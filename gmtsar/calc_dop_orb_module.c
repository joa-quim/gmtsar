#define THIS_MODULE_CLASSIC_NAME "calc_dop_orb"
#define THIS_MODULE_MODERN_NAME  "calc_dop_orb"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Calculate the Doppler polynomial and orbit parameters from a PRM file"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <stdlib.h>

int gmtsar_calc_dop_orb_run(const char *file_in, const char *file_out, double re, int have_doppler, double doppler_centroid);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<file.PRM> -B<added.PRM> -E<earth_radius> [-D<doppler_centroid>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the input PRM file; -B is the output file of additional parameters to append.");
	GMT_Usage(API, 1, "\n-E sets the earth radius (0 to calculate it).");
	GMT_Usage(API, 1, "\n-D forces the Doppler centroid to a given value instead of computing it.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_calc_dop_orb(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *file_in = NULL, *file_out = NULL, *re_str = NULL, *doppler_str = NULL;
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
			case 'A': file_in = opt->arg; break;
			case 'B': file_out = opt->arg; break;
			case 'E': re_str = opt->arg; break;
			case 'D': doppler_str = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!file_in || !file_out || !re_str)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_calc_dop_orb_run(file_in, file_out, atof(re_str), doppler_str != NULL,
		doppler_str ? atof(doppler_str) : 0.0);

	gmt_end_module(GMT, copy);
	return error;
}
