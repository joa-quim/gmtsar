#define THIS_MODULE_CLASSIC_NAME "ALOS_llt2rat"
#define THIS_MODULE_MODERN_NAME  "ALOS_llt2rat"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Transform ALOS geographic coordinates to radar range/azimuth coordinates"
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

int gmtsar_ALOS_llt2rat_run(const char *prmfile, int precise, int otype);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<master.PRM> -P<precise> [-S|-D] [%s] < lon_lat_elev > outputfile\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the master PRM file (points to the ALOS LED orbit file).");
	GMT_Usage(API, 1, "\n-P<precise> is 0 for standard back-geocoding or 1 for the slower polynomial refinement.");
	GMT_Usage(API, 1, "\n-S writes single-precision binary output; -D writes double-precision binary output; "
		"the default is ASCII. Reads lon/lat/elevation triples from standard input and writes "
		"range/azimuth/elevation/lon/lat to standard output.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ALOS_llt2rat(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prmfile = NULL, *end = NULL;
	long precise = -1;
	int single_flag = 0, double_flag = 0;
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
			case 'S': single_flag = 1; break;
			case 'D': double_flag = 1; break;
			case 'P':
				errno = 0; precise = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0' || (precise != 0 && precise != 1)) {
					GMT_Report(API, GMT_MSG_ERROR, "-P must be 0 or 1\n");
					error = GMT_PARSE_ERROR;
				}
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!prmfile || precise < 0 || (single_flag && double_flag))) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_ALOS_llt2rat_run(prmfile, (int)precise, double_flag ? 3 : (single_flag ? 2 : 1));

	gmt_end_module(GMT, copy);
	return error;
}
