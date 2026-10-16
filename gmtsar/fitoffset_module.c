#define THIS_MODULE_CLASSIC_NAME "fitoffset"
#define THIS_MODULE_MODERN_NAME  "fitoffset"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Fit a polynomial model to offset measurements and update a PRM file"
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
#include <stdio.h>
#include <stdlib.h>

int gmtsar_fitoffset_run(int rng_p, int azi_p, const char *xcorr_file, const char *prmfile);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<npar_rng> -B<npar_azi> -C<xcorr.dat> -F<prmfile.PRM> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B set the number of range and azimuth model parameters.");
	GMT_Usage(API, 1, "\n-C selects the xcorr.dat offsets file (see xcorr).");
	GMT_Usage(API, 1, "\n-F selects the PRM file to update in place.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_fitoffset(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *xcorr_file = NULL, *prmfile = NULL, *end = NULL;
	long rng_p = -1, azi_p = -1;
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
			case 'A':
				errno = 0; rng_p = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-A requires an integer\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'B':
				errno = 0; azi_p = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-B requires an integer\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'C': xcorr_file = opt->arg; break;
			case 'F': prmfile = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (rng_p < 0 || azi_p < 0 || !xcorr_file || !prmfile)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_fitoffset_run((int)rng_p, (int)azi_p, xcorr_file, prmfile);

	gmt_end_module(GMT, copy);
	return error;
}
