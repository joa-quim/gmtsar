#define THIS_MODULE_CLASSIC_NAME "make_slc_csk"
#define THIS_MODULE_MODERN_NAME  "make_slc_csk"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Create a COSMO-SkyMed SLC"
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

int gmtsar_make_slc_csk_run(const char *input_file, const char *output_stem, double SLC_factor);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<input.h5> -C<output_stem> [-F<SLC_factor>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the COSMO-SkyMed HDF5 input file; -C selects the output stem. "
		"Writes <stem>.SLC, <stem>.PRM, <stem>.LED.");
	GMT_Usage(API, 1, "\n-F sets the SLC scale factor [1.0].");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_make_slc_csk(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *input_file = NULL, *output_stem = NULL, *end = NULL;
	double slc_factor = 1.0;
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
			case 'F':
				errno = 0; slc_factor = strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-F requires a number\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!input_file || !output_stem)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_make_slc_csk_run(input_file, output_stem, slc_factor);

	gmt_end_module(GMT, copy);
	return error;
}
