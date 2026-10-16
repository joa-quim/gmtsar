#define THIS_MODULE_CLASSIC_NAME "asa_cat"
#define THIS_MODULE_MODERN_NAME  "asa_cat"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Concatenate Envisat ASAR Image Mode / Wide Swath Mode Level 0 data"
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

int gmtsar_asa_cat_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -F<file1>,<file2>,... -O<out_file> [-C<0|1>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-F selects the comma-separated list of ASAR files to concatenate (along track).");
	GMT_Usage(API, 1, "\n-O selects the output data file.");
	GMT_Usage(API, 1, "\n-C sets catAbort: 0 discontinues concatenation on non-overlapping frames "
		"(default), 1 continues with missing lines filled in.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_asa_cat(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *files = NULL, *outfile = NULL, *catabort = NULL, *end = NULL;
	char files_buf[8192];
	char *legacy[128];
	char numfiles_str[16];
	int argc = 0, error = GMT_NOERROR, nfiles = 0;
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
			case 'O': outfile = opt->arg; break;
			case 'C':
				errno = 0; strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-C requires an integer\n"); error = GMT_PARSE_ERROR; }
				catabort = opt->arg;
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!files || !outfile)) error = usage(API, GMT_USAGE);

	if (!error) {
		strncpy(files_buf, files, sizeof(files_buf) - 1);
		files_buf[sizeof(files_buf) - 1] = '\0';
		legacy[argc++] = (char *)THIS_MODULE_CLASSIC_NAME;
		legacy[argc++] = numfiles_str; /* placeholder, filled below */
		for (tok = strtok(files_buf, ","); tok; tok = strtok(NULL, ",")) {
			if (argc >= 125) { error = 1; break; }
			legacy[argc++] = tok;
			nfiles++;
		}
		if (!error) {
			snprintf(numfiles_str, sizeof(numfiles_str), "%d", nfiles);
			legacy[argc++] = outfile;
			if (catabort) legacy[argc++] = catabort;
			error = gmtsar_asa_cat_run(argc, legacy);
		}
		else {
			GMT_Report(API, GMT_MSG_ERROR, "-F has too many files\n");
			error = usage(API, GMT_USAGE);
		}
	}

	gmt_end_module(GMT, copy);
	return error;
}
