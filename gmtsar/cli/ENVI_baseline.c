#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ENVI_baseline", 2U, 0U, NULL);
	char opt1[4096], opt2[4096];
	char *args[2];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ENVI_baseline(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3) {
		fprintf(stderr, "Usage: (two modes)\n"
		                "mode 1:\n\n"
		                "ENVI_baseline PRM_master PRM_aligned\n\n"
		                "or mode 2:\n\n"
		                "ENVI_baseline -input file\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	if (strncmp(argv[1], "-input", 6) == 0) {
		if (argc != 3) {
			fprintf(stderr, "ENVI_baseline -input file\n");
			GMT_Destroy_Session(API);
			return GMT_MODULE_USAGE;
		}
		snprintf(opt1, sizeof(opt1), "-L%s", argv[2]);
		args[0] = opt1;
		status = GMT_ENVI_baseline(API, 1, args);
	}
	else {
		snprintf(opt1, sizeof(opt1), "-A%s", argv[1]);
		snprintf(opt2, sizeof(opt2), "-B%s", argv[2]);
		args[0] = opt1; args[1] = opt2;
		status = GMT_ENVI_baseline(API, 2, args);
	}

	GMT_Destroy_Session(API);
	return status;
}
