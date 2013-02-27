using MathProg

require("nlp.jl")

function clnlbeam(N)
    ni    = N
    alpha = 350
    h     = 1/ni
    halfH = h/2

    m = Model("min")

    @defVar(m, -1 <= t[1:(ni+1)] <= 1)
    @defVar(m, -0.05 <= x[1:(ni+1)] <= 0.05)
    @defVar(m, u[1:(ni+1)])

    cons = Array(NLExpr,0)
    # cons1
    for i in 1:ni
        push!(cons, @nlexpr x[i+1] - x[i] - halfH*(sin(t[i+1])+sin(t[i])))
    end
    # cons2
    for i in 1:ni
        push!(cons, @nlexpr t[i+1] - t[i] - halfH*u[i+1] - halfH*u[i])
    end

    return m,cons

end

function cont5_1(N)
    n = N
    m = n 
    T = 1
    dt = T/m
    l = atan(1)
    dx = l/n
    h2inv = 1/dx^2
    dtinv = 1/dt
    dxinv = 1/dx

    model = Model("min")

    # add 1 to ampl indices for y
    @defVar(model, -10 <= y[1:(m+1),1:(n+1)] <= 10)
    @defVar(model, 0 <= u[1:m] <= 1)

    cons = Array(NLExpr,0)
    # pde
    for i in 0:(m-1), j in 1:(n-1)
        push!(cons, @nlexpr dtinv*(y[i+2,j+1] - y[i+1,j+1]) - 
            (0.5h2inv)*(y[i+1,j] - 2y[i+1,j+1] + y[i+1,j+2] + y[i+2,j] - 2y[i+2,j+1] + y[i+2,j+2]))
    end

    # bc1
    for i in 1:m
        push!(cons, @nlexpr (0.5dxinv)*(y[i+1,3] - 4y[i+1,2] + 3y[i+1,1]))
    end
    
    # bc2
    for i in 1:m
        push!(cons, @nlexpr((0.5dxinv)*(y[i+1,n-1] - 4y[i+1,n] + 3y[i+1,n+1]) +
         y[i+1,n+1] - u[i] + y[i+1,n+1]*(y[i+1,n+1]^2)^(1.5)) )
        # use y*(y^2)^(3/2) instead of y*abs(y)^3 
    end

    return model,cons
end


instances = [(:clnlbeam,500),
    (:clnlbeam,5000),(:clnlbeam,50000),
    (:clnlbeam,500000),
    (:cont5_1,200),(:cont5_1,400),(:cont5_1,1000)]
#instances = [:cont5_1]
#instances = [(:clnlbeam,500000)]


function dobench()
    Reps = 100

    modeltime = Float64[]
    prepjacobian = Float64[]
    firsteval = Float64[]
    nextN = Float64[]
    for (i,N) in instances
        gc_disable()
        f = eval(i)

        t = time()
        m,cons = f(N)
        push!(modeltime,time()-t)

        t = time()
        elts, colval, rowstarts = sparseJacobian(m,cons)
        push!(prepjacobian,time()-t)

        xval = ones(m.numCols)
        
        t = time()
        # preallocate output
        nzval = Array(Float64,length(colval))
        elts(xval,nzval)
        push!(firsteval,time()-t)

        t = time()
        for k in 1:Reps
            elts(xval,nzval)
        end
        push!(nextN,time()-t)

        #for row in 1:length(cons)
        #    print("Row $row: ")
        #    println(join([@sprintf("%.9f*X%d", nzval[r], colval[r]) for r in rowstarts[row]:(rowstarts[row+1]-1)]," + "))
        #end
        
        println("### $(string(i)), N = $N $(modeltime[end]) $(prepjacobian[end]) $(firsteval[end]) $(nextN[end]/N)")
        println("## $(string(i)), N = $N Problem has $(m.numCols) variables, $(length(cons)) constraints, and $(length(nzval)) non-zero elements")
        println("## $(string(i)), N = $N Jacobian norm: $(norm(nzval,2)) (nnz = $(length(nzval)))")
        gc_enable()
    end
end

dobench()
        




