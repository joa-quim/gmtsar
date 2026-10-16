#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("resamp", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], gopt[4096], sopt[4096], iopt[64], copt[4096], dopt[4096];
	char *args[7];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_resamp(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 6 && argc != 8) {
		fprintf(stderr, "\nUsage: resamp master.PRM aligned.PRM new_aligned.PRM new_aligned.SLC intrp [dr.grd da.grd]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[3]);
	snprintf(sopt, sizeof(sopt), "-S%s", argv[4]);
	snprintf(iopt, sizeof(iopt), "-I%s", argv[5]);
	args[0] = aopt; args[1] = bopt; args[2] = gopt; args[3] = sopt; args[4] = iopt;
	n = 5;
	if (argc == 8) {
		snprintf(copt, sizeof(copt), "-C%s", argv[6]);
		snprintf(dopt, sizeof(dopt), "-D%s", argv[7]);
		args[n++] = copt;
		args[n++] = dopt;
	}

	status = GMT_resamp(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
