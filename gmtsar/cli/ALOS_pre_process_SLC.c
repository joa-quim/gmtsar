#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ALOS_pre_process_SLC", 2U, 0U, NULL);
	char aopt[4096], bopt[4096];
	char copt[64], dopt[64], eopt[64], fopt[64], gopt[64], hopt[64];
	char *args[20];
	int n, status, i;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ALOS_pre_process_SLC(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 3) {
		fprintf(stderr, "Usage: ALOS_pre_process_SLC imagefile LEDfile [-radius RE] [-swap] "
		                "[-V] [-debug] [-quiet]\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);
	args[0] = aopt; args[1] = bopt;
	n = 2;

#define NEED_VALUE(flag) \
	do { if (++i >= argc) { fprintf(stderr, " no option after %s!\n", flag); GMT_Destroy_Session(API); return GMT_MODULE_USAGE; } } while (0)

	for (i = 3; i < argc; i++) {
		if (!strcmp(argv[i], "-near")) { NEED_VALUE("-near"); snprintf(copt, sizeof(copt), "-C%s", argv[i]); args[n++] = copt; }
		else if (!strcmp(argv[i], "-radius")) { NEED_VALUE("-radius"); snprintf(dopt, sizeof(dopt), "-D%s", argv[i]); args[n++] = dopt; }
		else if (!strcmp(argv[i], "-nrows")) { NEED_VALUE("-nrows"); snprintf(eopt, sizeof(eopt), "-E%s", argv[i]); args[n++] = eopt; }
		else if (!strcmp(argv[i], "-tbias")) { NEED_VALUE("-tbias"); snprintf(fopt, sizeof(fopt), "-F%s", argv[i]); args[n++] = fopt; }
		else if (!strcmp(argv[i], "-rbias")) { NEED_VALUE("-rbias"); snprintf(gopt, sizeof(gopt), "-G%s", argv[i]); args[n++] = gopt; }
		else if (!strcmp(argv[i], "-SLC_factor")) { NEED_VALUE("-SLC_factor"); snprintf(hopt, sizeof(hopt), "-H%s", argv[i]); args[n++] = hopt; }
		else if (!strcmp(argv[i], "-ALOS1")) { args[n++] = "-I"; }
		else if (!strcmp(argv[i], "-ALOS2")) { args[n++] = "-J"; }
		else if (!strcmp(argv[i], "-ALOS4")) { args[n++] = "-K"; }
		else if (!strcmp(argv[i], "-roi")) { args[n++] = "-L"; }
		else if (!strcmp(argv[i], "-LED")) { args[n++] = "-M"; }
		else if (!strcmp(argv[i], "-noLED")) { args[n++] = "-N"; }
		else if (!strcmp(argv[i], "-swap")) { /* byte-swap is auto-detected; no-op */ }
		else if (!strncmp(argv[i], "-debug", 2)) { args[n++] = "-O"; }
		else if (!strncmp(argv[i], "-V", 1) || !strncmp(argv[i], "-v", 1)) { args[n++] = "-V"; }
		else if (!strcmp(argv[i], "-quiet")) { /* documented but never implemented upstream; ignored */ }
		else {
			fprintf(stderr, " %s *** option not recognized ***\n\n", argv[i]);
			GMT_Destroy_Session(API);
			return GMT_MODULE_USAGE;
		}
	}
#undef NEED_VALUE

	status = GMT_ALOS_pre_process_SLC(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
