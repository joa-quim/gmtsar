#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("sbas", 2U, 0U, NULL);
	char converted[24][4096], *args[24];
	int i, n = 0, status = EXIT_FAILURE;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_sbas(API, 1, argv + 1);
		goto done;
	}
	if (argc < 7) {
		fprintf(stderr, "USAGE: sbas intf.tab scene.tab N S xdim ydim [-atm ni] [-smooth sf] "
			"[-wavelength wl] [-incidence inc] [-range rng] [-rms] [-dem] [-mmap] [-robust]\n");
		goto done;
	}

	snprintf(converted[n], sizeof(converted[n]), "-A%s", argv[1]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-B%s", argv[2]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-N%s", argv[3]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-S%s", argv[4]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-X%s", argv[5]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-Y%s", argv[6]); args[n] = converted[n]; ++n;

	for (i = 7; i < argc && n < 23; ++i) {
		if (!strcmp(argv[i], "-rms")) { args[n++] = "-Q"; continue; }
		if (!strcmp(argv[i], "-dem")) { args[n++] = "-E"; continue; }
		if (!strcmp(argv[i], "-mmap")) { args[n++] = "-P"; continue; }
		if (!strcmp(argv[i], "-robust")) { args[n++] = "-U"; continue; }
		char option = !strcmp(argv[i], "-smooth") ? 'M' : !strcmp(argv[i], "-atm") ? 'T' :
			!strcmp(argv[i], "-wavelength") ? 'W' : !strcmp(argv[i], "-incidence") ? 'C' :
			!strcmp(argv[i], "-range") ? 'D' : 0;
		if (!option || i + 1 >= argc) {
			fprintf(stderr, " %s *** option not recognized ***\n", argv[i]);
			goto done;
		}
		snprintf(converted[n], sizeof(converted[n]), "-%c%s", option, argv[++i]); args[n] = converted[n]; ++n;
	}

	status = GMT_sbas(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
