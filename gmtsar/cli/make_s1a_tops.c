#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_s1a_tops", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], gopt[4096], mopt[32], copt[4096], dopt[4096];
	char *args[6];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_s1a_tops(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 5 && argc != 7) {
		fprintf(stderr, "\nUsage: make_s1a_tops xml_file tiff_file output mode [dr.grd da.grd]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[3]);
	snprintf(mopt, sizeof(mopt), "-M%s", argv[4]);
	args[0] = aopt; args[1] = bopt; args[2] = gopt; args[3] = mopt;
	n = 4;
	if (argc == 7) {
		snprintf(copt, sizeof(copt), "-C%s", argv[5]);
		snprintf(dopt, sizeof(dopt), "-D%s", argv[6]);
		args[n++] = copt; args[n++] = dopt;
	}

	status = GMT_make_s1a_tops(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
