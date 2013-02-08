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

function chainRule(ex::Variable,wrt::Variable)
    if ex.col == wrt.col
        return 1
    else
        return 0
    end
end

chainRule(ex::Number,wrt::Variable) = 0

function chainRule(ex::Expr,wrt::Variable)
    if ex.head != :call
        error("Unrecognized expression $ex")
    end
    if ex.args[1] == :^
    #    println("^ operator, diff it")
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

function sparseJacobian(m,constr)

    arr = {:Float64}
    colval = Array(Int,0)
    rowstart = [1]
    
    t1 = 0.
    t2 = 0.

    for r in 1:length(constr)
        for i in 1:m.numCols
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
        push!(rowstart,length(arr))
    end

    println("chain rule time: $t1")
    println("prepare expression time: $t2")
    
    println("Calling compiler with $(length(arr)-1) non-zero elements")

    t = time()
    v = compileExprVec(arr)
    t3 = time() - t
    println("compile time: $t3")
    return v, colval, rowstart

            
end
