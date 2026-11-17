#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* sbas0 intf.tab [-wavelength wl] [-rows nr] [-reference rng0 azi0] [-partial_coverage]
   is translated to: -A<intf.tab> [-W<wl>] [-L<nr>] [-C<rng0>/<azi0>] [-P].
   A first argument starting with '-' means GMT-style options: passed through as is. */
int main(int argc, char **argv) {
	void *API = GMT_Create_Session("sbas0", 2U, 0U, NULL);
	char converted[8][4096], *args[8];
	int i, n = 0, status = EXIT_FAILURE;

	if (!API) return EXIT_FAILURE;
	if (argc > 1 && argv[1][0] == '-') {
		status = GMT_sbas0(API, argc - 1, argv + 1);
		goto done;
	}
	if (argc < 2) {
		fprintf(stderr, "USAGE: sbas0 intf.tab [-wavelength wl] [-rows nr] [-reference rng0 azi0] [-partial_coverage]\n");
		goto done;
	}

	snprintf(converted[n], sizeof(converted[n]), "-A%s", argv[1]); args[n] = converted[n]; ++n;
	for (i = 2; i < argc; ++i) {
		if (n >= 7) {
			fprintf(stderr, " too many arguments\n");
			goto done;
		}
		if (!strcmp(argv[i], "-partial_coverage")) { args[n++] = "-P"; continue; }
		if (!strcmp(argv[i], "-reference") && i + 2 < argc) {
			snprintf(converted[n], sizeof(converted[n]), "-C%s/%s", argv[i+1], argv[i+2]); args[n] = converted[n]; ++n;
			i += 2;
			continue;
		}
		char option = !strcmp(argv[i], "-wavelength") ? 'W' : !strcmp(argv[i], "-rows") ? 'L' : 0;
		if (!option || i + 1 >= argc) {
			fprintf(stderr, " %s *** option not recognized or missing its value ***\n", argv[i]);
			goto done;
		}
		snprintf(converted[n], sizeof(converted[n]), "-%c%s", option, argv[++i]); args[n] = converted[n]; ++n;
	}

	status = GMT_sbas0(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
