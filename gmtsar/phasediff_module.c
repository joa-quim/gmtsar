#define THIS_MODULE_CLASSIC_NAME "phasediff"
#define THIS_MODULE_MODERN_NAME  "phasediff"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Compute the phase difference of two aligned SAR images"
#define THIS_MODULE_KEYS         "TG(,MG(,EG),QG)"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_phasediff_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<reference.PRM> -B<repeat.PRM> [-T<topography>] [-M<model>] [-E<realgrid>] [-Q<imaggrid>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B select reference and repeat PRM files.");
	GMT_Usage(API, 1, "\n-T and -M provide optional GMT input grids.");
	GMT_Usage(API, 1, "\n-E and -Q select real and imaginary output grids [real.grd and imag.grd].");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_phasediff(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *ref = NULL, *rep = NULL, *topo = NULL, *model = NULL, *real = NULL, *imag = NULL;
	char *legacy[11]; int argc = 3, error = 0;
	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);
	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;
	for (opt = options; opt; opt = opt->next) {
		if (opt->option == 'A') ref = opt->arg; else if (opt->option == 'B') rep = opt->arg;
		else if (opt->option == 'T') topo = opt->arg; else if (opt->option == 'M') model = opt->arg;
		else if (opt->option == 'E') real = opt->arg; else if (opt->option == 'Q') imag = opt->arg;
		else if (opt->option != 'V') error += gmt_default_option_error(GMT, opt);
	}
	if (!error && (!ref || !rep)) error = usage(API, GMT_USAGE);
	legacy[0] = "phasediff"; legacy[1] = ref; legacy[2] = rep;
#define ADD_PAIR(flag, value) do { if (value) { legacy[argc++] = flag; legacy[argc++] = value; } } while (0)
	ADD_PAIR("-topo", topo); ADD_PAIR("-model", model); ADD_PAIR("-real", real); ADD_PAIR("-imag", imag);
#undef ADD_PAIR
	if (!error) error = gmtsar_phasediff_run(API, argc, legacy);
	gmt_end_module(GMT, copy);
	return error;
}
