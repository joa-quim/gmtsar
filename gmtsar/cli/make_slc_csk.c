#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_slc_csk", 2U, 0U, NULL);
	char aopt[4096], copt[4096], fopt[64];
	char *args[3];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_slc_csk(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3) {
		fprintf(stderr, "Usage: make_slc_csk name_of_input_file name_output [SLC_factor]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(copt, sizeof(copt), "-C%s", argv[2]);
	args[0] = aopt; args[1] = copt;
	n = 2;
	if (argc == 4) {
		snprintf(fopt, sizeof(fopt), "-F%s", argv[3]);
		args[n++] = fopt;
	}

	status = GMT_make_slc_csk(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
