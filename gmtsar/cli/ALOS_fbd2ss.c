#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_fbd2ss", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], copt[64], dopt[64], eopt[64];
	char *args[5];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_fbd2ss(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 6) {
		fprintf(stderr, "ALOS_fbd2ss FBD.PRM SW4.PRM ashift ntot a_stretch_a\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	snprintf(dopt, sizeof(dopt), "-D%s", argv[4]);
	snprintf(eopt, sizeof(eopt), "-E%s", argv[5]);
	args[0] = aopt; args[1] = bopt; args[2] = copt; args[3] = dopt; args[4] = eopt;

	status = GMT_ALOS_fbd2ss(API, 5, args);
	GMT_Destroy_Session(API);
	return status;
}
