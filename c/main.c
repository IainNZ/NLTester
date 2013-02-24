/* 
   wget ftp://www.netlib.org/ampl/solvers.tar.gz 
   tar xvzf solvers.tar.gz
   cd solvers
   sh configurehere
   make

   gcc -O2 main.c solvers/amplsolver.a -o nltest -ldl -lm 

*/
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
	t0 = clock_now() - t0;

	
	J = (real *)Malloc(nzc*sizeof(real));
	

	int nvar = n_var;

	X = (real *)Malloc(nvar*sizeof(real));

	for (i = 0; i < nvar; i++) X[i] = 1.0;
	
	//objVal = objval(0, X, &nerror);
	//printf("Objective %.5f\n", objVal);
	
	double t1 = clock_now();
	for (k = 0; k < 100; k++) {
		jacval(X, J, &nerror);
	}
	t1 = clock_now() - t1;

	double norm = 0;
	for (i = 0; i < nzc; i++) {
		norm += J[i]*J[i];
	}
	norm = sqrt(norm);


	char *bname = basename(argv[1]);
	// Initialization time, 100 jacobian evaluations
	printf("### %s %f %g\n",bname,t0,t1/100);
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
	
}
