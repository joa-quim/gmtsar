#define THIS_MODULE_CLASSIC_NAME "resamp"
#define THIS_MODULE_MODERN_NAME  "resamp"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Resample a secondary SLC image onto a master image geometry"
#define THIS_MODULE_KEYS         "CG(,DG("
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

int gmtsar_resamp_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<master.PRM> -B<aligned.PRM> -G<new_aligned.PRM> -S<new_aligned.SLC> "
		"-I<method> [-C<dr.grd>] [-D<da.grd>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B select the master and aligned PRM files.");
	GMT_Usage(API, 1, "\n-G and -S select the resampled PRM and SLC outputs.");
	GMT_Usage(API, 1, "\n-I sets the interpolation method: 1-nearest; 2-bilinear; 3-biquadratic; 4-bisinc; 5-bisinc-grid.");
	GMT_Usage(API, 1, "\n-C and -D supply the range and azimuth coregistration grids required by -I5.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_resamp(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *master = NULL, *aligned = NULL, *outprm = NULL, *outslc = NULL, *rgrid = NULL, *agrid = NULL;
	char *end = NULL;
	char *legacy[8];
	long method = 0;
	int argc = 6, error = 0;

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
			case 'A': master = opt->arg; break;
			case 'B': aligned = opt->arg; break;
			case 'G': outprm = opt->arg; break;
			case 'S': outslc = opt->arg; break;
			case 'C': rgrid = opt->arg; break;
			case 'D': agrid = opt->arg; break;
			case 'I':
				errno = 0;
				method = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0' || method < 1 || method > 5) {
					GMT_Report(API, GMT_MSG_ERROR, "-I method must be an integer between 1 and 5\n");
					error = GMT_PARSE_ERROR;
				}
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!master || !aligned || !outprm || !outslc || method == 0)) error = usage(API, GMT_USAGE);
	if (!error && method == 5 && (!rgrid || !agrid)) {
		GMT_Report(API, GMT_MSG_ERROR, "-I5 requires both -C<dr.grd> and -D<da.grd>\n");
		error = GMT_PARSE_ERROR;
	}

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
	legacy[1] = master;
	legacy[2] = aligned;
	legacy[3] = outprm;
	legacy[4] = outslc;
	if (!error) {
		char method_str[8];
		snprintf(method_str, sizeof(method_str), "%ld", method);
		legacy[5] = method_str;
		if (method == 5) {
			legacy[6] = rgrid;
			legacy[7] = agrid;
			argc = 8;
		}
		error = gmtsar_resamp_run(API, argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
