#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_slc_nsr", 2U, 0U, NULL);
	char aopt[4096], copt[4096], topt[16], fopt[64], ropt[128];
	char *args[5];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_slc_nsr(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 5) {
		fprintf(stderr, "Usage: make_slc_nsr name_of_input_file name_output output_type scale_factor [region_cut]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(copt, sizeof(copt), "-C%s", argv[2]);
	snprintf(topt, sizeof(topt), "-T%s", argv[3]);
	snprintf(fopt, sizeof(fopt), "-F%s", argv[4]);
	args[0] = aopt; args[1] = copt; args[2] = topt; args[3] = fopt;
	n = 4;
	if (argc == 6) {
		snprintf(ropt, sizeof(ropt), "-R%s", argv[5]);
		args[n++] = ropt;
	}

	status = GMT_make_slc_nsr(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
