#define THIS_MODULE_CLASSIC_NAME "xcorr"
#define THIS_MODULE_MODERN_NAME  "xcorr"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Compute the 2-D cross-correlation of two SAR images"
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
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int gmtsar_xcorr_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<master.PRM|master.grd> -B<aligned.PRM|aligned.grd> [-M<time|time4|freq>] "
		"[-F] [-N] [-Z] [-G<range_interp>] [-X<nx>] [-Y<ny>] [-S<xsearch>] [-T<ysearch>] [-W<interp_factor>] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B select the master and aligned images; either a PRM file pair or a "
		"pair of ordinary GMT grids holding real data.");
	GMT_Usage(API, 1, "\n-M selects the correlation method [freq].");
	GMT_Usage(API, 1, "\n-F reads real (not complex) data. -N ignores the PRM ashift/rshift. "
		"-Z skips sub-pixel interpolation of the correlation surface.");
	GMT_Usage(API, 1, "\n-G sets the range interpolation factor [2]; -G1 disables it.");
	GMT_Usage(API, 1, "\n-X and -Y set the number of locations in range and azimuth [16/32].");
	GMT_Usage(API, 1, "\n-S and -T set the power-of-two search window in range and azimuth [64/64].");
	GMT_Usage(API, 1, "\n-W sets the correlation-surface interpolation factor [16].");
	GMT_Usage(API, 1, "\nThe historical -input batch/list mode is not exposed through this module interface.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_xcorr(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *master = NULL, *aligned = NULL, *mode_str = NULL;
	char *end = NULL;
	char *legacy[24];
	long xsearch = 0, ysearch = 0;
	int argc = 3, error = 0;
	int real_flag = 0, noshift_flag = 0, nointerp_flag = 0;
	int have_g = 0, have_x = 0, have_y = 0, have_s = 0, have_t = 0, have_w = 0;
	long g_val = 0, x_val = 0, y_val = 0, w_val = 0;

	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;

#define PARSE_LONG(dest) do { \
		errno = 0; \
		(dest) = strtol(opt->arg, &end, 10); \
		if (errno || end == opt->arg || *end != '\0') { \
			GMT_Report(API, GMT_MSG_ERROR, "-%c requires an integer argument\n", opt->option); \
			error = GMT_PARSE_ERROR; \
		} \
	} while (0)

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'A': master = opt->arg; break;
			case 'B': aligned = opt->arg; break;
			case 'M': mode_str = opt->arg; break;
			case 'F': real_flag = 1; break;
			case 'N': noshift_flag = 1; break;
			case 'Z': nointerp_flag = 1; break;
			case 'G': PARSE_LONG(g_val); have_g = 1; break;
			case 'X': PARSE_LONG(x_val); have_x = 1; break;
			case 'Y': PARSE_LONG(y_val); have_y = 1; break;
			case 'S': PARSE_LONG(xsearch); have_s = 1; break;
			case 'T': PARSE_LONG(ysearch); have_t = 1; break;
			case 'W': PARSE_LONG(w_val); have_w = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
#undef PARSE_LONG

	if (!error && (!master || !aligned)) error = usage(API, GMT_USAGE);
	if (!error && mode_str && strcmp(mode_str, "time") && strcmp(mode_str, "time4") && strcmp(mode_str, "freq")) {
		GMT_Report(API, GMT_MSG_ERROR, "-M must be one of time, time4, or freq\n");
		error = GMT_PARSE_ERROR;
	}

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
	legacy[1] = master;
	legacy[2] = aligned;
	if (!error) {
		char g_str[16], x_str[16], y_str[16], s_str[16], t_str[16], w_str[16];
		if (mode_str && !strcmp(mode_str, "time")) legacy[argc++] = "-time";
		else if (mode_str && !strcmp(mode_str, "time4")) legacy[argc++] = "-time4";
		else if (mode_str) legacy[argc++] = "-freq";
		if (real_flag) legacy[argc++] = "-real";
		if (noshift_flag) legacy[argc++] = "-noshift";
		if (nointerp_flag) legacy[argc++] = "-nointerp";
		if (have_g) {
			if (g_val == 1) legacy[argc++] = "-norange";
			else {
				snprintf(g_str, sizeof(g_str), "%ld", g_val);
				legacy[argc++] = "-range_interp"; legacy[argc++] = g_str;
			}
		}
		if (have_x) { snprintf(x_str, sizeof(x_str), "%ld", x_val); legacy[argc++] = "-nx"; legacy[argc++] = x_str; }
		if (have_y) { snprintf(y_str, sizeof(y_str), "%ld", y_val); legacy[argc++] = "-ny"; legacy[argc++] = y_str; }
		if (have_s) { snprintf(s_str, sizeof(s_str), "%ld", xsearch); legacy[argc++] = "-xsearch"; legacy[argc++] = s_str; }
		if (have_t) { snprintf(t_str, sizeof(t_str), "%ld", ysearch); legacy[argc++] = "-ysearch"; legacy[argc++] = t_str; }
		if (have_w) { snprintf(w_str, sizeof(w_str), "%ld", w_val); legacy[argc++] = "-interp"; legacy[argc++] = w_str; }
		error = gmtsar_xcorr_run(API, argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
