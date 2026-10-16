#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("xcorr", 2U, 0U, NULL);
	char converted[24][4096], *args[24];
	int i, n = 0, status = EXIT_FAILURE;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_xcorr(API, 1, argv + 1);
		goto done;
	}
	if (argc < 3) {
		fprintf(stderr, "\nUsage: xcorr master.PRM aligned.PRM [-time] [-real] [-freq] [-nx n] [-ny n] "
			"[-xsearch xs] [-ysearch ys]\n");
		goto done;
	}

	snprintf(converted[n], sizeof(converted[n]), "-A%s", argv[1]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-B%s", argv[2]); args[n] = converted[n]; ++n;

	for (i = 3; i < argc && n < 23; ++i) {
		char option = 0;
		if (!strcmp(argv[i], "-time")) { snprintf(converted[n], sizeof(converted[n]), "-Mtime"); args[n] = converted[n]; ++n; continue; }
		if (!strcmp(argv[i], "-time4")) { snprintf(converted[n], sizeof(converted[n]), "-Mtime4"); args[n] = converted[n]; ++n; continue; }
		if (!strcmp(argv[i], "-freq")) { snprintf(converted[n], sizeof(converted[n]), "-Mfreq"); args[n] = converted[n]; ++n; continue; }
		if (!strcmp(argv[i], "-real")) { args[n++] = "-F"; continue; }
		if (!strcmp(argv[i], "-noshift")) { args[n++] = "-N"; continue; }
		if (!strcmp(argv[i], "-nointerp")) { args[n++] = "-Z"; continue; }
		if (!strcmp(argv[i], "-norange")) { args[n++] = "-G1"; continue; }
		if (!strcmp(argv[i], "-v")) { args[n++] = "-V"; continue; }
		if (i + 1 >= argc) goto done;
		option = !strcmp(argv[i], "-range_interp") ? 'G' : !strcmp(argv[i], "-nx") ? 'X' : !strcmp(argv[i], "-ny") ? 'Y' :
			!strcmp(argv[i], "-xsearch") ? 'S' : !strcmp(argv[i], "-ysearch") ? 'T' : !strcmp(argv[i], "-interp") ? 'W' : 0;
		if (!option) {
			fprintf(stderr, " %s *** option not recognized ***\n", argv[i]);
			goto done;
		}
		snprintf(converted[n], sizeof(converted[n]), "-%c%s", option, argv[++i]); args[n] = converted[n]; ++n;
	}

	status = GMT_xcorr(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
