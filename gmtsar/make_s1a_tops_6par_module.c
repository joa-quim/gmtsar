#define THIS_MODULE_CLASSIC_NAME "make_s1a_tops_6par"
#define THIS_MODULE_MODERN_NAME  "make_s1a_tops_6par"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Create a Sentinel-1 TOPS SLC using an explicit six-parameter shift model"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <stdio.h>
#include <stdlib.h>

int gmtsar_make_s1a_tops_6par_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<xml_file> -B<tiff_file> -G<output_stem> -M<mode> -R<rng_shift> -Z<azi_shift> "
		"-X<stretch_a> -Y<a_stretch_a> -S<stretch_r> -T<a_stretch_r> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A is the Sentinel-1 XML annotation file; -B is the matching TIFF file.");
	GMT_Usage(API, 1, "\n-G is the stem for the output .PRM/.LED/.SLC files.");
	GMT_Usage(API, 1, "\n-M selects the output mode: 0 no SLC; 1 center SLC; 2 high SLCH and low SLCL.");
	GMT_Usage(API, 1, "\n-R and -Z are the fractional range and azimuth shifts.");
	GMT_Usage(API, 1, "\n-X/-Y are the additional azimuth shifts in range/azimuth direction; "
		"-S/-T are the additional range shifts in range/azimuth direction.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_make_s1a_tops_6par(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *xml_file = NULL, *tiff_file = NULL, *output_stem = NULL, *mode_str = NULL;
	char *rng = NULL, *azi = NULL, *stretch_a = NULL, *a_stretch_a = NULL, *stretch_r = NULL, *a_stretch_r = NULL;
	char *legacy[11];
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
			case 'A': xml_file = opt->arg; break;
			case 'B': tiff_file = opt->arg; break;
			case 'G': output_stem = opt->arg; break;
			case 'M': mode_str = opt->arg; break;
			case 'R': rng = opt->arg; break;
			case 'Z': azi = opt->arg; break;
			case 'X': stretch_a = opt->arg; break;
			case 'Y': a_stretch_a = opt->arg; break;
			case 'S': stretch_r = opt->arg; break;
			case 'T': a_stretch_r = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!xml_file || !tiff_file || !output_stem || !mode_str || !rng || !azi ||
		!stretch_a || !a_stretch_a || !stretch_r || !a_stretch_r)) error = usage(API, GMT_USAGE);

	legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
	legacy[1] = xml_file; legacy[2] = tiff_file; legacy[3] = output_stem; legacy[4] = mode_str;
	legacy[5] = rng; legacy[6] = azi; legacy[7] = stretch_a; legacy[8] = a_stretch_a; legacy[9] = stretch_r; legacy[10] = a_stretch_r;
	unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
	API->pad = 0U; gmt_set_pad(GMT, 0U);
	if (!error) error = gmtsar_make_s1a_tops_6par_run(API, 11, legacy);
	API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);

	gmt_end_module(GMT, copy);
	return error;
}
