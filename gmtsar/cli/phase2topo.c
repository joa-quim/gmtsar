#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("phase2topo", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], copt[4096], gopt[4096];
	char *args[4];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_phase2topo(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 5) {
		fprintf(stderr, "\nUsage: phase2topo master.PRM topo_in.grd res_phase.grd topo_out.grd\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[4]);
	args[0] = aopt; args[1] = bopt; args[2] = copt; args[3] = gopt;

	status = GMT_phase2topo(API, 4, args);
	GMT_Destroy_Session(API);
	return status;
}
