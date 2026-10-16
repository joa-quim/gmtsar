#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("extend_orbit", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], fopt[64];
	char *args[3];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_extend_orbit(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 4) {
		fprintf(stderr, "\nUsage: extend_orbit file_in.LED file_out.LED frac\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(fopt, sizeof(fopt), "-F%s", argv[3]);
	args[0] = aopt; args[1] = bopt; args[2] = fopt;

	status = GMT_extend_orbit(API, 3, args);
	GMT_Destroy_Session(API);
	return status;
}
