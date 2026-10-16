#define THIS_MODULE_CLASSIC_NAME "offset_topo"
#define THIS_MODULE_MODERN_NAME  "offset_topo"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Estimate a topographic grid offset by cross-correlation"
#define THIS_MODULE_KEYS         "AG{,BG{,GG)"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int gmtsar_offset_topo_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<amp_master.grd> -B<topo_ra.grd> -X<rshift> -Y<ashift> -S<ns> "
		"[-G<topo_shift.grd>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the master amplitude image; -B is the topography in radar coordinates.");
	GMT_Usage(API, 1, "\n-X and -Y are the guessed integer range and azimuth shifts; -S is the integer search radius.");
	GMT_Usage(API, 1, "\n-G writes the topography shifted by the refined offset.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_offset_topo(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *amp = NULL, *topo = NULL, *shifted = NULL, *end = NULL;
	char *legacy[7];
	long rshift = 0, ashift = 0, ns = -1;
	int have_x = 0, have_y = 0;
	int argc = 6, error = GMT_NOERROR;

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
			case 'A': amp = opt->arg; break;
			case 'B': topo = opt->arg; break;
			case 'G': shifted = opt->arg; break;
			case 'X':
				errno = 0; rshift = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-X requires an integer\n"); error = GMT_PARSE_ERROR; }
				have_x = 1;
				break;
			case 'Y':
				errno = 0; ashift = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-Y requires an integer\n"); error = GMT_PARSE_ERROR; }
				have_y = 1;
				break;
			case 'S':
				errno = 0; ns = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0' || ns < 0) { GMT_Report(API, GMT_MSG_ERROR, "-S requires a non-negative integer\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!amp || !topo || !have_x || !have_y || ns < 0)) error = usage(API, GMT_USAGE);

	if (!error) {
		char x_str[16], y_str[16], s_str[16];
		snprintf(x_str, sizeof(x_str), "%ld", rshift);
		snprintf(y_str, sizeof(y_str), "%ld", ashift);
		snprintf(s_str, sizeof(s_str), "%ld", ns);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = amp;
		legacy[2] = topo;
		legacy[3] = x_str;
		legacy[4] = y_str;
		legacy[5] = s_str;
		if (shifted) { legacy[6] = shifted; argc = 7; }
		error = gmtsar_offset_topo_run(API, argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
