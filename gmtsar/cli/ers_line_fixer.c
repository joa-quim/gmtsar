#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("ers_line_fixer", 2U, 0U, NULL);
	char infiles[4096];
	char aopt[64], hopt[64], lopt[64], sopt[256], iopt[4096], oopt[4096];
	char *args[6];
	int i, n = 0, status;
	int nfiles = 0;
	char *near_range = NULL, *header = NULL, *line = NULL, *station = NULL;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_ers_line_fixer(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}

	infiles[0] = '\0';
	for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-a") && i + 1 < argc) { near_range = argv[++i]; }
		else if (!strcmp(argv[i], "-h") && i + 1 < argc) { header = argv[++i]; }
		else if (!strcmp(argv[i], "-l") && i + 1 < argc) { line = argv[++i]; }
		else if (!strcmp(argv[i], "-s") && i + 1 < argc) { station = argv[++i]; }
		else {
			if (infiles[0]) strncat(infiles, ",", sizeof(infiles) - strlen(infiles) - 1);
			strncat(infiles, argv[i], sizeof(infiles) - strlen(infiles) - 1);
			nfiles++;
		}
	}
	/* last positional argument is the output file, not an input file */
	if (nfiles < 2) {
		fprintf(stderr, "Usage: ers_line_fixer [-a near_range] [-h header] [-l line] [-s station] "
		                "<raw file...> <fixed file>\n");
		GMT_Destroy_Session(API);
		return GMT_MODULE_USAGE;
	}
	{
		char *last_comma = strrchr(infiles, ',');
		snprintf(oopt, sizeof(oopt), "-O%s", last_comma + 1);
		*last_comma = '\0';
	}
	snprintf(iopt, sizeof(iopt), "-I%s", infiles);
	args[n++] = iopt;
	args[n++] = oopt;
	if (near_range) { snprintf(aopt, sizeof(aopt), "-A%s", near_range); args[n++] = aopt; }
	if (header) { snprintf(hopt, sizeof(hopt), "-H%s", header); args[n++] = hopt; }
	if (line) { snprintf(lopt, sizeof(lopt), "-L%s", line); args[n++] = lopt; }
	if (station) { snprintf(sopt, sizeof(sopt), "-S%s", station); args[n++] = sopt; }

	status = GMT_ers_line_fixer(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
