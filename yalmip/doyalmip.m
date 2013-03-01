
function [] = doyalmip()

runinstance('clnlbeam',500);
runinstance('cont5_1',100);
runinstance('clnlbeam',5000);
runinstance('cont5_1',200);


end

function [] = runinstance(name,N)

modelrep = 1;
jacrep = 3;

% take mimimum over repetitions to decrease variability
buildtime = Inf;
for k = 1:modelrep
    yalmip('clear')
    tic
    model = eval(sprintf('%s(%d)',name,N));
    model = yalmip2nonlinearsolver(model);
    buildtime = min(toc,buildtime);
end

x = ones(length(model.linearindicies),1);

tic
jac = ipopt_callback_dg(x,model);
jactime1 = toc;

n = norm(jac(:));

jactime2 = Inf;
for k = 1:jacrep
    x = rand(length(model.linearindicies),1);
    tic
    jac = ipopt_callback_dg(x,model);
    jactime2 = min(toc,jactime2);
end
disp(['### ',name,',',num2str(N),' ',num2str(buildtime), ' ',num2str(jactime1),' ',num2str(jactime2)])
disp(['## Jacobian norm: ',num2str(n), ' (nnz = ',num2str(nnz(jac)),')'])


end