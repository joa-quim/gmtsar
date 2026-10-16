#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
int main(int argc, char **argv) {
	void *API;
	char gopt[4096], sopt[64];
	char *args[3];
	int n = 2, status;
	API = GMT_Create_Session("nearest_grid", 2U, 0U, NULL);
	if (!API) return 1;
	if (argc == 2 && argv[1][0] == '-') {
		status = GMT_nearest_grid(API, 1, argv + 1);
		GMT_Destroy_Session(API);
		return status;
	}
	if (argc != 3 && argc != 4) { GMT_Destroy_Session(API); return GMT_MODULE_USAGE; }
	snprintf(gopt, sizeof(gopt), "-G%s", argv[2]);
	args[0] = argv[1]; args[1] = gopt;
	if (argc == 4) { snprintf(sopt, sizeof(sopt), "-S%s", argv[3]); args[n++] = sopt; }
	status = GMT_nearest_grid(API, n, args);
	GMT_Destroy_Session(API);
	return status;
}
