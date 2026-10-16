#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("esarp", 2U, 0U, NULL);
	char aopt[4096], bopt[4096];
	char *args[3];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_esarp(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3 || argc > 4) {
		fprintf(stderr, "\nUsage: esarp filein.PRM fileout.SLC [R4]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	args[0] = aopt; args[1] = bopt;
	n = 2;
	if (argc == 4 && (argv[3][0] == 'r' || argv[3][0] == 'R')) args[n++] = "-F";

	status = GMT_esarp(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
