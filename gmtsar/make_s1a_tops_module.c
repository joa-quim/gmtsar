#define THIS_MODULE_CLASSIC_NAME "make_s1a_tops"
#define THIS_MODULE_MODERN_NAME  "make_s1a_tops"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Create a Sentinel-1 TOPS SLC from XML/TIFF, with optional precise coregistration shifts"
#define THIS_MODULE_KEYS         "CG(,DG("
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

int gmtsar_make_s1a_tops_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<xml_file> -B<tiff_file> -G<output_stem> -M<mode> [-C<dr.grd> -D<da.grd>] [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the Sentinel-1 XML annotation file; -B is the matching TIFF file.");
	GMT_Usage(API, 1, "\n-G is the stem for the output .PRM/.LED/.SLC (or .SLCH/.SLCL/.BB) files.");
	GMT_Usage(API, 1, "\n-M selects the output mode: 0 no SLC; 1 center SLC; 2 high SLCH and low SLCL; 3 output ramp phase.");
	GMT_Usage(API, 1, "\n-C and -D give the range and azimuth coregistration shift grids; give both together or neither "
		"(omitting them writes SLCs with no shift).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_make_s1a_tops(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *xml_file = NULL, *tiff_file = NULL, *output_stem = NULL, *dr_grd = NULL, *da_grd = NULL, *end = NULL;
	char *legacy[8];
	long imode = -1;
	int argc = 5, error = GMT_NOERROR;

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
			case 'A': xml_file = opt->arg; break;
			case 'B': tiff_file = opt->arg; break;
			case 'G': output_stem = opt->arg; break;
			case 'C': dr_grd = opt->arg; break;
			case 'D': da_grd = opt->arg; break;
			case 'M':
				errno = 0; imode = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0' || imode < 0 || imode > 3) {
					GMT_Report(API, GMT_MSG_ERROR, "-M must be 0, 1, 2, or 3\n");
					error = GMT_PARSE_ERROR;
				}
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!xml_file || !tiff_file || !output_stem || imode < 0)) error = usage(API, GMT_USAGE);
	if (!error && ((dr_grd != NULL) != (da_grd != NULL))) {
		GMT_Report(API, GMT_MSG_ERROR, "-C and -D must be given together\n");
		error = GMT_PARSE_ERROR;
	}

	if (!error) {
		char mode_str[8];
		snprintf(mode_str, sizeof(mode_str), "%ld", imode);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = xml_file; legacy[2] = tiff_file; legacy[3] = output_stem; legacy[4] = mode_str;
		if (dr_grd) { legacy[5] = dr_grd; legacy[6] = da_grd; argc = 7; }
		error = gmtsar_make_s1a_tops_run(API, argc, legacy);
	}

	gmt_end_module(GMT, copy);
	return error;
}
