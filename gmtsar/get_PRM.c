#include "update_PRM.h"
#include "gmtsar_commands.h"
#include <stdio.h>

int gmtsar_get_PRM_run(const char *file, const char *parameter) {

	char *szString = NULL;

	szString = get_PRM((char *)file, (char *)parameter);
	if (szString == NULL) return EXIT_FAILURE;
	fprintf(stdout, "%s\n", szString);

	fflush(stdout);		/* Make sure output buffer is flushed  */

	if (szString)
		free(szString);

	return 0;
}

int gmtsar_get_PRM(int argc, char **argv) {
	if (argc != 3 && argc != 4) {
		fprintf(stderr, "Usage: get_PRM file.PRM param\n");
		return 1;
	}
	return gmtsar_get_PRM_run(argv[1], argv[2]);
}
