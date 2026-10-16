#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_mosaic_ss_2frames", 2U, 0U, NULL);
	char pair[10][2048];
	char aopt[10][2064];
	char kopt[4096], lopt[64], mopt[64];
	char *args[13];
	int i, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_mosaic_ss_2frames(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 24) {
		fprintf(stderr, " ALOS_mosaic_ss_2frames prmfile1 grd1 ... prmfile10 grd10 mosaic dec dir\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	for (i = 0; i < 10; i++) {
		snprintf(pair[i], sizeof(pair[i]), "%s,%s", argv[1 + 2 * i], argv[2 + 2 * i]);
		snprintf(aopt[i], sizeof(aopt[i]), "-%c%s", 'A' + i, pair[i]);
		args[i] = aopt[i];
	}
	snprintf(kopt, sizeof(kopt), "-K%s", argv[21]);
	snprintf(lopt, sizeof(lopt), "-L%s", argv[22]);
	snprintf(mopt, sizeof(mopt), "-M%s", argv[23]);
	args[10] = kopt;
	args[11] = lopt;
	args[12] = mopt;

	status = GMT_ALOS_mosaic_ss_2frames(API, 13, args);
	GMT_Destroy_Session(API);
	return status;
}
