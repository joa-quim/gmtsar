#define THIS_MODULE_CLASSIC_NAME "ALOS_merge"
#define THIS_MODULE_MODERN_NAME  "ALOS_merge"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Merge adjacent frames of ALOS PALSAR data"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_ALOS_merge_run(const char *prm1_file, const char *prm2_file, const char *output_stem, int calc_doppler,
                          int verbose_flag);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<PRMfile1> -B<PRMfile2> [-C<output_stem>] [-N] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B select the two PRM files to merge (file2 is appended onto file1, "
		"omitting duplicate lines; updates num_lines and doppler (average) in the PRM file).");
	GMT_Usage(API, 1, "\n-C sets the output stem (creates <stem>.raw and <stem>.PRM); default is \"merge\".");
	GMT_Usage(API, 1, "\n-N disables doppler (centroid) recalculation; by default it is calculated.");
	GMT_Usage(API, 1, "\nUse the common -V to get the legacy diagnostic messages.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ALOS_merge(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prm1_file = NULL, *prm2_file = NULL, *output_stem = NULL;
	int nodopp = 0, verbose_flag = 0;
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
			case 'A': prm1_file = opt->arg; break;
			case 'B': prm2_file = opt->arg; break;
			case 'C': output_stem = opt->arg; break;
			case 'N': nodopp = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	verbose_flag = (GMT->current.setting.verbose >= GMT_MSG_INFORMATION) ? 1 : 0;
	if (!error && (!prm1_file || !prm2_file)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_ALOS_merge_run(prm1_file, prm2_file, output_stem, !nodopp, verbose_flag);

	gmt_end_module(GMT, copy);
	return error;
}
