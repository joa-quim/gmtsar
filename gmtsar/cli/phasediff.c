#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
	void *API = GMT_Create_Session("phasediff", 2U, 0U, NULL);
	char a[4096], b[4096], converted[4][4096], *args[6];
	int i, n = 2, status;
	if (!API) return 1;
	if (argc == 2 && argv[1][0] == '-') { status = GMT_phasediff(API, 1, argv + 1); goto done; }
	if (argc < 3) { status = GMT_MODULE_USAGE; goto done; }
	snprintf(a, sizeof(a), "-A%s", argv[1]); snprintf(b, sizeof(b), "-B%s", argv[2]);
	args[0] = a; args[1] = b;
	for (i = 3; i + 1 < argc && n < 6; i += 2) {
		char option = !strcmp(argv[i], "-topo") ? 'T' : !strcmp(argv[i], "-model") ? 'M' :
		              !strcmp(argv[i], "-real") ? 'E' : !strcmp(argv[i], "-imag") ? 'Q' : 0;
		if (!option) { status = EXIT_FAILURE; goto done; }
		snprintf(converted[n - 2], sizeof(converted[0]), "-%c%s", option, argv[i + 1]);
		args[n] = converted[n - 2]; ++n;
	}
	status = GMT_phasediff(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
