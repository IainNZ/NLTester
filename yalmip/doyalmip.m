
function [] = doyalmip()

runinstance('clnlbeam',500);
runinstance('cont5_1',100);
runinstance('clnlbeam',5000);
runinstance('cont5_1',200);


end

function [] = runinstance(name,N)

modelrep = 1;
jacrep = 3;

% take mimimum over repitions to decrease variability
buildtime = Inf;
for k = 1:modelrep
    tic
    model = eval(sprintf('%s(%d)',name,N));
    model = yalmip2nonlinearsolver(model);
    buildtime = min(toc,buildtime);
end

x = ones(length(model.linearindicies),1);

jactime = Inf;
for k = 1:jacrep
    tic
    jac = ipopt_callback_dg(x,model);
    jactime = min(toc,jactime);
end
disp(['### ',name,',',num2str(N),' ',num2str(buildtime), ' ',num2str(jactime)])
disp(['## Jacobian norm: ',num2str(norm(jac(:))), ' (nnz = ',num2str(nnz(jac)),')'])

end