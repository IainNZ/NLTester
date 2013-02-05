using MathProg

require("nlp.jl")

function Test()
	ni    = 500
	alpha = 350
	h     = 1/ni

	m = Model("min")

	t = [ addVar(m, -1, +1, CONTINUOUS) for i = 1:(ni+1) ] 
	x = [ addVar(m, -0.05, +0.05, CONTINUOUS) for i = 1:(ni+1) ]
	u = [ addVar(m, -Inf, +Inf, CONTINUOUS) for i = 1:(ni+1) ]

	#sum( 0.5*h*(u[i+1]^2 + u[i]^2) + 0.5*alpha*h*(cos(t[i+1]) + cos(t[i])) for i = 1:ni )
	objective = :( sum{ 0.5*h*(u[i+1] ^ 2 + u[i] ^ 2) + 0.5*alpha*h*(cos(t[i+1]) + cos(t[i])), i = 1:ni } )

	dobj = ChainRule( :(sum{ 5*t[i], i=1:10}), t[1] )
	show(dobj)
	println()
	dobj = prepareExpression(dobj)
	show(dobj)
	println()
	dobjf = generateFunction(dobj)
	dump(dobjf)
	println()
	println(dobjf([2,3,4,5,6]))

	#minimize f:
	#	sum {i in 0..ni-1} (0.5*h*(u[i+1]^2 + u[i]^2) + 0.5*alpha*h*(cos(t[i+1]) + cos(t[i]))); 
	#subject to cons1{i in 0..ni-1}:
	#	x[i+1] - x[i] - 0.5*h*(sin(t[i+1]) + sin(t[i]))= 0;
	#subject to cons2{i in 0..ni-1}:
	#	t[i+1] - t[i] - 0.5*h*u[i+1] - 0.5*h*u[i] = 0;
end

Test()
