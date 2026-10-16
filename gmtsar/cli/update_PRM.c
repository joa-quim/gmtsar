#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("update_PRM", 2U, 0U, NULL);
	char aopt[4096], nopt[4096], copt[4096];
	char *args[3];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_update_PRM(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 4) {
		fprintf(stderr, "\nUsage: update_PRM file.PRM parameter value\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(nopt, sizeof(nopt), "-N%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	args[0] = aopt; args[1] = nopt; args[2] = copt;

	status = GMT_update_PRM(API, 3, args);
	GMT_Destroy_Session(API);
	return status;
}
