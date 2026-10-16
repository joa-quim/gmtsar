#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
int main(int argc, char **argv) {
	void *API;
	char fopt[4096], nopt[4096];
	char *args[2];
	int status;
	API = GMT_Create_Session("get_PRM", 2U, 0U, NULL);
	if (!API) return 1;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_get_PRM(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3) { GMT_Destroy_Session(API); return GMT_MODULE_USAGE; }
	snprintf(fopt, sizeof(fopt), "-F%s", argv[1]);
	snprintf(nopt, sizeof(nopt), "-N%s", argv[2]);
	args[0] = fopt; args[1] = nopt;
	status = GMT_get_PRM(API, 2, args);
	GMT_Destroy_Session(API);
	return status;
}
