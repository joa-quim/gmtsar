#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("stitch_tops", 2U, 0U, NULL);
	char aopt[4096], gopt[4096];
	char *args[2];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_stitch_tops(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3) {
		fprintf(stderr, "\n\nUSAGE: stitch_tops stem.in output_stem\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[2]);
	args[0] = aopt; args[1] = gopt;

	status = GMT_stitch_tops(API, 2, args);
	GMT_Destroy_Session(API);
	return status;
}
