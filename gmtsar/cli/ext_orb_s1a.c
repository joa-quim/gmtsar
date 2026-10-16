#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ext_orb_s1a", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], gopt[4096];
	char *args[3];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ext_orb_s1a(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 4) {
		fprintf(stderr, "\n\nUsage: ext_orb_s1a name_of_prm name_of_orb_xml name_output\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[3]);
	args[0] = aopt; args[1] = bopt; args[2] = gopt;

	status = GMT_ext_orb_s1a(API, 3, args);
	GMT_Destroy_Session(API);
	return status;
}
