#define THIS_MODULE_CLASSIC_NAME "ALOS_pre_process"
#define THIS_MODULE_MODERN_NAME  "ALOS_pre_process"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Prepare ALOS-1 (AUIG/ERSDAC) Level 1.0 data for InSAR processing"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_ALOS_pre_process_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<imagefile> -B<LEDfile> [-C<near_range>] [-D<radius>] [-E<chirp_slope>] "
		"[-F<fd1>] [-G<chirp_ext>] [-H<nrows>] [-I<npatch>] [-J<tbias>] [-K] [-L] [-M] [-N] [-O] [-P] [-Q] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the ALOS Level 1.0 image file (CEOS format); "
		"-B selects the LED (leaderfile) file. Creates data.raw and writes PRM parameters to stdout.");
	GMT_Usage(API, 1, "\n-C forces the near range (m); -D forces the local earth radius (m); "
		"-E forces the chirp slope; -F forces the doppler centroid (fd1, also disables doppler calculation); "
		"-G forces the chirp extension (integer); -H forces nrows; -I forces the number of patches; "
		"-J corrects the clock bias (positive means plus).");
	GMT_Usage(API, 1, "\n-K disables doppler calculation (sets fd1 to zero); -L adjusts parameters for quad-pol "
		"mode (PRF/2); -M selects ERSDAC (ALOSE) input format instead of the default AUIG format.");
	GMT_Usage(API, 1, "\n-N writes the GMTSAR generic LED format output and updates the PRM (default); "
		"-O suppresses that generic LED output; -P also writes roi_pac format output; "
		"-Q enables debug (and verbose) output.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ALOS_pre_process(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *imagefile = NULL, *ledfile = NULL;
	char *near_range = NULL, *radius = NULL, *slope = NULL, *fd1 = NULL, *chirp_ext = NULL;
	char *nrows = NULL, *npatch = NULL, *tbias = NULL;
	int nodopp_flag = 0, quad_flag = 0, alose_flag = 0, led_flag = 0, noled_flag = 0, roi_flag = 0, debug_flag = 0;
	char *legacy[32];
	int argc = 3, error = GMT_NOERROR;

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
			case 'A': imagefile = opt->arg; break;
			case 'B': ledfile = opt->arg; break;
			case 'C': near_range = opt->arg; break;
			case 'D': radius = opt->arg; break;
			case 'E': slope = opt->arg; break;
			case 'F': fd1 = opt->arg; break;
			case 'G': chirp_ext = opt->arg; break;
			case 'H': nrows = opt->arg; break;
			case 'I': npatch = opt->arg; break;
			case 'J': tbias = opt->arg; break;
			case 'K': nodopp_flag = 1; break;
			case 'L': quad_flag = 1; break;
			case 'M': alose_flag = 1; break;
			case 'N': led_flag = 1; break;
			case 'O': noled_flag = 1; break;
			case 'P': roi_flag = 1; break;
			case 'Q': debug_flag = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!imagefile || !ledfile)) error = usage(API, GMT_USAGE);

	if (!error) {
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = imagefile;
		legacy[2] = ledfile;
#define ADD_PAIR(flag, value) do { if (value) { legacy[argc++] = flag; legacy[argc++] = value; } } while (0)
		ADD_PAIR("-near", near_range);
		ADD_PAIR("-radius", radius);
		ADD_PAIR("-force_slope", slope);
		ADD_PAIR("-fd1", fd1);
		ADD_PAIR("-chirp_ext", chirp_ext);
		ADD_PAIR("-nrows", nrows);
		ADD_PAIR("-npatch", npatch);
		ADD_PAIR("-tbias", tbias);
#undef ADD_PAIR
		if (nodopp_flag) legacy[argc++] = "-nodopp";
		if (quad_flag) legacy[argc++] = "-quad";
		if (alose_flag) legacy[argc++] = "-ALOSE";
		if (led_flag) legacy[argc++] = "-LED";
		if (noled_flag) legacy[argc++] = "-noLED";
		if (roi_flag) legacy[argc++] = "-roi";
		if (debug_flag) legacy[argc++] = "-debug";
		if (GMT->current.setting.verbose >= GMT_MSG_INFORMATION) legacy[argc++] = "-V";
		error = gmtsar_ALOS_pre_process_run(argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
