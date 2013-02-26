function processExpr(x)
    if !isa(x,Expr)
        return x
    elseif x.head == :curly && x.args[1] == :sum
        # transform sum syntax into an explicit call to (+)
        # we generate code that calls the same macro
        # score one for recursion
        arr = gensym()
        code = :(push!($arr,@nlexpr($(x.args[2]))))
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

macro nlexpr(x)
    return esc(processExpr(x))
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





function canonicalizeExpression(ex::Variable,seen::Dict{Int,Int})
    idx = get(seen,ex.col,0)
    if idx != 0
        return Placeholder(idx)
    else
        seen[ex.col] = length(seen)+1
        return Placeholder(length(seen))
    end
end

canonicalizeExpression(ex::Symbol,seen) = ex
canonicalizeExpression(ex::Number,seen) = ex
canonicalizeExpression(ex::Expr,seen) = expr(ex.head,{canonicalizeExpression(y,seen) for y in ex.args})
canonicalizeExpression(ex) = (d = Dict{Int,Int}(); (canonicalizeExpression(ex,d),length(d)))




# combination of expressionEqual and placeholderMap
# check if Expr y with placeholders is equal to expression x *and* has the same variable pattern
function expressionPatternEqual(x,y,numPlaceholder::Int) 
    a = zeros(Int,numPlaceholder)
    return expressionPatternEqual2(x,y,a), a
end

function expressionPatternEqual2(x::Expr,y::Expr,map)
    if x.head != y.head || length(x.args) != length(y.args)
        return false
    else
        for i in 1:length(x.args)
            if !expressionPatternEqual2(x.args[i],y.args[i],map)
                return false
            end
        end
        return true
    end
end

function expressionPatternEqual2(x::Variable,y::Placeholder,map::Vector{Int})
    if map[y.idx] == 0 # haven't seen this placeholder yet
        map[y.idx] = x.col
    elseif map[y.idx] != x.col
        # already saw this placeholder but it was matched to a different variable
        return false
    end
    return true
end

expressionPatternEqual2(x::Any,y::Any,map) = x == y


preparePlaceholderExpression(ex::Placeholder,t) = :(__vals[placeholderMaps[$t][i][$(ex.idx)]])
preparePlaceholderExpression(ex::Symbol,t) = ex
preparePlaceholderExpression(ex::Number,t) = ex
preparePlaceholderExpression(ex::Expr,t) = expr(ex.head,{preparePlaceholderExpression(y,t) for y in ex.args})



function sparseJacobian(m,constr)

    arr = {:Float64}
    colval = Array(Int,0)
    rowstart = [1]

    origExprTemplates = {}
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
        # check if we've seen this expression before, modulo variable indices
        t = time()
        found = false
        for k in 1:length(origExprTemplates)
            y = origExprTemplates[k]
            idx = k
            eq, placemap = expressionPatternEqual(constr[r],y,numPlaceholders[k])
            if eq
                @assert !contains(placemap,0)
                found = true
                break
            end
        end
        t2 += time() - t

        t = time()
        if !found
            origTemplate,np = canonicalizeExpression(constr[r])
            eq, placemap = expressionPatternEqual(constr[r],origTemplate,np)
            push!(origExprTemplates,origTemplate)
            push!(numPlaceholders,np)
            push!(exprsByDerivTemplate,Array(Vector{Int},np))
            # fix this syntax
            for i in 1:np
                exprsByDerivTemplate[end][i] = Array(Int,0)
            end
            push!(placeholderMaps,Array(Vector{Int},0))
            # differentiate wrt each variable present
            push!(derivExprTemplates,{ chainRule(origTemplate,Placeholder(i)) for i in 1:np })
            idx = length(origExprTemplates)
        end
        t1 += time() - t

        t = time()
        # fill in row (in correct variable order)
        for i in sortperm(placemap)
            push!(colval,placemap[i])
            push!(placeholderMaps[idx],placemap)
            push!(exprsByDerivTemplate[idx][i],length(colval))
        end
        t3 += time() - t
        push!(rowstart,length(colval)+1)
    end
    println("$(length(origExprTemplates)) unique expressions")

    println("chain rule time: $t1")
    println("expressionPatternEqual time: $t2")
    println("sortperm+ time: $t3")
    
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
    println("compile time: $t3")
    return v, colval, rowstart

            
end

