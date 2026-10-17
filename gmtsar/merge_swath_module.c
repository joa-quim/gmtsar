#define THIS_MODULE_CLASSIC_NAME "merge_swath"
#define THIS_MODULE_MODERN_NAME  "merge_swath"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Merge 2 or 3 Sentinel-1 TOPS subswaths into one grid"
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
#include <string.h>

int gmtsar_merge_swath_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<inputlist> -G<output.grd> [-S<stem>] [-N<n1>/<n2>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A lists 2 or 3 lines of the form aligned.PRM:phasefilt.grd, one per subswath, in swath order.");
	GMT_Usage(API, 1, "\n-G writes the merged grid.");
	GMT_Usage(API, 1, "\n-S also writes <stem>.PRM for the merged image.");
	GMT_Usage(API, 1, "\n-N<n1>/<n2> overrides the automatically computed stitch locations (use 0 for n2 with only 2 swaths).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_merge_swath(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *inputlist = NULL, *output = NULL, *stem = NULL, *n_pair = NULL, *end = NULL;
	char *legacy[6];
	int argc = 3, error = GMT_NOERROR;

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
			case 'A': inputlist = opt->arg; break;
			case 'G': output = opt->arg; break;
			case 'S': stem = opt->arg; break;
			case 'N': n_pair = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!inputlist || !output)) error = usage(API, GMT_USAGE);

	if (!error) {
		char n1_str[24], n2_str[24];
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = inputlist;
		legacy[2] = output;
		if (n_pair) {
			char tmp[64], *slash;
			snprintf(tmp, sizeof(tmp), "%s", n_pair);
			slash = strchr(tmp, '/');
			if (!slash) { GMT_Report(API, GMT_MSG_ERROR, "-N requires n1/n2\n"); error = GMT_PARSE_ERROR; }
			else {
				*slash = '\0';
				snprintf(n1_str, sizeof(n1_str), "%s", tmp);
				snprintf(n2_str, sizeof(n2_str), "%s", slash + 1);
				errno = 0; strtol(n1_str, &end, 10);
				if (errno || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-N requires integer n1/n2\n"); error = GMT_PARSE_ERROR; }
				errno = 0; strtol(n2_str, &end, 10);
				if (errno || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-N requires integer n1/n2\n"); error = GMT_PARSE_ERROR; }
			}
		}
		if (!error) {
			if (stem && n_pair) { legacy[3] = stem; legacy[4] = n1_str; legacy[5] = n2_str; argc = 6; }
			else if (stem) { legacy[3] = stem; argc = 4; }
			else if (n_pair) { legacy[3] = n1_str; legacy[4] = n2_str; argc = 5; }
			unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
			API->pad = 0U; gmt_set_pad(GMT, 0U);
			error = gmtsar_merge_swath_run(API, argc, legacy);
			API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
		}
	}

	gmt_end_module(GMT, copy);
	return error;
}
