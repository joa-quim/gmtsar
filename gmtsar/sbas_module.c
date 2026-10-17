#define THIS_MODULE_CLASSIC_NAME "sbas"
#define THIS_MODULE_MODERN_NAME  "sbas"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Run small-baseline subset (SBAS) time-series inversion"
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
#include <stdio.h>
#include <stdlib.h>

int gmtsar_sbas_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<intf.tab> -B<scene.tab> -N<N> -S<S> -X<xdim> -Y<ydim> "
		"[-M<smooth>] [-T<atm_iter>] [-W<wavelength>] [-C<incidence>] [-D<range>] [-Q] [-E] [-P] [-U] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A lists unwrapped interferograms (unwrap.grd corr.grd ref_id rep_id B_perp).");
	GMT_Usage(API, 1, "\n-B lists SAR scenes in chronological order (scene_id number_of_days).");
	GMT_Usage(API, 1, "\n-N is the number of interferograms; -S is the number of scenes.");
	GMT_Usage(API, 1, "\n-X and -Y are the interferogram dimensions.");
	GMT_Usage(API, 1, "\n-M sets the smoothing factor [0]; -T sets the number of atmospheric-correction "
		"iterations [0, skip]; -W sets the radar wavelength (m) [0.236]; -C sets the incidence angle "
		"(degrees) [37]; -D sets the range distance (m) [866000].");
	GMT_Usage(API, 1, "\n-Q writes velocity uncertainty grids; -E writes the DEM error grid; "
		"-P uses mmap for large arrays; -U restricts velocity estimation to atmosphere-corrected records.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_sbas(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *intf_tab = NULL, *scene_tab = NULL, *end = NULL;
	char *legacy[24];
	long N = -1, S = -1, xdim = -1, ydim = -1;
	int have_n = 0, have_s = 0, have_x = 0, have_y = 0;
	char *smooth = NULL, *atm = NULL, *wavelength = NULL, *incidence = NULL, *range = NULL;
	int rms_flag = 0, dem_flag = 0, mmap_flag = 0, robust_flag = 0;
	int argc = 7, error = GMT_NOERROR;

	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;

#define PARSE_LONG(dest, have) do { \
		errno = 0; \
		(dest) = strtol(opt->arg, &end, 10); \
		if (errno || end == opt->arg || *end != '\0') { \
			GMT_Report(API, GMT_MSG_ERROR, "-%c requires an integer argument\n", opt->option); \
			error = GMT_PARSE_ERROR; \
		} \
		(have) = 1; \
	} while (0)

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'A': intf_tab = opt->arg; break;
			case 'B': scene_tab = opt->arg; break;
			case 'N': PARSE_LONG(N, have_n); break;
			case 'S': PARSE_LONG(S, have_s); break;
			case 'X': PARSE_LONG(xdim, have_x); break;
			case 'Y': PARSE_LONG(ydim, have_y); break;
			case 'M': smooth = opt->arg; break;
			case 'T': atm = opt->arg; break;
			case 'W': wavelength = opt->arg; break;
			case 'C': incidence = opt->arg; break;
			case 'D': range = opt->arg; break;
			case 'Q': rms_flag = 1; break;
			case 'E': dem_flag = 1; break;
			case 'P': mmap_flag = 1; break;
			case 'U': robust_flag = 1; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
#undef PARSE_LONG
	if (!error && (!intf_tab || !scene_tab || !have_n || !have_s || !have_x || !have_y)) error = usage(API, GMT_USAGE);

	if (!error) {
		char n_str[24], s_str[24], x_str[24], y_str[24];
		snprintf(n_str, sizeof(n_str), "%ld", N);
		snprintf(s_str, sizeof(s_str), "%ld", S);
		snprintf(x_str, sizeof(x_str), "%ld", xdim);
		snprintf(y_str, sizeof(y_str), "%ld", ydim);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = intf_tab; legacy[2] = scene_tab;
		legacy[3] = n_str; legacy[4] = s_str; legacy[5] = x_str; legacy[6] = y_str;
#define ADD_PAIR(flag, value) do { if (value) { legacy[argc++] = flag; legacy[argc++] = value; } } while (0)
		ADD_PAIR("-atm", atm);
		ADD_PAIR("-smooth", smooth);
		ADD_PAIR("-wavelength", wavelength);
		ADD_PAIR("-incidence", incidence);
		ADD_PAIR("-range", range);
#undef ADD_PAIR
		if (rms_flag) legacy[argc++] = "-rms";
		if (dem_flag) legacy[argc++] = "-dem";
		if (mmap_flag) legacy[argc++] = "-mmap";
		if (robust_flag) legacy[argc++] = "-robust";
		unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
		API->pad = 0U; gmt_set_pad(GMT, 0U);
		error = gmtsar_sbas_run(API, argc, legacy);
		API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	}

	gmt_end_module(GMT, copy);
	return error;
}
