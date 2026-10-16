#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("asa_cat", 2U, 0U, NULL);
	char files[8192], fopt[8200], oopt[4096], copt[32];
	char *args[3];
	int n = 0, status, numFiles, i;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_asa_cat(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if ((argc - 1) < 3 || sscanf(argv[1], "%d", &numFiles) != 1 || numFiles < 1 || (argc - 3) < numFiles) {
		fprintf(stderr, "Usage: asa_cat <NumFiles2Cat> <asa_file1> <asa_file2> <...> <out_file> [catAbort]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	files[0] = '\0';
	for (i = 0; i < numFiles; i++) {
		if (i) strncat(files, ",", sizeof(files) - strlen(files) - 1);
		strncat(files, argv[2 + i], sizeof(files) - strlen(files) - 1);
	}
	snprintf(fopt, sizeof(fopt), "-F%s", files);
	snprintf(oopt, sizeof(oopt), "-O%s", argv[numFiles + 2]);
	args[n++] = fopt;
	args[n++] = oopt;
	if (argc > (numFiles + 3)) {
		snprintf(copt, sizeof(copt), "-C%s", argv[numFiles + 3]);
		args[n++] = copt;
	}

	status = GMT_asa_cat(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
