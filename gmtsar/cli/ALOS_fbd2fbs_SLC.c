#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_fbd2fbs_SLC", 2U, 0U, NULL);
	char aopt[4096], bopt[4096];
	char *args[2];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_fbd2fbs_SLC(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3) {
		fprintf(stderr, "ALOS_FBD2FBS_SLC FBD.PRM FBS.PRM\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	args[0] = aopt; args[1] = bopt;

	status = GMT_ALOS_fbd2fbs_SLC(API, 2, args);
	GMT_Destroy_Session(API);
	return status;
}
