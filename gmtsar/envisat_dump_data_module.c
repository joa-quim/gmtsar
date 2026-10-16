#define THIS_MODULE_CLASSIC_NAME "envisat_dump_data"
#define THIS_MODULE_MODERN_NAME  "envisat_dump_data"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Dump binary complex data from an Envisat/ERS product"
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

int gmtsar_envisat_dump_data_run(const char *infile, const char *outfile, int have_range, unsigned int l0,
                                 unsigned int lN, unsigned int p0, unsigned int pN);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<envisat-product> -B<outputfile> [-C<l0>/<lN>/<p0>/<pN>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the input Envisat/ERS product; -B selects the output filename.");
	GMT_Usage(API, 1, "\n-C restricts the dump to azimuth lines l0..lN and range pixels p0..pN (all "
		"starting at 1); default is the whole image.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_envisat_dump_data(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *infile = NULL, *outfile = NULL, *range = NULL;
	unsigned int l0 = 0, lN = 0, p0 = 0, pN = 0;
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
			case 'A': infile = opt->arg; break;
			case 'B': outfile = opt->arg; break;
			case 'C': range = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!infile || !outfile)) error = usage(API, GMT_USAGE);
	if (!error && range) {
		if (sscanf(range, "%u/%u/%u/%u", &l0, &lN, &p0, &pN) != 4) {
			GMT_Report(API, GMT_MSG_ERROR, "-C requires <l0>/<lN>/<p0>/<pN>\n");
			error = GMT_PARSE_ERROR;
		}
	}
	if (!error) error = gmtsar_envisat_dump_data_run(infile, outfile, range != NULL, l0, lN, p0, pN);

	gmt_end_module(GMT, copy);
	return error;
}
