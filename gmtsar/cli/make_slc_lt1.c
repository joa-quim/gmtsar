#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_slc_lt1", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], copt[4096], fopt[64];
	char *args[4];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_slc_lt1(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 4) {
		fprintf(stderr, "Usage: make_slc_lt1 name_of_xml_file name_of_tiff_file name_output [SLC_factor]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(copt, sizeof(copt), "-C%s", argv[3]);
	args[0] = aopt; args[1] = bopt; args[2] = copt;
	n = 3;
	if (argc == 5) {
		snprintf(fopt, sizeof(fopt), "-F%s", argv[4]);
		args[n++] = fopt;
	}

	status = GMT_make_slc_lt1(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
