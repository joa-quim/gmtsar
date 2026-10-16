#define THIS_MODULE_CLASSIC_NAME "get_PRM"
#define THIS_MODULE_MODERN_NAME  "get_PRM"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Read a named value from a GMTSAR PRM file"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_get_PRM_run(const char *file, const char *parameter);

static int get_PRM_usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB,
		THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -F<PRMfile> -N<parameter> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-F<PRMfile> selects the GMTSAR parameter file.");
	GMT_Usage(API, 1, "\n-N<parameter> selects the parameter name.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_get_PRM(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *GMT_cpy = NULL;
	const char *file = NULL, *parameter = NULL;
	int error = GMT_NOERROR;
	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return get_PRM_usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return get_PRM_usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return get_PRM_usage(API, GMT_SYNOPSIS);
	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME,
		THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &GMT_cpy);
	if (!GMT) return API->error;
	for (opt = options; opt; opt = opt->next) {
		if (opt->option == 'F') file = opt->arg;
		else if (opt->option == 'N') parameter = opt->arg;
		else if (opt->option != 'V') error += gmt_default_option_error(GMT, opt);
	}
	if (!error && (!file || !parameter)) error = get_PRM_usage(API, GMT_USAGE);
	if (!error) error = gmtsar_get_PRM_run(file, parameter);
	gmt_end_module(GMT, GMT_cpy);
	return error;
}
