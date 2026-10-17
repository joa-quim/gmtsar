#define THIS_MODULE_CLASSIC_NAME "split_spectrum"
#define THIS_MODULE_MODERN_NAME  "split_spectrum"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Split the range spectrum of an SLC to estimate ionospheric delay"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_split_spectrum_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<prm1> [-H] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the SLC's PRM file. SLCs are bandpassed with a modified cosine "
		"filter and shifted to the center of the spectrum; outputs are SLCH/SLCL (high.tiff/low.tiff for TOPS).");
	GMT_Usage(API, 1, "\n-H uses half the spectrum (for ALOS FBD/FBS cases).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_split_spectrum(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prm1 = NULL;
	char *legacy[3];
	int half_band = 0, argc = 2, error = GMT_NOERROR;

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
			case 'A': prm1 = opt->arg; break;
			case 'H': half_band = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && !prm1) error = usage(API, GMT_USAGE);

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
	legacy[1] = prm1;
	if (half_band) { legacy[2] = "1"; argc = 3; }
	unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
	API->pad = 0U; gmt_set_pad(GMT, 0U);
	if (!error) error = gmtsar_split_spectrum_run(API, argc, legacy);
	API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);

	gmt_end_module(GMT, copy);
	return error;
}
