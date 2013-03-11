from coopr.pyomo import *

model = AbstractModel()

model.N = Param(within=PositiveIntegers)
model.h = 1.0/model.N

model.VarIdx = RangeSet(model.N+1)

model.t = Var(model.VarIdx, bounds=(-1.0,1.0))
model.x = Var(model.VarIdx, bounds=(-0.05,0.05))
model.u = Var(model.VarIdx)

model.c = Objective(expr=1) # dummy objective

def cons1_rule(m, i):
	if i == m.N+1:
		return Constraint.Skip
	return m.x[i+1] - m.x[i] - (0.5*m.h)*(sin(m.t[i+1])+sin(m.t[i])) == 0
model.cons1 = Constraint(model.VarIdx)

def cons2_rule(m,i):
	if i == m.N+1:
		return Constraint.Skip
	return m.t[i+1] - m.t[i] - (0.5*m.h)*m.u[i+1] - (0.5*m.h)*m.u[i] == 0
model.cons2 = Constraint(model.VarIdx)

