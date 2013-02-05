function ChainRule(e,var)
  println("In ChainRule")
  println(e)


	if e.args[1] == :sum
		println("Sum operator")
		thingToSum = e.args[2]
		iter = e.args[3]
		return :(sum($(expr(:comprehension, thingToSum, iter))))
	end
end



function prepareExpression(expr)
  if typeof(expr) == Expr
    for i in 1:length(expr.args)
      if typeof(expr.args[i]) == Variable
        expr.args[i] = :(__vals[$(expr.args[i].col)])
      elseif typeof(expr.args[i]) == Expr
				if expr.args[i].head == :ref
					x = expr.args[i]
					expr.args[i] = :(__vals[$(x.args[1])[$(x.args[2])].col])
				else
					prepareExpression(expr.args[i])
				end
      end
      
    end
  end
  return expr
end



# compile a function that evaluates the expression!
function generateFunction(expr)
  eval(quote function(__vals); $expr end end)
end
