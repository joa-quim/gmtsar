#define THIS_MODULE_CLASSIC_NAME "spectral_diversity"
#define THIS_MODULE_MODERN_NAME  "spectral_diversity"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Estimate residual coregistration shift from Sentinel-1 TOPS spectral diversity"
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

int gmtsar_spectral_diversity_run(const char *master_stem, const char *aligned_stem, int bshift, const char *filter_file);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<master_stem> -B<aligned_stem> -S<bshift> -F<filter> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B are the master and aligned stems (must have .SLCH/.SLCL/.BB files present).");
	GMT_Usage(API, 1, "\n-S is the burst shift; -F is the smoothing filter file.");
	GMT_Usage(API, 1, "\nWrites the ddphase file and prints residual_shift.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_spectral_diversity(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *master_stem = NULL, *aligned_stem = NULL, *filter_file = NULL, *end = NULL;
	long bshift = 0;
	int have_s = 0, error = GMT_NOERROR;

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
			case 'A': master_stem = opt->arg; break;
			case 'B': aligned_stem = opt->arg; break;
			case 'F': filter_file = opt->arg; break;
			case 'S':
				errno = 0; bshift = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-S requires an integer\n"); error = GMT_PARSE_ERROR; }
				have_s = 1;
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!master_stem || !aligned_stem || !have_s || !filter_file)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_spectral_diversity_run(master_stem, aligned_stem, (int)bshift, filter_file);

	gmt_end_module(GMT, copy);
	return error;
}
