#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("envisat_dump_data", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], copt[64];
	char *args[3];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_envisat_dump_data(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3 && argc != 7) {
		fprintf(stderr, "Usage: envisat_dump_data envisat-product outputfile [l0 lN p0 pN]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	args[0] = aopt; args[1] = bopt;
	n = 2;
	if (argc == 7) {
		snprintf(copt, sizeof(copt), "-C%s/%s/%s/%s", argv[3], argv[4], argv[5], argv[6]);
		args[n++] = copt;
	}

	status = GMT_envisat_dump_data(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
