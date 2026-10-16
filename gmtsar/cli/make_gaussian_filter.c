#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_gaussian_filter", 2U, 0U, NULL);
	char aopt[4096], xopt[32], yopt[32], wopt[32], gopt[4096];
	char *args[5];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_gaussian_filter(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 5 || argc > 6) {
		fprintf(stderr, "\nUsage: make_gaussian_filter name_of_PRM_file RNG_DEC AZI_DEC WAVELENGTH(m) [output_filename]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(xopt, sizeof(xopt), "-X%s", argv[2]);
	snprintf(yopt, sizeof(yopt), "-Y%s", argv[3]);
	snprintf(wopt, sizeof(wopt), "-W%s", argv[4]);
	args[0] = aopt; args[1] = xopt; args[2] = yopt; args[3] = wopt;
	n = 4;
	if (argc == 6) { snprintf(gopt, sizeof(gopt), "-G%s", argv[5]); args[n++] = gopt; }

	status = GMT_make_gaussian_filter(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
