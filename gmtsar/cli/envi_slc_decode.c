#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("envi_slc_decode", 2U, 0U, NULL);
	char aopt[4096];
	char *args[1];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_envi_slc_decode(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 2) {
		fprintf(stderr, "Usage: envi_slc_decode name_of_data_file (*.E1 *.E2 or *.N1)\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	args[0] = aopt;

	status = GMT_envi_slc_decode(API, 1, args);
	GMT_Destroy_Session(API);
	return status;
}
