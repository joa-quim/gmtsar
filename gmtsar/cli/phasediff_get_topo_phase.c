#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("phasediff_get_topo_phase", 2U, 0U, NULL);
	char converted[8][4096], *args[8];
	int i, n = 0, status = EXIT_FAILURE;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_phasediff_get_topo_phase(API, 1, argv + 1);
		goto done;
	}
	if (argc < 3) {
		fprintf(stderr, "\nUsage: phasediff_get_topo_phase ref.PRM rep.PRM [-topo topo_ra.grd] [-model modelphase.grd]\n");
		goto done;
	}

	snprintf(converted[n], sizeof(converted[n]), "-A%s", argv[1]); args[n] = converted[n]; ++n;
	snprintf(converted[n], sizeof(converted[n]), "-B%s", argv[2]); args[n] = converted[n]; ++n;
	for (i = 3; i < argc && n < 7; ++i) {
		char option = !strcmp(argv[i], "-topo") ? 'T' : !strcmp(argv[i], "-model") ? 'M' : 0;
		if (!option || i + 1 >= argc) goto done;
		snprintf(converted[n], sizeof(converted[n]), "-%c%s", option, argv[++i]); args[n] = converted[n]; ++n;
	}

	status = GMT_phasediff_get_topo_phase(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
