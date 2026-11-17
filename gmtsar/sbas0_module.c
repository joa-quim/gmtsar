#define THIS_MODULE_CLASSIC_NAME "sbas0"
#define THIS_MODULE_MODERN_NAME  "sbas0"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Run a minimal unweighted SBAS displacement time-series inversion"
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
#include <string.h>

int gmtsar_sbas0_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<intf.tab> [-C<x0>/<y0>] [-L<rows>] [-P] [-W<wavelength>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Message(API, GMT_TIME_NONE, "  REQUIRED ARGUMENTS:\n");
	GMT_Usage(API, 1, "\n-A<intf.tab>");
	GMT_Usage(API, -2, "Three-column table: unwrap.grd ref_id rep_id. Scene IDs are YYYYDDD with "
		"zero-based DDD (January 1 = 000). Scene list, counts and grid dimensions are derived from it; "
		"scenes disconnected from the earliest one are dropped. Blank lines and # comments are ignored.");
	GMT_Message(API, GMT_TIME_NONE, "\n  OPTIONAL ARGUMENTS:\n");
	GMT_Usage(API, 1, "\n-C<x0>/<y0>");
	GMT_Usage(API, -2, "Reference every interferogram to the mean of the 3x3 cells centered on the node "
		"nearest grid coordinates <x0>/<y0> (grid x/y as in grdinfo, not pixel indices). All nine must be finite.");
	GMT_Usage(API, 1, "\n-L<rows>");
	GMT_Usage(API, -2, "Rows per processing block [400].");
	GMT_Usage(API, 1, "\n-P Partial coverage: use the finite interferograms available at each pixel "
		"(slow per-pixel DGELSY, full rank required). Default uses a common finite-data mask and one Cholesky factorization.");
	GMT_Usage(API, 1, "\n-W<wavelength>");
	GMT_Usage(API, -2, "Radar wavelength in meters [0.0554658].");
	GMT_Option(API, "V");
	GMT_Usage(API, 0, "\nOutput (in the working directory): disp_<YYYYDDD>.grd (cumulative LOS displacement, mm), "
		"vel.grd (LOS velocity, mm/yr), rms.grd (velocity uncertainty, mm/yr), residual_rms_mm.grd (interferogram misfit, mm).");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_sbas0(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *intf_tab = NULL, *wavelength = NULL, *rows = NULL, *end = NULL;
	char x0[GMT_LEN64] = {""}, y0[GMT_LEN64] = {""};
	char *legacy[12];
	int partial = 0, have_ref = 0, argc = 2, error = GMT_NOERROR;

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
			case 'A': intf_tab = opt->arg; break;
			case 'C':
				if (sscanf(opt->arg, "%63[^/]/%63s", x0, y0) != 2) {
					GMT_Report(API, GMT_MSG_ERROR, "Option -C: expected -C<x0>/<y0>\n");
					error = GMT_PARSE_ERROR;
				}
				else {
					errno = 0;
					strtod(x0, &end);
					if (errno || end == x0 || *end) error = GMT_PARSE_ERROR;
					strtod(y0, &end);
					if (errno || end == y0 || *end) error = GMT_PARSE_ERROR;
					if (error) GMT_Report(API, GMT_MSG_ERROR, "Option -C: invalid coordinate in %s\n", opt->arg);
					have_ref = 1;
				}
				break;
			case 'L':
				rows = opt->arg;
				errno = 0;
				if (strtol(rows, &end, 10) < 1 || errno || end == rows || *end) {
					GMT_Report(API, GMT_MSG_ERROR, "Option -L: requires a positive integer\n");
					error = GMT_PARSE_ERROR;
				}
				break;
			case 'P': partial = 1; break;
			case 'W': wavelength = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!intf_tab || !intf_tab[0])) {
		GMT_Report(API, GMT_MSG_ERROR, "Option -A: the interferogram table is required\n");
		error = GMT_PARSE_ERROR;
	}

	if (!error) {
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = intf_tab;
		if (wavelength) { legacy[argc++] = "-wavelength"; legacy[argc++] = wavelength; }
		if (rows) { legacy[argc++] = "-rows"; legacy[argc++] = rows; }
		if (have_ref) { legacy[argc++] = "-reference"; legacy[argc++] = x0; legacy[argc++] = y0; }
		if (partial) legacy[argc++] = "-partial_coverage";
		legacy[argc] = NULL;
		unsigned int gmtsar_pad = API->pad;	/* sbas0 indexes row strips assuming the pad its own session had: 0 */
		API->pad = 0U; gmt_set_pad(GMT, 0U);
		error = gmtsar_sbas0_run(API, argc, legacy);
		API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	}

	gmt_end_module(GMT, copy);
	return error;
}
