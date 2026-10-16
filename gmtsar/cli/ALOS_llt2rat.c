#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_llt2rat", 2U, 0U, NULL);
	char aopt[4096], popt[32];
	char *args[3];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_llt2rat(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3 || argc > 4) {
		fprintf(stderr, "\n Usage: ALOS_llt2rat master.PRM prec [-bo[s|d]] < inputfile > outputfile\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(popt, sizeof(popt), "-P%s", argv[2]);
	args[0] = aopt; args[1] = popt;
	n = 2;
	if (argc == 4) {
		if (!strcmp(argv[3], "-bos")) args[n++] = "-S";
		else if (!strcmp(argv[3], "-bod")) args[n++] = "-D";
		else {
			fprintf(stderr, " %s *** option not recognized ***\n", argv[3]);
			GMT_Destroy_Session(API);
			return GMT_MODULE_USAGE;
		}
	}

	status = GMT_ALOS_llt2rat(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
