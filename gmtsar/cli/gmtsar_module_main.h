#ifndef GMTSAR_MODULE_MAIN_H
#define GMTSAR_MODULE_MAIN_H

#include "../gmtsar_commands.h"
#include "gmt.h"

#define GMTSAR_MODULE_MAIN(symbol) \
	int main(int argc, char **argv) { \
		void *API = GMT_Create_Session(#symbol, 2U, 0U, NULL); \
		int status; \
		if (API == NULL) return EXIT_FAILURE; \
		status = GMT_##symbol(API, argc - 1, argv + 1); \
		if (GMT_Destroy_Session(API) != GMT_NOERROR && status == GMT_NOERROR) status = EXIT_FAILURE; \
		return status; \
	}

#endif
