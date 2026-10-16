#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("asa_im_decode", 2U, 0U, NULL);
	char files[8192], fopt[8200], iopt[4096], oopt[4096], topt[32], nopt[64];
	char *args[5];
	int n = 0, status, numFiles, i;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_asa_im_decode(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if ((argc - 1) < 5) {
		fprintf(stderr, "Usage: asa_im_decode <asa_im...> <asa_ins> <out> <outType> <near_range>\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	numFiles = (argc - 1) - 4;
	files[0] = '\0';
	for (i = 0; i < numFiles; i++) {
		if (i) strncat(files, ",", sizeof(files) - strlen(files) - 1);
		strncat(files, argv[1 + i], sizeof(files) - strlen(files) - 1);
	}
	snprintf(fopt, sizeof(fopt), "-F%s", files);
	snprintf(iopt, sizeof(iopt), "-I%s", argv[numFiles + 1]);
	snprintf(oopt, sizeof(oopt), "-O%s", argv[numFiles + 2]);
	snprintf(topt, sizeof(topt), "-T%s", argv[numFiles + 3]);
	snprintf(nopt, sizeof(nopt), "-N%s", argv[numFiles + 4]);
	args[n++] = fopt; args[n++] = iopt; args[n++] = oopt; args[n++] = topt; args[n++] = nopt;

	status = GMT_asa_im_decode(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
