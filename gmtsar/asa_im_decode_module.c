#define THIS_MODULE_CLASSIC_NAME "asa_im_decode"
#define THIS_MODULE_MODERN_NAME  "asa_im_decode"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Decode Envisat ASAR Image Mode Level 0 data"
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
#include <string.h>

int gmtsar_asa_im_decode_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -F<asa_im1>[,<asa_im2>,...] -I<asa_ins> -O<out> -T<outType> -N<near_range> [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-F selects one or more comma-separated input image files (multiple if merging "
		"along-track).");
	GMT_Usage(API, 1, "\n-I selects the auxiliary instrument characterization data file.");
	GMT_Usage(API, 1, "\n-O selects the output raw data file (complex, no headers).");
	GMT_Usage(API, 1, "\n-T sets the output file type (1=byte, 4=float); -N sets the near range to which "
		"to align all lines (0 uses the first line's near range).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_asa_im_decode(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *files = NULL, *insfile = NULL, *outfile = NULL, *outtype = NULL, *near_range = NULL, *end = NULL;
	char files_buf[8192];
	char *legacy[128];
	int argc = 1, error = GMT_NOERROR;
	char *tok;

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
			case 'F': files = opt->arg; break;
			case 'I': insfile = opt->arg; break;
			case 'O': outfile = opt->arg; break;
			case 'T':
				errno = 0; strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-T requires an integer\n"); error = GMT_PARSE_ERROR; }
				outtype = opt->arg;
				break;
			case 'N':
				errno = 0; strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-N requires a number\n"); error = GMT_PARSE_ERROR; }
				near_range = opt->arg;
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!files || !insfile || !outfile || !outtype || !near_range)) error = usage(API, GMT_USAGE);

	if (!error) {
		strncpy(files_buf, files, sizeof(files_buf) - 1);
		files_buf[sizeof(files_buf) - 1] = '\0';
		legacy[argc++] = (char *)THIS_MODULE_CLASSIC_NAME;
		for (tok = strtok(files_buf, ","); tok; tok = strtok(NULL, ",")) {
			if (argc >= 123) { error = 1; break; }
			legacy[argc++] = tok;
		}
		if (!error) {
			legacy[argc++] = insfile;
			legacy[argc++] = outfile;
			legacy[argc++] = outtype;
			legacy[argc++] = near_range;
			error = gmtsar_asa_im_decode_run(argc, legacy);
		}
		else {
			GMT_Report(API, GMT_MSG_ERROR, "-F has too many files\n");
			error = usage(API, GMT_USAGE);
		}
	}

	gmt_end_module(GMT, copy);
	return error;
}
