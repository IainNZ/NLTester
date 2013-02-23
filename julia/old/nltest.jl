# Julia NLtest

using Calculus

obj = :(x*y + z^2 - x*y*z + y)
con1 = :(z*y + x^y <= 5)
con2 = :(x*z*y + z-y <= 4)

Jexpr = SparseMatrixCSC{Expr}(0,0,[],[],[])

function buildSparseFormat()
	m = 2
	n = 3
	
	
	Jexpr_nz = []
	Jexpr_rowval = []
	Jexpr_colptr = []
	Jexpr_nnz = 0
	
	# Differentiate each expression
	for diffBy = [:x,:y,:z]
		push!(Jexpr_colptr, Jexpr_nnz)
		for conToDiff = [(con1,1), (con2,2)]
			test = differentiate(conToDiff[1],:x)
			if test != 0
				push!(Jexpr_nz, test)
				push!(Jexpr_rowval, conToDiff[2])
				Jexpr_nnz += 1
			end
		end
	end
	
	jacobianZeros = zeros(Jexpr_nnz)
	Jexpr= SparseMatrixCSC(m,n, Jexpr_colptr, Jexpr_rowval, Jexpr_nz)
	return SparseMatrixCSC(m,n, Jexpr_colptr, Jexpr_rowval, jacobianZeros)
end

function calculateJacobian(J,x,y,z)
	for col = [(1,:x), (2,:y), (3,:z)]
		for ind = J.colptr[col[1]] : J.colptr[col[1]+1]
		  println(col,ind)
		end
 end
end

# Jacobian test
J = buildSpareFormat()
calculateJacobian(J,[5,2,3])

