function model = clnlbeam(N)

ni = N;
%alpha = 350;
h = 1/ni;

t = sdpvar(ni+1,1);
x = sdpvar(ni+1,1);
u = sdpvar(ni+1,1);

% cons1
C = [x(2:ni+1)-x(1:ni) - (0.5*h)*(sin(t(2:ni+1))+sin(t(1:ni))) == 0];

% cons2
C = [C, t(2:ni+1)-t(1:ni) - (0.5*h)*u(2:ni+1)-(0.5*h)*u(1:ni)];

% dummy objective
obj = t(1);

options = sdpsettings();
options.pureexport = 1;

model = solvesdp(C,obj,options);


end