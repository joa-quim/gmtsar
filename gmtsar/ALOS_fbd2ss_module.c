#define THIS_MODULE_CLASSIC_NAME "ALOS_fbd2ss"
#define THIS_MODULE_MODERN_NAME  "ALOS_fbd2ss"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Zero the lines of an ALOS FBD raw file to match a WB1_SW4 ScanSAR file"
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

int gmtsar_ALOS_fbd2ss_run(const char *fbd_prm, const char *sw4_prm, int ashift, int ntot0, double a_stretch_a);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<FBD.PRM> -B<SW4.PRM> -C<ashift> -D<ntot> -E<a_stretch_a> [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A selects the input FBD PRM file (fine beam dual polarization).");
	GMT_Usage(API, 1, "\n-B selects the output PRM file with the appropriate lines zeroed to match a WB1_SW4 file.");
	GMT_Usage(API, 1, "\n-C sets the azimuth shift needed to align the first row of the FBD to the SW4.");
	GMT_Usage(API, 1, "\n-D sets the total number of rows between bursts in the SW4 (= num_valid_az/6).");
	GMT_Usage(API, 1, "\n-E sets either the parameter from matching or (SW4_PRF - FBD_PRF)/FBD_PRF.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_ALOS_fbd2ss(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *fbd_prm = NULL, *sw4_prm = NULL, *end = NULL;
	long ashift = 0, ntot0 = -1;
	double a_stretch_a = 0.0;
	int have_ashift = 0, have_stretch = 0;
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
			case 'A': fbd_prm = opt->arg; break;
			case 'B': sw4_prm = opt->arg; break;
			case 'C':
				errno = 0; ashift = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-C requires an integer\n"); error = GMT_PARSE_ERROR; }
				have_ashift = 1;
				break;
			case 'D':
				errno = 0; ntot0 = strtol(opt->arg, &end, 10);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-D requires an integer\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'E':
				errno = 0; a_stretch_a = strtod(opt->arg, &end);
				if (errno || end == opt->arg || *end != '\0') { GMT_Report(API, GMT_MSG_ERROR, "-E requires a number\n"); error = GMT_PARSE_ERROR; }
				have_stretch = 1;
				break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error && (!fbd_prm || !sw4_prm || ntot0 < 0 || !have_ashift || !have_stretch)) error = usage(API, GMT_USAGE);
	if (!error) error = gmtsar_ALOS_fbd2ss_run(fbd_prm, sw4_prm, (int)ashift, (int)ntot0, a_stretch_a);

	gmt_end_module(GMT, copy);
	return error;
}
