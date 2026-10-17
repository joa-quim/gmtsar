#define THIS_MODULE_CLASSIC_NAME "phasediff_get_topo_phase"
#define THIS_MODULE_MODERN_NAME  "phasediff_get_topo_phase"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Compute and retain the topographic phase between two SLC images"
#define THIS_MODULE_KEYS         "TG(,MG("
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_phasediff_get_topo_phase_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<ref.PRM> -B<rep.PRM> [-T<topo_ra.grd>] [-M<model.grd>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B select the reference and repeat PRM files.");
	GMT_Usage(API, 1, "\n-T and -M provide optional topography and model-phase input grids.");
	GMT_Usage(API, 1, "\nWrites real.grd with the topographic phase.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_phasediff_get_topo_phase(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *ref = NULL, *rep = NULL, *topo = NULL, *model = NULL;
	char *legacy[7]; int argc = 3, error = GMT_NOERROR;

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
			case 'A': ref = opt->arg; break;
			case 'B': rep = opt->arg; break;
			case 'T': topo = opt->arg; break;
			case 'M': model = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!ref || !rep)) error = usage(API, GMT_USAGE);

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME; legacy[1] = ref; legacy[2] = rep;
#define ADD_PAIR(flag, value) do { if (value) { legacy[argc++] = flag; legacy[argc++] = value; } } while (0)
	ADD_PAIR("-topo", topo); ADD_PAIR("-model", model);
#undef ADD_PAIR
	unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
	API->pad = 0U; gmt_set_pad(GMT, 0U);
	if (!error) error = gmtsar_phasediff_get_topo_phase_run(API, argc, legacy);
	API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);

	gmt_end_module(GMT, copy);
	return error;
}
