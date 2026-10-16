#define THIS_MODULE_CLASSIC_NAME "ers_line_fixer"
#define THIS_MODULE_MODERN_NAME  "ers_line_fixer"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Fix missing/misaligned lines in an ERS SAR raw data file"
#define THIS_MODULE_KEYS         ""
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"

#include <string.h>

int gmtsar_ers_line_fixer_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -I<rawfile1>[,<rawfile2>,...] -O<fixed_file> [-A<near_range>] "
		"[-H<header_bytes>] [-L<line_bytes>] [-S<station>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-I selects one or more comma-separated raw input files; -O selects the fixed "
		"output file (must not already exist).");
	GMT_Usage(API, 1, "\n-A aligns the lines by shifting them all to the given near range (the legacy "
		"-a flag, despite its synopsis, always requires a value).");
	GMT_Usage(API, 1, "\n-H forces the header length in bytes; -L forces the line length in bytes; "
		"-S selects the input file's station (default: auto-detect).");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ers_line_fixer(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *infiles = NULL, *outfile = NULL, *near_range = NULL, *header = NULL, *line = NULL, *station = NULL;
	char infiles_buf[4096];
	char *legacy[64];
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
			case 'I': infiles = opt->arg; break;
			case 'O': outfile = opt->arg; break;
			case 'A': near_range = opt->arg; break;
			case 'H': header = opt->arg; break;
			case 'L': line = opt->arg; break;
			case 'S': station = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!infiles || !outfile)) error = usage(API, GMT_USAGE);

	if (!error) {
		legacy[argc++] = (char *)THIS_MODULE_CLASSIC_NAME;
		if (near_range) { legacy[argc++] = "-a"; legacy[argc++] = near_range; }
		if (header) { legacy[argc++] = "-h"; legacy[argc++] = header; }
		if (line) { legacy[argc++] = "-l"; legacy[argc++] = line; }
		if (station) { legacy[argc++] = "-s"; legacy[argc++] = station; }

		strncpy(infiles_buf, infiles, sizeof(infiles_buf) - 1);
		infiles_buf[sizeof(infiles_buf) - 1] = '\0';
		for (tok = strtok(infiles_buf, ","); tok; tok = strtok(NULL, ",")) {
			if (argc >= 61) { error = 1; break; }
			legacy[argc++] = tok;
		}
		if (!error) {
			legacy[argc++] = outfile;
			error = gmtsar_ers_line_fixer_run(argc, legacy);
		}
		else {
			GMT_Report(API, GMT_MSG_ERROR, "-I has too many input files\n");
			error = usage(API, GMT_USAGE);
		}
	}

	gmt_end_module(GMT, copy);
	return error;
}
