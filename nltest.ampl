var x;
var y;
var z;
maximize Obj:
 x*y + z^2 - x*y*z + y;

subject to FUN1:
 z*y + x^y <= 5;

subject to FUN2:
 x*z*y + z-y <= 4;

write gnltest;
