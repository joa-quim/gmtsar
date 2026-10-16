#define THIS_MODULE_CLASSIC_NAME "cut_slc"
#define THIS_MODULE_MODERN_NAME  "cut_slc"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Cut a region from a coregistered SLC image"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_cut_slc_run(const char *stem, const char *new_stem, const char *range, int prm_only);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<stem.PRM> -B<new_stem> -C<range> [-P] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the PRM file for the coregistered image to cut.");
	GMT_Usage(API, 1, "\n-B is the stem for the newly generated SLC and PRM file.");
	GMT_Usage(API, 1, "\n-C is the range to cut, e.g. 500/1500/900/3600.");
	GMT_Usage(API, 1, "\n-P writes only the new PRM file, skipping the SLC data.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_cut_slc(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *stem = NULL, *new_stem = NULL, *range = NULL;
	int prm_only = 0;
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
			case 'A': stem = opt->arg; break;
			case 'B': new_stem = opt->arg; break;
			case 'C': range = opt->arg; break;
			case 'P': prm_only = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!stem || !new_stem || !range)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_cut_slc_run(stem, new_stem, range, prm_only);

	gmt_end_module(GMT, copy);
	return error;
}
