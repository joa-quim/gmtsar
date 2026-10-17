#define THIS_MODULE_CLASSIC_NAME "ALOS_mosaic_ss_2frames"
#define THIS_MODULE_MODERN_NAME  "ALOS_mosaic_ss_2frames"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Mosaic (or divide) 5 ALOS ScanSAR subswaths across 2 frames in radar coordinates"
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

int gmtsar_ALOS_mosaic_ss_2frames_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<prmfile1>,<grd1> -B<prmfile2>,<grd2> -C<prmfile3>,<grd3> "
		"-D<prmfile4>,<grd4> -E<prmfile5>,<grd5> -F<prmfile6>,<grd6> -G<prmfile7>,<grd7> "
		"-H<prmfile8>,<grd8> -I<prmfile9>,<grd9> -J<prmfile10>,<grd10> -K<mosaic_grd> -L<dec> -M<dir> [%s]\n",
		name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A through -J each select one subswath's PRM file and GMT grid (corr, phase, "
		"phasefilt), comma-separated. The first frame is -A..-E, the second frame is -F..-J.");
	GMT_Usage(API, 1, "\n-K selects the mosaic GMT grid (output when -M1, input when -M0).");
	GMT_Usage(API, 1, "\n-L sets the decimation factor in radar coordinates (e.g. 100).");
	GMT_Usage(API, 1, "\n-M1 mosaics the 5 subswaths into -K; -M0 divides -K back into the 5 subswaths.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

static int split2(const char *buf, char *a, char *b) {
	const char *comma = strchr(buf, ',');
	if (!comma) return 1;
	strncpy(a, buf, (size_t)(comma - buf));
	a[comma - buf] = '\0';
	strcpy(b, comma + 1);
	return 0;
}

EXTERN_MSC int GMT_ALOS_mosaic_ss_2frames(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *pair[10] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
	char *mosaic = NULL, *dec = NULL, *dir = NULL;
	char prm_buf[10][1024], grd_buf[10][1024];
	char *legacy[26];
	int argc = 0, error = GMT_NOERROR;
	int i;

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
			case 'A': pair[0] = opt->arg; break;
			case 'B': pair[1] = opt->arg; break;
			case 'C': pair[2] = opt->arg; break;
			case 'D': pair[3] = opt->arg; break;
			case 'E': pair[4] = opt->arg; break;
			case 'F': pair[5] = opt->arg; break;
			case 'G': pair[6] = opt->arg; break;
			case 'H': pair[7] = opt->arg; break;
			case 'I': pair[8] = opt->arg; break;
			case 'J': pair[9] = opt->arg; break;
			case 'K': mosaic = opt->arg; break;
			case 'L': dec = opt->arg; break;
			case 'M': dir = opt->arg; break;
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
	if (!error) {
		for (i = 0; i < 10; i++)
			if (!pair[i] || split2(pair[i], prm_buf[i], grd_buf[i])) error = 1;
		if (!mosaic || !dec || !dir) error = 1;
		if (error) {
			GMT_Report(API, GMT_MSG_ERROR, "-A through -J each require <prmfile>,<grdfile>\n");
			error = usage(API, GMT_USAGE);
		}
	}

	if (!error) {
		legacy[argc++] = (char *)THIS_MODULE_CLASSIC_NAME;
		for (i = 0; i < 10; i++) {
			legacy[argc++] = prm_buf[i];
			legacy[argc++] = grd_buf[i];
		}
		legacy[argc++] = mosaic;
		legacy[argc++] = dec;
		legacy[argc++] = dir;
		unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 2 */
		API->pad = 2U; gmt_set_pad(GMT, 2U);
		error = gmtsar_ALOS_mosaic_ss_2frames_run(API, argc, legacy);
		API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	}

	gmt_end_module(GMT, copy);
	return error;
}
