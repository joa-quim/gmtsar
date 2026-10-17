#define THIS_MODULE_CLASSIC_NAME "nearest_grid"
#define THIS_MODULE_MODERN_NAME  "nearest_grid"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Fill NaN grid nodes from their nearest valid neighbour"
#define THIS_MODULE_KEYS         "<G{,GG}"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
/* This GMT installation was configured with GLib, but its development GLib
 * headers were not installed beside gmt_dev.h.  This module uses no GLib
 * facilities, so keep the private GMT declarations usable without inventing
 * a new Windows runtime dependency. */
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <errno.h>
#include <limits.h>
#include <stdlib.h>

int gmtsar_nearest_grid_run(void *API, const char *input, const char *output, int radius);

static int nearest_grid_usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB,
		THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s <inputgrid> -G<outputgrid> [-S<search_radius>] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n<inputgrid> is the grid whose NaN nodes will be filled.");
	GMT_Usage(API, 1, "\n-G<outputgrid> sets the resulting GMT grid.");
	GMT_Usage(API, 1, "\n-S<search_radius> limits the search in grid nodes; zero searches the full grid.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_nearest_grid(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL;
	struct GMT_CTRL *GMT = NULL, *GMT_cpy = NULL;
	struct GMT_OPTION *opt = NULL;
	const char *input = NULL, *output = NULL;
	char *end = NULL;
	long parsed_radius = 0;
	int error = GMT_NOERROR;

	if (API == NULL) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return nearest_grid_usage(API, GMT_MODULE_PURPOSE);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return nearest_grid_usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return nearest_grid_usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME,
		THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &GMT_cpy);
	if (GMT == NULL) return API->error;

	for (opt = options; opt; opt = opt->next) {
		if (opt->option == '<') { if (input) { error = GMT_PARSE_ERROR; break; } input = opt->arg; }
		else if (opt->option == 'G') output = opt->arg;
		else if (opt->option == 'S') {
		errno = 0;
		parsed_radius = strtol(opt->arg, &end, 10);
		if (errno || end == opt->arg || *end != '\0' || parsed_radius < 0 || parsed_radius > INT_MAX) {
			GMT_Report(API, GMT_MSG_ERROR, "search_radius must be a non-negative integer\n");
			error = GMT_PARSE_ERROR;
			break;
		}
		}
		else if (opt->option != 'V') error += gmt_default_option_error(GMT, opt);
	}
	if (!error && (!input || !output)) error = nearest_grid_usage(API, GMT_USAGE);
	unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
	API->pad = 0U; gmt_set_pad(GMT, 0U);
	if (!error) error = gmtsar_nearest_grid_run(API, input, output, (int)parsed_radius);
	API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);

cleanup:
	gmt_end_module(GMT, GMT_cpy);
	return error;
}
