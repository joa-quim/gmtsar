#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ENVI_llt2rat", 2U, 0U, NULL);
	char aopt[4096];
	char *args[2];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ENVI_llt2rat(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 2 || argc > 3) {
		fprintf(stderr, "\n Usage: ENVI_llt2rat master.PRM [-bo[s|d]] < inputfile > outputfile\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	args[0] = aopt;
	n = 1;
	if (argc == 3) {
		if (!strcmp(argv[2], "-bos")) args[n++] = "-S";
		else if (!strcmp(argv[2], "-bod")) args[n++] = "-D";
		else {
			fprintf(stderr, " %s *** option not recognized ***\n", argv[2]);
			GMT_Destroy_Session(API);
			return GMT_MODULE_USAGE;
		}
	}

	status = GMT_ENVI_llt2rat(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
