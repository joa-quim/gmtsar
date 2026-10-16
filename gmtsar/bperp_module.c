#define THIS_MODULE_CLASSIC_NAME "bperp"
#define THIS_MODULE_MODERN_NAME  "bperp"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Compute a perpendicular-baseline grid"
#define THIS_MODULE_KEYS         "BG{,GG}"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_bperp_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<rep.PRM> -B<phase.grd> -G<bperp.grd> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the repeat PRM file that provides the interferometric baseline.");
	GMT_Usage(API, 1, "\n-B is an input phase grid that provides the output dimensions.");
	GMT_Usage(API, 1, "\n-G writes the perpendicular-baseline grid.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_bperp(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *prm = NULL, *phase = NULL, *bperp_out = NULL;
	char *legacy[4];
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
			case 'A': prm = opt->arg; break;
			case 'B': phase = opt->arg; break;
			case 'G': bperp_out = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!prm || !phase || !bperp_out)) error = usage(API, GMT_USAGE);

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
	legacy[1] = prm; legacy[2] = phase; legacy[3] = bperp_out;
	if (!error) error = gmtsar_bperp_run(API, 4, legacy);

	gmt_end_module(GMT, copy);
	return error;
}
