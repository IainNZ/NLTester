#include "../AMPLInterface/asl.h"

int main(int argc, char **argv)
{
	FILE *nl;
	char *stub;
	ASL *asl;
	fint nerror = 0;
	real X[3];
	real objVal;
	int i, j, je;
	real* J;
	cgrad *cg;
	char *fmt;

	if (argc < 2) {
		printf("Usage: %s stub\n", argv[0]);
		return 1;
	}

	asl = ASL_alloc(ASL_read_fg);
	stub = argv[1];
	nl = jac0dim(stub, (fint)strlen(stub));
	
	J = (real *)Malloc(nzc*sizeof(real));
	
	fg_read(nl,0);
	
	X[0] = 5.0;
	X[1] = 2.0;
	X[2] = 3.0;
	
	objVal = objval(0, X, &nerror);
	printf("Objective %.5f\n", objVal);
	
	
	jacval(X, J, &nerror);
	
	printf("nzc %d\n",nzc);
	for(i = 0; i < nzc; i++) {
		printf("%d %g\n",i,J[i]);
	}
	
	for(i = 0; i < n_con; i++) {
		printf("\nRow %d:", i+1);
		fmt = " J[%d]=%g*X%d";
		for(cg = Cgrad[i]; cg; cg = cg->next, fmt = " + J[%d]=%g*X%d") {
			printf(fmt, cg->goff, J[cg->goff], cg->varno+1);
		}
		printf("\n");
	}
	
}
