# Julia NLtest


function buildSparseFormat()
	m = 2
	n = 3
	colptr = [0,2,4]
	rowval = [0,1,0,1,0,1]
	nzval = [0.,0.,0.,0.,0.,0.]
	return SparseMatrixCSC(m,n,colptr,rowval,nzval)
end

function calculateJacobian(


# Jacobian test
J = buildSpareFormat()
calculateJacobian(J,[5,2,3])

