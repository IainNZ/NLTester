
type NLExpr
    ex::Any
    exhash::Uint
    exvars::Vector{Int} # list of variables in the expression as they appear (duplicates possible)
end

function processExpr(x::Expr)
    if x.head == :curly && x.args[1] == :sum
        # transform sum syntax into an explicit call to (+)
        # score one for recursion
        arr = gensym()
        code = :(push!($arr,$(processExpr(x.args[2]))))
        for level in length(x.args):-1:3
            code = expr(:for, {x.args[level],code})
            # for $(x.args[level]) $code end
        end
        code = :($arr = {:+};$code;$arr)
        return :(expr(:call,$code))
    elseif x.head == :call
        quoted = expr(:quote,{x.args[1]})
        code = :(expr(:call,{$quoted}))
        for y in x.args[2:end]
            push!(code.args[3].args,processExpr(y))
        end
        return code
    else
        return x
    end
end

processExpr(x::Any) = x

addToVarList(x::Variable,l) = push!(l,x.col)
addToVarList(x::Any,l) = nothing

# generate code that generates the list of variables in an expression
function genVarList(x::Expr, arrname)
    if x.head == :curly && x.args[1] == :sum
        code = genVarList(x.args[2],arrname)
        for level in length(x.args):-1:3
            code = expr(:for, {x.args[level],code})
        end
        return code
    elseif x.head == :call
        return expr(:block,{ genVarList(y,arrname) for y in x.args[2:end] })
    else
        return :(addToVarList($x,$arrname))
    end
end

genVarList(x::Number,arrname) = nothing
genVarList(x::Symbol,arrname) = :(addToVarList($x,$arrname))


macro nlexpr(x)
    exvars = gensym()
    varcode = quote
        $exvars = Int[]
        $(genVarList(x,exvars))
        $exvars
    end
    return :(NLExpr($(esc(processExpr(x))),$(hash(x)), $(esc(varcode))))
end  

type Placeholder
    idx::Int
end

chainRule(ex::Variable,wrt::Variable) = (ex.col == wrt.col) ? 1 : 0
chainRule(ex::Placeholder,wrt::Placeholder) = (ex.idx == wrt.idx) ? 1 : 0


chainRule(ex::Number,wrt::Variable) = 0
chainRule(ex::Number,wrt::Placeholder) = 0

function chainRule(ex::Expr,wrt)
    if ex.head != :call
        error("Unrecognized expression $ex")
    end
    if ex.args[1] == :^
        #println("^ operator, diff it")
        x = chainRule(ex.args[2],wrt)
        if x != 0
            return :( $(ex.args[3]) * $(x) * ($(ex.args[2]) ^ ($(ex.args[3] - 1))) )
        else
            return 0
        end
    end
    if ex.args[1] == :+
    #    println("$(ex.args[1]) operator, just diff terms")
        termdiffs = {ex.args[1]}
        for y in ex.args[2:end]
            x = chainRule(y,wrt)
            if x != 0
                push!(termdiffs, x)
            end
        end
        if (length(termdiffs) == 1)
            return 0
        elseif (length(termdiffs) == 2)
            return termdiffs[2]
        else
            return expr(:call,termdiffs)
        end
    end
    if ex.args[1] == :-
    #    println("$(ex.args[1]) operator, just diff terms")
        termdiffs = {ex.args[1]}
        # first term is special, can't be dropped
        term1 = chainRule(ex.args[2],wrt)
        push!(termdiffs, term1)
        for y in ex.args[3:end]
            x = chainRule(y,wrt)
            if x != 0
                push!(termdiffs, x)
            end
        end
        if term1 != 0 && length(termdiffs) == 2 && length(ex.args) >= 3
            # if all of the terms but the first disappeared, we just return the first
            return term1
        elseif (term1 == 0 && length(termdiffs) == 2)
            return 0
        else
            return expr(:call,termdiffs)
        end
    end
    if ex.args[1] == :*
    #    println("* operation")
        if length(ex.args) != 3
            error("Only multiplication with two terms is currently supported")
        end
        d1 = chainRule(ex.args[2],wrt)
        d2 = chainRule(ex.args[3],wrt)
        # there's a nicer way
        if d1 == 0 && d2 == 0
            return 0
        elseif d1 == 0
            return :( $(d2)*$(ex.args[2]) )
        elseif d2 == 0
            return :( $(d1)*$(ex.args[3]) )
        else
            return :( $(d1)*$(ex.args[3]) + $(ex.args[2])*$(d2))
        end
    end
    if ex.args[1] == :cos
        x = chainRule(ex.args[2],wrt)
        if x != 0
            return :(-$(x)*sin($(ex.args[2])))
        else
            return 0
        end
    end
    if ex.args[1] == :sin
        x = chainRule(ex.args[2],wrt)
        if x != 0
            return :($x*cos($(ex.args[2])))
        else
            return 0
        end
    end
    
    error("Unrecognized function $(ex.args[1])")
end




# new approach: keep a list of expressions that we've seen and identify
# which are identical up to a difference in variable indices


function canonicalizeExpression(ex::Variable,niceidx,nseen)
    return Placeholder(niceidx[nseen.idx += 1])
end

canonicalizeExpression(ex::Symbol,niceidx,nseen) = ex
canonicalizeExpression(ex::Number,niceidx,nseen) = ex
canonicalizeExpression(ex::Expr,niceidx,nseen) = expr(ex.head,{canonicalizeExpression(y,niceidx,nseen) for y in ex.args})
canonicalizeExpression(ex,niceidx) = (nseen = Placeholder(0); canonicalizeExpression(ex,niceidx,nseen))


# make indices nice, preserving equality
# e.g. [3, 10, 100, 3, 2 ] -> [ 1, 2, 3, 1, 4 ]
function canonicalizeArray{T}(vec::Vector{T}) 
    seen = Dict{T,Int}()
    out = Array(Int,length(vec))
    reversemap = T[]
    for i in 1:length(vec)
        idx = get(seen,vec[i],0)
        if idx != 0
            out[i] = idx
        else
            seen[vec[i]] = length(seen)+1
            out[i] = length(seen)
            push!(reversemap,vec[i])
        end
    end
    return out, reversemap, length(seen)
end


preparePlaceholderExpression(ex::Placeholder,t) = :(__vals[placeholderMaps[$t][i][$(ex.idx)]])
preparePlaceholderExpression(ex::Symbol,t) = ex
preparePlaceholderExpression(ex::Number,t) = ex
preparePlaceholderExpression(ex::Expr,t) = expr(ex.head,{preparePlaceholderExpression(y,t) for y in ex.args})



function sparseJacobian(m,constr::Vector{NLExpr})

    arr = {:Float64}
    colval = Array(Int,0)
    rowstart = [1]

    origExprTemplates = NLExpr[]
    derivExprTemplates = Array(Vector{Any},0)
    numPlaceholders = Int[]
    # for each derivarive template, the nonzero elements it corresponds to
    exprsByDerivTemplate = Array(Vector{Vector{Int}},0)
    placeholderMaps = Array(Vector{Vector{Int}},0)
    nnz = 0
    
    t1 = 0.
    t2 = 0.
    t3 = 0.


    for r in 1:length(constr)
        con = constr[r]
        #println(con.ex,con.exvars)
        # check if we've seen this expression before, modulo variable indices
        t = time()
        found = false
        for k in length(origExprTemplates):-1:1
            y = origExprTemplates[k]
            if y.exhash == con.exhash
                # check that pattern of variables match, i.e. 1-1 correspondence between expressions
                templatevars = y.exvars
                convars = con.exvars
                @assert length(convars) == length(templatevars)
                matcharr = zeros(Int,numPlaceholders[k])
                nmatch = 0
                ismatch = true
                # map from placeholder index to variables in this constraint
                for i in 1:length(convars)
                    if matcharr[templatevars[i]] == 0
                        matcharr[templatevars[i]] = convars[i]
                        nmatch += 1
                    elseif matcharr[templatevars[i]] != convars[i]
                        # no match
                        ismatch = false
                        break
                    end
                end
                if ismatch && nmatch == numPlaceholders[k]
                    idx = k
                    found = true
                    break
                end
            end
        end
        t2 += time() - t
        t = time()
        if !found
            templatevars,matcharr,np = canonicalizeArray(con.exvars)
            origTemplate = NLExpr(canonicalizeExpression(con.ex,templatevars),con.exhash,templatevars)
            push!(origExprTemplates,origTemplate)
            push!(numPlaceholders,np)
            push!(exprsByDerivTemplate,Array(Vector{Int},np))
            # fix this syntax
            for i in 1:np
                exprsByDerivTemplate[end][i] = Array(Int,0)
            end
            push!(placeholderMaps,Array(Vector{Int},0))
            # differentiate wrt each unique variable present
            push!(derivExprTemplates,{ chainRule(origTemplate.ex,Placeholder(i)) for i in 1:np })
            idx = length(origExprTemplates)
        end
        t1 += time() - t

        t = time()
        # fill in row (in correct variable order)
        for i in sortperm(matcharr)
            push!(colval,matcharr[i])
            push!(exprsByDerivTemplate[idx][i],length(colval))
        end
        push!(placeholderMaps[idx],matcharr)
        t3 += time() - t
        push!(rowstart,length(colval)+1)
    end
    #println("$(length(origExprTemplates)) unique expressions")

    #println("chain rule time: $t1")
    #println("expression pattern match: $t2")
    #println("sortperm+ time: $t3")
    
    t3 = time()
    fexpr = :( (__vals::Vector{Float64},out::Vector{Float64},exprsByDerivTemplate::Vector{Vector{Vector{Int}}},placeholderMaps::Vector{Vector{Vector{Int}}}) -> begin end )
    for t in 1:length(derivExprTemplates)
        for k in 1:length(derivExprTemplates[t])
            ex = preparePlaceholderExpression(derivExprTemplates[t][k],t)
            loop = quote
                arr = exprsByDerivTemplate[$t][$k]
                for i in 1:length(arr)
                    out[arr[i]] = $ex
                end
            end
            push!(fexpr.args[2].args[2].args,loop)
        end
    end
    f = eval(fexpr)
    v = (__vals,out) -> f(__vals,out,exprsByDerivTemplate,placeholderMaps)
    t3 = time() - t3
    #println("compile time: $t3")
    return v, colval, rowstart

            
end

