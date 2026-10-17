#define THIS_MODULE_CLASSIC_NAME "conv"
#define THIS_MODULE_MODERN_NAME  "conv"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Convolve a 2-D filter with an image and write a decimated grid"
#define THIS_MODULE_KEYS         "GG}"
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

int gmtsar_conv_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -X<idec> -Y<jdec> -C<filter_file> -I<input> -G<output.grd> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-X and -Y are the row and column decimation factors.");
	GMT_Usage(API, 1, "\n-C is the filter file, e.g. filters/gauss17x5.");
	GMT_Usage(API, 1, "\n-I is the file to be filtered, either a PRM file (I*2 or R*4 SLC) or a GMT grid.");
	GMT_Usage(API, 1, "\n-G writes the filtered output grid (R*4 only).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_conv(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *filter_file = NULL, *input = NULL, *output = NULL, *end = NULL;
	char *legacy[6];
	long idec = -1, jdec = -1;
	int error = GMT_NOERROR;

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
		if (errno || end == opt->arg || *end != '\0' || (dest) <= 0) { \
			GMT_Report(API, GMT_MSG_ERROR, "-%c requires a positive integer argument\n", opt->option); \
			error = GMT_PARSE_ERROR; \
		} \
	} while (0)

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'X': PARSE_LONG(idec); break;
			case 'Y': PARSE_LONG(jdec); break;
			case 'C': filter_file = opt->arg; break;
			case 'I': input = opt->arg; break;
			case 'G': output = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
#undef PARSE_LONG
	if (!error && (idec < 0 || jdec < 0 || !filter_file || !input || !output)) error = usage(API, GMT_USAGE);

	if (!error) {
		char idec_str[24], jdec_str[24];
		snprintf(idec_str, sizeof(idec_str), "%ld", idec);
		snprintf(jdec_str, sizeof(jdec_str), "%ld", jdec);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = idec_str; legacy[2] = jdec_str; legacy[3] = filter_file; legacy[4] = input; legacy[5] = output;
		unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
		API->pad = 0U; gmt_set_pad(GMT, 0U);
		error = gmtsar_conv_run(API, 6, legacy);
		API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	}

	gmt_end_module(GMT, copy);
	return error;
}
