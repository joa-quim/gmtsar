#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("assemble_tops", 2U, 0U, NULL);
	char aopt[32], bopt[32], iopt[4096], oopt[4096];
	char *args[4];
	int i, status;
	size_t used;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_assemble_tops(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc < 5) {
		fprintf(stderr, "\nUsage: assemble_tops azi_1 azi_2 name_stem1 name_stem2 ... output_stem\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}

	snprintf(aopt, sizeof(aopt), "-A%s", argv[1]);
	snprintf(bopt, sizeof(bopt), "-B%s", argv[2]);

	iopt[0] = '\0';
	used = 0;
	for (i = 3; i < argc - 1; ++i) {
		int n = snprintf(iopt + used, sizeof(iopt) - used, "%s%s", used ? "/" : "-I", argv[i]);
		if (n < 0 || (size_t)n >= sizeof(iopt) - used) {
			fprintf(stderr, "assemble_tops: too many/too long input stems\n");
			GMT_Destroy_Session(API);
			return EXIT_FAILURE;
		}
		used += (size_t)n;
	}
	snprintf(oopt, sizeof(oopt), "-O%s", argv[argc - 1]);

	args[0] = aopt; args[1] = bopt; args[2] = iopt; args[3] = oopt;

	status = GMT_assemble_tops(API, 4, args);
	GMT_Destroy_Session(API);
	return status;
}
