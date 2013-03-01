function model = cont5_1(N)

n = N;
m = N;
T = 1;
dt = T/m;
l = atan(1);
dx = l/n;
h2inv = 1/dx^2;


y = sdpvar(m+1,n+1,'full');
u = sdpvar(m,1);

% pde
C = [(1/dt)*(y(2:m+1,2:n) - y(1:m,2:n)) - ...
    (h2inv/2)*(y(1:m,1:n-1) - 2*y(1:m,2:n) + y(1:m,3:n+1) + y(2:m+1,1:n-1) ...
        - 2*y(2:m+1,2:n) + y(2:m+1,3:n+1)) == 0];


    
% bc1
C = [C, (0.5/dx)*(y(2:m+1,3)-4*y(2:m+1,2) + 3*y(2:m+1,1)) == 0];

% bc2
C = [C, (0.5/dx)*(y(2:m+1,n-1) - 4*y(2:m+1,n) + 3*y(2:m+1,n+1)) + ...
    y(2:m+1,n+1) - u + y(2:m+1,n+1).*(y(2:m+1,n+1).^2).^(1.5) == 0];

% dummy objective
obj = y(1);


options = sdpsettings();
options.pureexport = 1;

model = solvesdp(C,obj,options);


end