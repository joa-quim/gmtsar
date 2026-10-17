#define THIS_MODULE_CLASSIC_NAME "p_scatter"
#define THIS_MODULE_MODERN_NAME  "p_scatter"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Compute average amplitude or persistent-scatterer statistics from aligned SLCs"
#define THIS_MODULE_KEYS         "GG}"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int gmtsar_p_scatter_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<PRM_filelist> -G<fileout.grd> -M<mode> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is a text file listing the aligned SLC PRM files.");
	GMT_Usage(API, 1, "\n-G writes the average-amplitude or persistent-scatter grid.");
	GMT_Usage(API, 1, "\n-M sets the mode: 0 amplitude; 1 persistent-scatter; 2 compute and apply persistent-scatter.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_p_scatter(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *filelist = NULL, *fileout = NULL, *end = NULL;
	char *legacy[4];
	long imode = -1;
	int error = GMT_NOERROR;

	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'A': filelist = opt->arg; break;
			case 'G': fileout = opt->arg; break;
			case 'M':
				errno = 0; imode = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0' || imode < 0 || imode > 2) {
					GMT_Report(API, GMT_MSG_ERROR, "-M must be 0, 1, or 2\n");
					error = GMT_PARSE_ERROR;
				}
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!filelist || !fileout || imode < 0)) error = usage(API, GMT_USAGE);

	if (!error) {
		char mode_str[8];
		snprintf(mode_str, sizeof(mode_str), "%ld", imode);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = filelist;
		legacy[2] = fileout;
		legacy[3] = mode_str;
		unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
		API->pad = 0U; gmt_set_pad(GMT, 0U);
		error = gmtsar_p_scatter_run(API, 4, legacy);
		API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	}

	gmt_end_module(GMT, copy);
	return error;
}
