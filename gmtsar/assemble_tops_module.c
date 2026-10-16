#define THIS_MODULE_CLASSIC_NAME "assemble_tops"
#define THIS_MODULE_MODERN_NAME  "assemble_tops"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Assemble consecutive Sentinel-1 TOPS bursts into one XML/TIFF pair"
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
#include <string.h>

int gmtsar_assemble_tops_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<azi_1> -B<azi_2> -I<stem1>/<stem2>/... -O<output_stem> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A and -B are the azimuth range to keep (both 0 to output all bursts).");
	GMT_Usage(API, 1, "\n-I lists two or more input stems (name.xml/name.tiff pairs), slash-separated, "
		"in the order they should be assembled.");
	GMT_Usage(API, 1, "\n-O is the output stem; writes <stem>.xml and <stem>.tiff.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_assemble_tops(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *azi_1 = NULL, *azi_2 = NULL, *output_stem = NULL, *stems = NULL;
	char *legacy[64];
	char stems_buf[4096];
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
			case 'A': azi_1 = opt->arg; break;
			case 'B': azi_2 = opt->arg; break;
			case 'O': output_stem = opt->arg; break;
			case 'I': stems = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!azi_1 || !azi_2 || !output_stem || !stems)) error = usage(API, GMT_USAGE);

	if (!error) {
		char *tok;
		int nstems = 0;
		snprintf(stems_buf, sizeof(stems_buf), "%s", stems);
		legacy[0] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[1] = azi_1;
		legacy[2] = azi_2;
		tok = strtok(stems_buf, "/");
		while (tok && argc < 62) {
			legacy[argc++] = tok;
			nstems++;
			tok = strtok(NULL, "/");
		}
		if (nstems < 2) {
			GMT_Report(API, GMT_MSG_ERROR, "-I requires at least two slash-separated stems\n");
			error = GMT_PARSE_ERROR;
		}
		else {
			legacy[argc++] = output_stem;
			error = gmtsar_assemble_tops_run(argc, legacy);
		}
	}

	gmt_end_module(GMT, copy);
	return error;
}
