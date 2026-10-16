#define THIS_MODULE_CLASSIC_NAME "make_gaussian_filter"
#define THIS_MODULE_MODERN_NAME  "make_gaussian_filter"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Create a Gaussian filter for a PRM file"
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

int gmtsar_make_gaussian_filter_run(const char *prmfile, int rng_dec, int azi_dec, int w, const char *out_filename);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<PRM_file> -X<rng_dec> -Y<azi_dec> -W<wavelength_m> [-G<output_filename>] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the PRM file. -X and -Y are the range and azimuth decimation factors (1-4).");
	GMT_Usage(API, 1, "\n-W is the filter wavelength in meters. -G names the output filter file [gauss_<wavelength>].");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_make_gaussian_filter(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prmfile = NULL, *out_filename = NULL, *end = NULL;
	long rng_dec = -1, azi_dec = -1, w = -1;
	int error = GMT_NOERROR;

	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;

#define PARSE_LONG(dest) do { \
		errno = 0; \
		(dest) = strtol(opt->arg, &end, 10); \
		if (errno || end == opt->arg || *end != '\0') { \
			GMT_Report(API, GMT_MSG_ERROR, "-%c requires an integer argument\n", opt->option); \
			error = GMT_PARSE_ERROR; \
		} \
	} while (0)

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'A': prmfile = opt->arg; break;
			case 'G': out_filename = opt->arg; break;
			case 'X': PARSE_LONG(rng_dec); break;
			case 'Y': PARSE_LONG(azi_dec); break;
			case 'W': PARSE_LONG(w); break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
#undef PARSE_LONG
	if (!error && (!prmfile || rng_dec < 0 || azi_dec < 0 || w < 0)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_make_gaussian_filter_run(prmfile, (int)rng_dec, (int)azi_dec, (int)w, out_filename);

	gmt_end_module(GMT, copy);
	return error;
}
