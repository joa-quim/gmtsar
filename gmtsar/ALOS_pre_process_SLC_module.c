#define THIS_MODULE_CLASSIC_NAME "ALOS_pre_process_SLC"
#define THIS_MODULE_MODERN_NAME  "ALOS_pre_process_SLC"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Prepare ALOS-2 Level 1.1 (SLC) data for InSAR processing"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

int gmtsar_ALOS_pre_process_SLC_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<imagefile> -B<LEDfile> [-C<near_range>] [-D<radius>] [-E<nrows>] "
		"[-F<tbias>] [-G<rbias>] [-H<SLC_factor>] [-I|-J|-K] [-L] [-M] [-N] [-O] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the ALOS Level 1.1 image file (CEOS format); "
		"-B selects the LED (leaderfile) file. Creates data.SLC and writes PRM parameters to stdout.");
	GMT_Usage(API, 1, "\n-C forces the near range (m); -D forces the local earth radius (m); "
		"-E forces nrows; -F corrects the clock bias (positive means plus); "
		"-G corrects the range bias (positive means increase near range); "
		"-H sets the scale factor to convert float to int SLC [1.0].");
	GMT_Usage(API, 1, "\n-I selects ALOS1 L1.1 data format; -J selects ALOS2 L1.1 data format (default); "
		"-K selects ALOS4 L1.1 data format.");
	GMT_Usage(API, 1, "\n-L also writes roi_pac format output; -M writes a generic LED file; "
		"-N uses the old-style ldr file for orbits directly (default); -O enables debug (and verbose) output.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ALOS_pre_process_SLC(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *imagefile = NULL, *ledfile = NULL;
	char *near_range = NULL, *radius = NULL, *nrows = NULL, *tbias = NULL, *rbias = NULL, *slc_factor = NULL;
	int alos1_flag = 0, alos2_flag = 0, alos4_flag = 0, roi_flag = 0, led_flag = 0, noled_flag = 0, debug_flag = 0;
	char *legacy[24];
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
			case 'E': nrows = opt->arg; break;
			case 'F': tbias = opt->arg; break;
			case 'G': rbias = opt->arg; break;
			case 'H': slc_factor = opt->arg; break;
			case 'I': alos1_flag = 1; break;
			case 'J': alos2_flag = 1; break;
			case 'K': alos4_flag = 1; break;
			case 'L': roi_flag = 1; break;
			case 'M': led_flag = 1; break;
			case 'N': noled_flag = 1; break;
			case 'O': debug_flag = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!imagefile || !ledfile)) error = usage(API, GMT_USAGE);
	if (!error && (alos1_flag + alos2_flag + alos4_flag) > 1) {
		GMT_Report(API, GMT_MSG_ERROR, "-I, -J and -K are mutually exclusive\n");
		error = GMT_PARSE_ERROR;
	}

	if (!error) {
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = imagefile;
		legacy[2] = ledfile;
#define ADD_PAIR(flag, value) do { if (value) { legacy[argc++] = flag; legacy[argc++] = value; } } while (0)
		ADD_PAIR("-near", near_range);
		ADD_PAIR("-radius", radius);
		ADD_PAIR("-nrows", nrows);
		ADD_PAIR("-tbias", tbias);
		ADD_PAIR("-rbias", rbias);
		ADD_PAIR("-SLC_factor", slc_factor);
#undef ADD_PAIR
		if (alos1_flag) legacy[argc++] = "-ALOS1";
		if (alos2_flag) legacy[argc++] = "-ALOS2";
		if (alos4_flag) legacy[argc++] = "-ALOS4";
		if (roi_flag) legacy[argc++] = "-roi";
		if (led_flag) legacy[argc++] = "-LED";
		if (noled_flag) legacy[argc++] = "-noLED";
		if (debug_flag) legacy[argc++] = "-debug";
		if (GMT->current.setting.verbose >= GMT_MSG_INFORMATION) legacy[argc++] = "-V";
		error = gmtsar_ALOS_pre_process_SLC_run(argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
