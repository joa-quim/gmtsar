#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_mosaic_ss", 2U, 0U, NULL);
	char pair[5][2048];
	char aopt[5][2064];
	char gopt[64], hopt[64];
	char *args[8];
	int i, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_mosaic_ss(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 14) {
		fprintf(stderr, " ALOS_mosaic_ss prmfile1 grd1 prmfile2 grd2 prmfile3 grd3 prmfile4 grd4 "
		                "prmfile5 grd5 mosaic dec dir\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	for (i = 0; i < 5; i++) {
		snprintf(pair[i], sizeof(pair[i]), "%s,%s", argv[1 + 2 * i], argv[2 + 2 * i]);
		snprintf(aopt[i], sizeof(aopt[i]), "-%c%s", 'A' + i, pair[i]);
		args[i] = aopt[i];
	}
	snprintf(gopt, sizeof(gopt), "-G%s", argv[12]);
	snprintf(hopt, sizeof(hopt), "-H%s", argv[13]);

	{
		char fopt[4096];
		snprintf(fopt, sizeof(fopt), "-F%s", argv[11]);
		args[5] = fopt;
		args[6] = gopt;
		args[7] = hopt;
		status = GMT_ALOS_mosaic_ss(API, 8, args);
	}

	GMT_Destroy_Session(API);
	return status;
}
