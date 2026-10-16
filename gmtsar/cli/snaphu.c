#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	void *API = GMT_Create_Session("snaphu", 2U, 0U, NULL);
	char converted[64][1024], *args[64];
	int i, n = 0, npos = 0, status = EXIT_FAILURE;

	if (!API) return EXIT_FAILURE;
	if (argc == 2 && argv[1][0] == '-' && argv[1][1] != '\0' && strcmp(argv[1], "-h") && strcmp(argv[1], "--help")) {
		status = GMT_snaphu(API, 1, argv + 1);
		goto done;
	}

	for (i = 1; i < argc && n < 63; ++i) {
		char *a = argv[i];
		if (a[0] != '-') {
			/* positional: first is infile, second is linelen */
			if (npos == 0) { snprintf(converted[n], sizeof(converted[n]), "-D%s", a); args[n] = converted[n]; ++n; npos = 1; }
			else if (npos == 1) { snprintf(converted[n], sizeof(converted[n]), "-R%s", a); args[n] = converted[n]; ++n; npos = 2; }
			else { fprintf(stderr, "snaphu: too many positional arguments: %s\n", a); goto done; }
			continue;
		}
		if (a[1] == '-') {
			/* long option */
			if (!strcmp(a, "--costinfile") || !strcmp(a, "--costoutfile") || !strcmp(a, "--nproc") || !strcmp(a, "--tiledir")) {
				char letter = !strcmp(a, "--costinfile") ? 'B' : !strcmp(a, "--costoutfile") ? 'E' : !strcmp(a, "--nproc") ? 'N' : 'O';
				if (++i >= argc) { fprintf(stderr, "snaphu: %s requires an argument\n", a); goto done; }
				snprintf(converted[n], sizeof(converted[n]), "-%c%s", letter, argv[i]); args[n] = converted[n]; ++n;
			}
			else if (!strcmp(a, "--debug") || !strcmp(a, "--dumpall")) args[n++] = "-F";
			else if (!strcmp(a, "--mst")) args[n++] = "-Hmst";
			else if (!strcmp(a, "--mcf")) args[n++] = "-Hmcf";
			else if (!strcmp(a, "--assemble")) args[n++] = "-P";
			else if (!strcmp(a, "--copyright") || !strcmp(a, "--info")) args[n++] = "-Q";
			else if (!strcmp(a, "--help")) args[n++] = "-h";
			else if (!strcmp(a, "--aa") || !strcmp(a, "--AA")) {
				char letter = a[2] == 'a' ? 'I' : 'J';
				if (i + 2 >= argc) { fprintf(stderr, "snaphu: %s requires two arguments\n", a); goto done; }
				snprintf(converted[n], sizeof(converted[n]), "-%c%s/%s", letter, argv[i + 1], argv[i + 2]);
				args[n] = converted[n]; ++n; i += 2;
			}
			else if (!strcmp(a, "--tile") || !strcmp(a, "--piece")) {
				char letter = a[2] == 't' ? 'K' : 'L';
				if (i + 4 >= argc) { fprintf(stderr, "snaphu: %s requires four arguments\n", a); goto done; }
				snprintf(converted[n], sizeof(converted[n]), "-%c%s/%s/%s/%s", letter, argv[i + 1], argv[i + 2], argv[i + 3], argv[i + 4]);
				args[n] = converted[n]; ++n; i += 4;
			}
			else { fprintf(stderr, "snaphu: unrecognized option %s\n", a); goto done; }
			continue;
		}
		/* short option: booleans pass straight through, value options merge with the next token */
		if (strchr("hutdsqiSknv", a[1]) && a[2] == '\0') { args[n] = a; ++n; continue; }
		if (strchr("ocmMaAewgGlCfbp", a[1]) && a[2] == '\0') {
			if (++i >= argc) { fprintf(stderr, "snaphu: option -%c requires an argument\n", a[1]); goto done; }
			snprintf(converted[n], sizeof(converted[n]), "-%c%s", a[1], argv[i]); args[n] = converted[n]; ++n;
			continue;
		}
		fprintf(stderr, "snaphu: unrecognized option %s\n", a);
		goto done;
	}

	status = GMT_snaphu(API, n, args);
done:
	GMT_Destroy_Session(API);
	return status;
}
