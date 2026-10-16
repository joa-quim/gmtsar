#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("merge_swath", 2U, 0U, NULL);
	char aopt[4096], gopt[4096], sopt[4096], nopt[64];
	char *args[4];
	int n, status;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_merge_swath(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3 && argc != 4 && argc != 5 && argc != 6) {
		fprintf(stderr, "\n\nUSAGE: merge_swath inputlist output [stem] [n1 n2]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(gopt, sizeof(gopt), "-G%s", argv[2]);
	args[0] = aopt; args[1] = gopt;
	n = 2;
	if (argc == 4) {
		snprintf(sopt, sizeof(sopt), "-S%s", argv[3]);
		args[n++] = sopt;
	}
	else if (argc == 5) {
		snprintf(nopt, sizeof(nopt), "-N%s/%s", argv[3], argv[4]);
		args[n++] = nopt;
	}
	else if (argc == 6) {
		snprintf(sopt, sizeof(sopt), "-S%s", argv[3]);
		snprintf(nopt, sizeof(nopt), "-N%s/%s", argv[4], argv[5]);
		args[n++] = sopt;
		args[n++] = nopt;
	}

	status = GMT_merge_swath(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
