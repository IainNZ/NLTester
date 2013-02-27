#
#   A nonlinear control problem as suggested by
#
#   N. Arada, J.-P. Raymond, and F. Troeltzsch,
#   ``On an augmented Lagrangian SQP method for a class of optimal control
#     problems in Banach spaces'', SFB 393, Preprint 00-19, TU Chemnitz 2000,
#     to appear
#
#   and
#
#   H. D. Mittelmann,
#   ``Sufficient Optimality for Discretized Parabolic and
#     Elliptic Control Problems'', to appear in
#     Proc. Workshop Fast solution of discretized optimization problems,
#     WIAS Berlin, 5/2000, Birkhaeuser-Verlag, Basel
#
#   See also Hans Mittelmann's WWW article
#
#    http://plato.la.asu.edu/papers/paper91/paper.html
#
#   where the problem is example 5.1.
#
param n default 200;
param m default n;
param n1 := n-1;
param m1 := m-1;
param T default 1;
param dt := T/m;
param l := atan(1);
param dx := l/n;
param h2 := dx^2;
param s2 := sqrt(2)/2;
param e1 := exp(1) + 1/exp(1);
param e13 := exp(1/3);
param e132 := e13*(e13-1);
param nu := s2*e132;
param yt{j in 0..n} := e1*cos(j*dx);

option presolve 0;

var y{0..m, 0..n} >= -10, <= 10;
var u{i in 1..m} >= 0, <= 1;

minimize f:	.25*dx*( (y[m,0] - yt[0])^2 + 
  2* sum{j in 1..n1} (y[m,j] - yt[j])^2 + (y[m,n] - yt[n])^2)
  + .25*nu*dt*( 2* sum{i in 1..m1} u[i]^2 + u[m]^2)
  + dt*( (sum{i in 1..m1} (-exp(-2*i*dt)*y[i,n] + s2*e13*u[i]))
  + .5*(-exp(-2*T)*y[m,n] + s2*e13*u[m]));

s.t. pde{i in 0..m1, j in 1..n1}:
	(y[i+1,j] - y[i,j])/dt = .5*(y[i,j-1] - 2*y[i,j] + y[i,j+1]
	 + y[i+1,j-1] - 2*y[i+1,j] + y[i+1,j+1])/h2;

#s.t. ic {j in 0..n}: y[0,j] = cos(j*dx);
s.t. bc1 {i in 1..m}: (y[i,2] - 4*y[i,1] + 3*y[i,0])/(2*dx) = 0;
s.t. bc2 {i in 1..m}: (y[i,n-2] - 4*y[i,n1] + 3*y[i,n])/(2*dx) + y[i,n]
  = u[i] + .25*exp(-4*i*dt) - min(1, max(0, (exp(i*dt)-e13)/e132))
    - y[i,n]*abs(y[i,n])^3;

#s.t. cc{i in 1..m}: 0 <= u[i] <= 1;    
#s.t. sc{i in 0..m,j in 0..n}: -10 <= y[i,j] <= 10;

write gcont5_1-200;
