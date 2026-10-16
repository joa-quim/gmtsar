#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("conv", 2U, 0U, NULL);
	char xopt[32], yopt[32], copt[4096], iopt[4096], gopt[4096];
	char *args[5];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_conv(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 6) {
		fprintf(stderr, "\nUsage: conv idec jdec filter_file input output\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(xopt, sizeof(xopt), "-X%s", argv[1]);
	snprintf(yopt, sizeof(yopt), "-Y%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	snprintf(iopt, sizeof(iopt), "-I%s", argv[4]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[5]);
	args[0] = xopt; args[1] = yopt; args[2] = copt; args[3] = iopt; args[4] = gopt;

	status = GMT_conv(API, 5, args);
	GMT_Destroy_Session(API);
	return status;
}
