/* 
   wget ftp://www.netlib.org/ampl/solvers.tar.gz 
   tar xvzf solvers.tar.gz
   cd solvers
   sh configurehere
   make

   gcc -O2 main.c solvers/amplsolver.a -o nltest -ldl -lm 

*/
//   bash -c 'for p in ../mod/*0.nl; do for k in `seq 1 3`; do ./nltest $p | grep "###"; done done'
#include "solvers/asl.h"
#include <sys/time.h>

// copied from julia
double clock_now()
{
    struct timeval now;

    gettimeofday(&now, NULL);
    return (double)now.tv_sec + (double)now.tv_usec/1.0e6;
}

int main(int argc, char **argv)
{
	FILE *nl;
	char *stub;
	ASL *asl;
	fint nerror = 0;
	real *X;
	real objVal;
	int i, j, k, je;
	real* J;
	cgrad *cg;
	char *fmt;

	if (argc < 2) {
		printf("Usage: %s stub\n", argv[0]);
		return 1;
	}
	
	double t0 = clock_now();
	asl = ASL_alloc(ASL_read_fg);
	stub = argv[1];
	nl = jac0dim(stub, (fint)strlen(stub));
	fg_read(nl,0);
	
	J = (real *)Malloc(nzc*sizeof(real));
	X = (real *)Malloc(n_var*sizeof(real));
	for (i = 0; i < n_var; i++) X[i] = 1.0;

	// include one jacobian call for consistency
	jacval(X, J, &nerror);

	t0 = clock_now() - t0;
	
	//objVal = objval(0, X, &nerror);
	//printf("Objective %.5f\n", objVal);
	
	double jactime = 1e30;
	for (k = 0; k < 10; k++) {
		double t1 = clock_now();
		jacval(X, J, &nerror);
		t1 = clock_now() - t1;
		jactime = (t1 < jactime) ? t1 : jactime;
	}

	double norm = 0;
	for (i = 0; i < nzc; i++) {
		norm += J[i]*J[i];
	}
	norm = sqrt(norm);


	char *bname = basename(argv[1]);
	// Initialization time, 1 jacobian evaluation
	printf("### %s %f %g\n",bname,t0,jactime);
	printf("## %s Jacobian norm: %.10g (nnz = %d)\n",bname,norm,nzc);


	
	/*printf("nzc %d\n",nzc);
	for(i = 0; i < nzc; i++) {
		printf("%d %g\n",i,J[i]);
	}*/
	/*
	for(i = 0; i < n_con; i++) {
		printf("\nRow %d:", i+1);
		//fmt = " J[%d]=%g*X%d";
		//for(cg = Cgrad[i]; cg; cg = cg->next, fmt = " + J[%d]=%g*X%d") {
		//	printf(fmt, cg->goff, J[cg->goff], cg->varno+1);
		//}
		fmt = " %g*X%d";
		for(cg = Cgrad[i]; cg; cg = cg->next, fmt = " + %g*X%d") {
			printf(fmt, J[cg->goff], cg->varno+1);
		}
		printf("\n");
	}*/

	return 0;
}
