#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("make_s1a_tops_6par", 2U, 0U, NULL);
	char aopt[4096], bopt[4096], gopt[4096], mopt[32];
	char ropt[32], zopt[32], xopt[32], yopt[32], sopt[32], topt[32];
	char *args[10];
	int status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_make_s1a_tops_6par(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 11) {
		fprintf(stderr, "\nUsage: make_s1a_tops_6par xml_file tiff_file output mode rng_shift azi_shift "
			"stretch_a a_stretch_a stretch_r a_stretch_r\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[3]);
	snprintf(mopt, sizeof(mopt), "-M%s", argv[4]);
	snprintf(ropt, sizeof(ropt), "-R%s", argv[5]);
	snprintf(zopt, sizeof(zopt), "-Z%s", argv[6]);
	snprintf(xopt, sizeof(xopt), "-X%s", argv[7]);
	snprintf(yopt, sizeof(yopt), "-Y%s", argv[8]);
	snprintf(sopt, sizeof(sopt), "-S%s", argv[9]);
	snprintf(topt, sizeof(topt), "-T%s", argv[10]);
	args[0] = aopt; args[1] = bopt; args[2] = gopt; args[3] = mopt;
	args[4] = ropt; args[5] = zopt; args[6] = xopt; args[7] = yopt; args[8] = sopt; args[9] = topt;

	status = GMT_make_s1a_tops_6par(API, 10, args);
	GMT_Destroy_Session(API);
	return status;
}
