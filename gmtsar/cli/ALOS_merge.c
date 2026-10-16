#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_merge", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], copt[4096];
	char *args[6];
	int n, status, i;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_merge(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3) {
		fprintf(stderr, "Usage: ALOS_merge PRMfile1 PRMfile2 [-output outfile] [-V] [-nodopp]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	args[0] = aopt; args[1] = bopt;
	n = 2;

	for (i = 3; i < argc; i++) {
		if (!strcmp(argv[i], "-output")) {
			if (++i >= argc) {
				fprintf(stderr, " no option after -output!\n");
				GMT_Destroy_Session(API);
				return GMT_MODULE_USAGE;
			}
			snprintf(copt, sizeof(copt), "-C%s", argv[i]);
			args[n++] = copt;
		}
		else if (!strcmp(argv[i], "-V") || !strcmp(argv[i], "-v")) {
			args[n++] = "-V";
		}
		else if (!strcmp(argv[i], "-nodopp")) {
			args[n++] = "-N";
		}
		else if (!strcmp(argv[i], "-debug")) {
			/* legacy debug flag has no module equivalent; ignored */
		}
		else {
			fprintf(stderr, " %s *** option not recognized ***\n\n", argv[i]);
			GMT_Destroy_Session(API);
			return GMT_MODULE_USAGE;
		}
	}

	status = GMT_ALOS_merge(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
