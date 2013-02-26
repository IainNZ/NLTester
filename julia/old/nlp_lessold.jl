macro nlexpr(x)
    return esc(processExpr(x))
end

findVariablesInner(x::Variable) = [x.col]
findVariablesInner(x::Symbol) = []
findVariablesInner(x::Number) = []
# this is too slow
#findVariablesInner(x::Expr) = vcat([findVariablesInner(a) for a in x.args]...)
function findVariablesInner(x::Expr)
    out = Array(Int,0)
    for a in x.args
        for b in findVariablesInner(a)
            push!(out,b)
        end
    end
    return out
end
# return a list of variables in the given expression
# (short code but not currently the most efficient)
findVariables(x::Expr) = sort(unique(findVariablesInner(x)))



#expressionEqual(x::Expr,y::Expr) = x.head == y.head && length(x.args) == length(y.args) && 
#    all([expressionEqual(a,b) for (a,b) in zip(x.args,y.args)])
function expressionEqual(x::Expr,y::Expr)
    if x.head != y.head || length(x.args) != length(y.args)
        return false
    else
        for i in 1:length(x.args)
            if !expressionEqual(x.args[i],y.args[i])
                return false
            end
        end
        return true
    end
end

expressionEqual(x::Variable,y::Placeholder) = true
expressionEqual(x::Any,y::Any) = x == y


# given Expr y with placeholders, generate map from placeholder indices to variable indices
# (assumes expressions are equal)

placeholderMap(x,y,numPlaceholder::Int) = (a = zeros(Int,numPlaceholder); placeholderMap2(x,y,a); a)
placeholderMap2(x::Expr,y::Expr,map) = for i in 1:length(x.args)
    placeholderMap2(x.args[i],y.args[i],map) 
end

function placeholderMap2(x::Variable,y::Placeholder,map::Vector{Int})
    if map[y.idx] == 0
        map[y.idx] = x.col
    else
        @assert map[y.idx] == x.col
    end
    return
end
placeholderMap2(x::Any,y::Any,map) = nothing

# exprTemplate : list of canonicalized expressions
# exprsByTemplate : output indices corresponding to each template
# placeholderMaps : corresponding placeholder maps
function compileExprVec(exprTemplates::Vector, exprsByTemplate::Vector{Vector{Int}}, 
    placeholderMaps::Vector{Vector{Vector{Int}}}, nnz)
    fexpr = :( (__vals::Vector{Float64},out::Vector{Float64},exprsByTemplate::Vector{Vector{Int}},placeholderMaps::Vector{Vector{Vector{Int}}}) -> begin end )
    for t in 1:length(exprTemplates)
        ex = preparePlaceholderExpression(exprTemplates[t],t)
        loop = :(
            for i in 1:length(exprsByTemplate[$t])
                out[exprsByTemplate[$t][i]] = $ex
            end)
        push!(fexpr.args[2].args[2].args,loop)
    end
    f = eval(fexpr)
    return (__vals,out) -> f(__vals,out,exprsByTemplate,placeholderMaps)
end


function sparseJacobianOld2(m,constr)

    arr = {:Float64}
    colval = Array(Int,0)
    rowstart = [1]

    exprTemplates = {}
    numPlaceholders = Int[]
    exprsByTemplate = Array(Vector{Int},0)
    placeholderMaps = Array(Vector{Vector{Int}},0)
    nnz = 0
    
    t1 = 0.
    t2 = 0.

    for r in 1:length(constr)
        #for i in 1:m.numCols
        for i in findVariables(constr[r])
            t = time()
            x = chainRule(constr[r],Variable(m,i))
            t1 += time() - t
            
            if x == 0
                continue
            end
            
            push!(colval,i)

            t = time()
            found = false
            for k in 1:length(exprTemplates)
                y = exprTemplates[k]
                idx = k
                if expressionEqual(x,y)
                    found = true
                    break
                end
            end
            if !found
                y,np = canonicalizeExpression(x)
                push!(exprTemplates,y)
                push!(numPlaceholders,np)
                push!(exprsByTemplate,Array(Int,0))
                push!(placeholderMaps,Array(Vector{Int},0))
                idx = length(exprTemplates)
            end
            push!(exprsByTemplate[idx],length(colval))
            placemap = placeholderMap(x,y,numPlaceholders[idx]) 
            push!(placeholderMaps[idx],placemap)
            @assert !contains(placemap,0)

            t2 += time() - t

        end
        push!(rowstart,length(colval)+1)
    end
    println("$(length(exprTemplates)) unique expressions")

    println("chain rule time: $t1")
    println("expressionEqual time: $t2")
    
    t = time()
    v = compileExprVec(exprTemplates,exprsByTemplate,placeholderMaps,length(colval))
    t3 = time() - t
    println("compile time: $t3")
    return v, colval, rowstart

            
end


## Old stuff:

prepareExpression(ex::Variable) = :(__vals[$(ex.col)])
prepareExpression(ex::Symbol) = ex
prepareExpression(ex::Number) = ex

function prepareExpression(ex::Expr)
    return expr(ex.head,{prepareExpression(y) for y in ex.args})
end

# compile a function that evaluates the expression
generateFunction(ex::Expr) = @eval (__vals) -> $ex

generateFunction(ex::Number) = (x) -> ex

# compile a function that generates array
# input arr contains expression for each element
# (first element of arr is output type)
function compileExprVec(arr::Vector{Any})
    #outexpr = expr(:vcat,arr)
    outexpr = expr(:ref,arr)
    @eval (__vals) -> $outexpr
end

# return function that computes the full gradient vector of given expression
function denseGradVec(m,ex)
    
    arr = Array(Any,m.numCols)
    t1 = 0.
    t2 = 0.
    for i in 1:m.numCols
        t = time()
        x = chainRule(ex,Variable(m,i))
        t1 += time() - t

        t = time()
        arr[i] = prepareExpression(x)
        t2 += time() - t
    end
    println("chain rule time: $t1")
    println("prepare expression time: $t2")
    
    t = time()
    v = compileExprVec(arr)
    t3 = time() - t
    println("compile time: $t3")
    return v 

end

# return tuple of (function that returns grad vector, non-zero indices)
function sparseGradVec(m,ex)
    
    arr = {:Float64}
    #arr = {}
    idx = Array(Int,0)
    t1 = 0.
    t2 = 0.
    for i in 1:m.numCols
        t = time()
        x = chainRule(ex,Variable(m,i))
        t1 += time() - t
        
        if x != 0
            println("$i: $x")
        end

        t = time()
        x = prepareExpression(x)
        t2 += time() - t

        if x != 0
            push!(arr,x)
            push!(idx,i)
        end
    end
    t = time()
    gv = compileExprVec(arr)
    t3 = time() - t
    println("chain rule time: $t1")
    println("prepare expression time: $t2")
    println("compile time: $t3")
    return gv,idx 

end

function sparseJacobianOld(m,constr)

    arr = {:Float64}
    colval = Array(Int,0)
    rowstart = [1]
    
    t1 = 0.
    t2 = 0.

    for r in 1:length(constr)
        #println("$r")
        #for i in 1:m.numCols
        for i in findVariables(constr[r])
            t = time()
            x = chainRule(constr[r],Variable(m,i))
            t1 += time() - t

            t = time()
            x = prepareExpression(x)
            t2 += time() - t

            if x != 0
                push!(arr,x)
                push!(colval,i)
            end
        end
        push!(rowstart,length(colval)+1)
    end

    println("chain rule time: $t1")
    println("prepare expression time: $t2")
    
    println("Calling compiler with $(length(colval)) non-zero elements")

    t = time()
    v = compileExprVec(arr)
    t3 = time() - t
    println("compile time: $t3")
    return v, colval, rowstart

            
end
