#define THIS_MODULE_CLASSIC_NAME "calc_dop_orb_envi"
#define THIS_MODULE_MODERN_NAME  "calc_dop_orb_envi"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Calculate the Doppler centroid and orbit parameters from an Envisat PRM file"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <errno.h>
#include <stdlib.h>

int gmtsar_calc_dop_orb_envi_run(const char *prmfile, const char *outfile, double re, int have_doppler, double doppler_centroid);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<PRM> -B<output> -C<earth_radius> [-D<doppler_centroid>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the input PRM file; -B selects the output parameter file.");
	GMT_Usage(API, 1, "\n-C sets the earth radius (0 keeps the PRM file's own values).");
	GMT_Usage(API, 1, "\n-D forces the doppler centroid (fd1) instead of calculating it.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_calc_dop_orb_envi(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prmfile = NULL, *outfile = NULL, *end = NULL;
	double re = 0.0, doppler_centroid = 0.0;
	int have_re = 0, have_doppler = 0;
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
			case 'A': prmfile = opt->arg; break;
			case 'B': outfile = opt->arg; break;
			case 'C':
				errno = 0; re = strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-C requires a number\n"); error = GMT_PARSE_ERROR; }
				have_re = 1;
				break;
			case 'D':
				errno = 0; doppler_centroid = strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-D requires a number\n"); error = GMT_PARSE_ERROR; }
				have_doppler = 1;
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!prmfile || !outfile || !have_re)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_calc_dop_orb_envi_run(prmfile, outfile, re, have_doppler, doppler_centroid);

	gmt_end_module(GMT, copy);
	return error;
}
