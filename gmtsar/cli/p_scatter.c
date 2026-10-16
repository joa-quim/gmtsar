#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("p_scatter", 2U, 0U, NULL);
	char aopt[4096], gopt[4096], mopt[32];
	char *args[3];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_p_scatter(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 4) {
		fprintf(stderr, "\nUsage: p_scatter PRM_filelist fileout.grd mode\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[2]);
	snprintf(mopt, sizeof(mopt), "-M%s", argv[3]);
	args[0] = aopt; args[1] = gopt; args[2] = mopt;

	status = GMT_p_scatter(API, 3, args);
	GMT_Destroy_Session(API);
	return status;
}
