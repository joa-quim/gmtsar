#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("fitoffset", 2U, 0U, NULL);
	char aopt[32], bopt[32], copt[4096], fopt[4096];
	char *args[4];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_fitoffset(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 5 || argc > 6) {
		fprintf(stderr, "Usage: fitoffset npar_rng npar_azi xcorr.dat prmfile.PRM [SNR]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	snprintf(fopt, sizeof(fopt), "-F%s", argv[4]);
	args[0] = aopt; args[1] = bopt; args[2] = copt; args[3] = fopt;

	status = GMT_fitoffset(API, 4, args);
	GMT_Destroy_Session(API);
	return status;
}
