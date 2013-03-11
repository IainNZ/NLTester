from coopr.pyomo import *

model = AbstractModel()
model.N = Param(within=PositiveIntegers)
model.T = 1.0
model.dt = model.T/model.N
model.l = atan(1)
model.dx = model.l/model.N
model.h2inv = 1.0/model.dx**2
#model.dtinv = 1.0/model.dt # fails: Cannot reconstruct parameter 'dtinv' (already constructed)
model.dxinv = 1.0/model.dx


model.Idx1 = RangeSet(1,model.N+1)
model.Idx2 = RangeSet(1,model.N)


model.y = Var(model.Idx1,model.Idx1, bounds=(-10,10))
model.u = Var(model.Idx2, bounds=(0.0,1.0))

model.c = Objective(expr=1) # dummy objective

def pde_rule(m, i, j):
	if j == m.N:
		return Constraint.Skip
	return m.N*(m.y[i+1,j+1] - m.y[i,j+1]) - (0.5*m.h2inv)*(m.y[i,j] - 2*m.y[i,j+1] + m.y[i,j+2] + m.y[i+1,j] - 2*m.y[i+1,j+1] + m.y[i+1,j+2]) == 0
model.pde = Constraint(model.Idx2,model.Idx2)

def bc1_rule(m, i):
	return (0.5*m.dxinv)*(m.y[i+1,3] - 4*m.y[i+1,2] + 3*m.y[i+1,1]) == 0
model.bc1 = Constraint(model.Idx2)

def bc2_rule(m, i):
	return (0.5*m.dxinv)*(m.y[i+1,int(m.N)-1] - 4*m.y[i+1,int(m.N)] + 3*m.y[i+1,int(m.N)+1]) + \
			m.y[i+1,int(m.N)+1] - m.u[i] + m.y[i+1,int(m.N)+1]*(m.y[i+1,int(m.N)+1]**2)**(1.5) == 0
model.bc2 = Constraint(model.Idx2)



