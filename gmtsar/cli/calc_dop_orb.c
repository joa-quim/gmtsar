#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("calc_dop_orb", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], eopt[64], dopt[64];
	char *args[4];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_calc_dop_orb(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 4 || argc > 5) {
		fprintf(stderr, "\nUsage: calc_dop_orb file.PRM added.PRM earth_radius [doppler_centroid]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(eopt, sizeof(eopt), "-E%s", argv[3]);
	args[0] = aopt; args[1] = bopt; args[2] = eopt;
	n = 3;
	if (argc == 5) { snprintf(dopt, sizeof(dopt), "-D%s", argv[4]); args[n++] = dopt; }

	status = GMT_calc_dop_orb(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
