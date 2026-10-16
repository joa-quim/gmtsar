#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("offset_topo", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], xopt[32], yopt[32], sopt[32], gopt[4096];
	char *args[6];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_offset_topo(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 6 || argc > 7) {
		fprintf(stderr, "\nUsage: offset_topo amp_master.grd topo_ra.grd rshift ashift ns [topo_shift.grd]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(xopt, sizeof(xopt), "-X%s", argv[3]);
	snprintf(yopt, sizeof(yopt), "-Y%s", argv[4]);
	snprintf(sopt, sizeof(sopt), "-S%s", argv[5]);
	args[0] = aopt; args[1] = bopt; args[2] = xopt; args[3] = yopt; args[4] = sopt;
	n = 5;
	if (argc == 7) { snprintf(gopt, sizeof(gopt), "-G%s", argv[6]); args[n++] = gopt; }

	status = GMT_offset_topo(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
