#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("split_spectrum", 2U, 0U, NULL);
	char aopt[4096];
	char *args[2];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_split_spectrum(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "\nUSAGE: split_spectrum prm1 [split_half]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	args[0] = aopt;
	n = 1;
	if (argc == 3 && !strcmp(argv[2], "1")) args[n++] = "-H";

	status = GMT_split_spectrum(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
