#define THIS_MODULE_CLASSIC_NAME "make_slc_nsr"
#define THIS_MODULE_MODERN_NAME  "make_slc_nsr"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Create a NISAR SLC from an HDF5 RSLC product"
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
#include <stdlib.h>

int gmtsar_make_slc_nsr_run(const char *input_file, const char *output_stem, const char *mode_in, double dfact,
                            const char *region_cut);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<input.h5> -C<output_stem> -T<output_type> -F<scale_factor> "
		"[-R<xl>/<xh>/<yl>/<yh>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the NISAR HDF5 RSLC file; -C selects the output stem. Writes "
		"<stem>.SLC, <stem>.PRM, <stem>.LED (S-band products get their stem's trailing A replaced with S).");
	GMT_Usage(API, 1, "\n-T sets the output_type/polarization dataset: AHH/AHV/AVH/AVV etc. for L-band "
		"frequency A/B, or SRH/SRV/SHH for S-band (mapped automatically to the available dataset).");
	GMT_Usage(API, 1, "\n-F sets the scale factor applied before casting float samples to int16.");
	GMT_Usage(API, 1, "\n-R crops to a region (range_low/range_high/azimuth_low/azimuth_high); the same "
		"region must be used for frequency A and B crops of the same scene.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_make_slc_nsr(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *input_file = NULL, *output_stem = NULL, *output_type = NULL, *region = NULL, *end = NULL;
	double scale_factor = 0.0;
	int have_factor = 0;
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
			case 'A': input_file = opt->arg; break;
			case 'C': output_stem = opt->arg; break;
			case 'T': output_type = opt->arg; break;
			case 'F':
				errno = 0; scale_factor = strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-F requires a number\n"); error = GMT_PARSE_ERROR; }
				have_factor = 1;
				break;
			case 'R': region = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!input_file || !output_stem || !output_type || !have_factor)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_make_slc_nsr_run(input_file, output_stem, output_type, scale_factor, region);

	gmt_end_module(GMT, copy);
	return error;
}
