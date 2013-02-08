using MathProg

require("nlp.jl")

function Test()
    ni    = 500
    alpha = 350
    h     = 1/ni
    halfH = h/2

    m = Model("min")

    #t = [ addVar(m, -1, +1, CONTINUOUS) for i = 1:(ni+1) ] 
    #x = [ addVar(m, -0.05, +0.05, CONTINUOUS) for i = 1:(ni+1) ]
    #u = [ addVar(m, -Inf, +Inf, CONTINUOUS) for i = 1:(ni+1) ]
    @defVar(m, -1 <= t[1:(ni+1)] <= 1)
    @defVar(m, -0.05 <= x[1:(ni+1)] <= 0.05)
    @defVar(m, u[1:(ni+1)])

    #sum( 0.5*h*(u[i+1]^2 + u[i]^2) + 0.5*alpha*h*(cos(t[i+1]) + cos(t[i])) for i = 1:ni )
    objective = @nlexpr sum{ (halfH)*(u[i+1] ^ 2 + u[i] ^ 2) + (alpha*halfH)*(cos(t[i+1]) + cos(t[i])), i = 1:ni }

    println("Preparing gradient vector")
    grad = @time denseGradVec(m, objective)
    #grad = @time sparseGradVec(m, objective)

    cons = Array(Expr,0)
    # cons1
    for i in 1:ni
        push!(cons, @nlexpr x[i+1] - x[i] - halfH*(sin(t[i+1])+sin(t[i])))
    end
    # cons2
    for i in 1:ni
        push!(cons, @nlexpr t[i+1] - t[i] - halfH*u[i+1] - halfH*u[i])
    end

    println("\nPreparing sparse jacobian")

    # elts is a function that returns the row-oriented nonzero element vector
    elts, colval, rowstarts = @time sparseJacobian(m,cons)

    #minimize f:
    #	sum {i in 0..ni-1} (0.5*h*(u[i+1]^2 + u[i]^2) + 0.5*alpha*h*(cos(t[i+1]) + cos(t[i]))); 
    #subject to cons1{i in 0..ni-1}:
    #	x[i+1] - x[i] - 0.5*h*(sin(t[i+1]) + sin(t[i]))= 0;
    #subject to cons2{i in 0..ni-1}:
    #	t[i+1] - t[i] - 0.5*h*u[i+1] - 0.5*h*u[i] = 0;
end

Test()
