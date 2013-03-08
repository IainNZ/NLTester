
function [] = doyalmip()


runinstance('cont5_1',200);
runinstance('cont5_1',400);
runinstance('cont5_1',1000);
runinstance('clnlbeam',5000);
runinstance('clnlbeam',50000);
runinstance('clnlbeam',500000);


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
    % include one call to jacobian
    x = ones(length(model.linearindicies),1);
    jac = ipopt_callback_dg(x,model);
    buildtime = min(toc,buildtime);
end

n = norm(jac(:));


jactime2 = Inf;
for k = 1:jacrep
    % change x because there's code to check for repeat calls
    x = rand(length(model.linearindicies),1);
    tic
    jac = ipopt_callback_dg(x,model);
    jactime2 = min(toc,jactime2);
end
disp(['### ',name,',',num2str(N),' ',num2str(buildtime),' ',num2str(jactime2)])
disp(['## Jacobian norm: ',num2str(n), ' (nnz = ',num2str(nnz(jac)),')'])


end
