#define THIS_MODULE_CLASSIC_NAME "read_data_file_dpaf"
#define THIS_MODULE_MODERN_NAME  "read_data_file_dpaf"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Report ERS DPAF-format data-file line timing (SWST, PRI, IFC) to stdout"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_read_data_file_dpaf_run(const char *datafile);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<datafile> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the DPAF-format CEOS SAR data file.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_read_data_file_dpaf(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *datafile = NULL;
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
			case 'A': datafile = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && !datafile) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_read_data_file_dpaf_run(datafile);

	gmt_end_module(GMT, copy);
	return error;
}
