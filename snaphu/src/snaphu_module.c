#define THIS_MODULE_CLASSIC_NAME "snaphu"
#define THIS_MODULE_MODERN_NAME  "snaphu"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Statistical-cost network-flow phase unwrapping"
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int gmtsar_snaphu_run(int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -D<infile> -R<linelen> [-o<outfile>] [-c<corrfile>] [-m<magfile>] "
		"[-M<bytemaskfile>] [-a<ampfile>] [-A<ampfile>] [-e<estfile>] [-w<weightfile>] [-g<conncompfile>] "
		"[-G<conncompfile>] [-l<logfile>] [-C<configline>] [-f<configfile>] [-b<bperp>] [-p<p>] "
		"[-u] [-t] [-d] [-s] [-q] [-i] [-S] [-k] [-n] [-v] [-h] "
		"[-B<costinfile>] [-E<costoutfile>] [-F] [-H<mst|mcf>] [-I<amp1>/<amp2>] [-J<amp1>/<amp2>] "
		"[-K<ntilerow>/<ntilecol>/<rowovrlp>/<colovrlp>] [-L<firstrow>/<firstcol>/<nrow>/<ncol>] "
		"[-N<nthreads>] [-O<tiledir>] [-P] [-Q] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-D is the required wrapped-phase input file; -R is the required line length (samples per row).");
	GMT_Usage(API, 1, "\nFile options: -o output unwrapped-phase file; -c correlation file; -m interferogram "
		"magnitude file; -M byte mask file; -a/-A amplitude file (amplitude flag on/off); -e coarse "
		"unwrapped estimate file; -w pixel weight file; -g/-G connected-component output file (-G also "
		"regrows components); -l log file.");
	GMT_Usage(API, 1, "\nConfiguration: -C passes one configuration-file line verbatim; -f reads a full "
		"snaphu configuration file.");
	GMT_Usage(API, 1, "\nGeometry/cost: -b nonzero baseline length; -p Lp-norm exponent for Lp costs.");
	GMT_Usage(API, 1, "\nMode flags: -u input is already unwrapped; -t topography cost mode; -d deformation "
		"cost mode; -s smooth cost mode; -q evaluate cost of unwrapped input only (implies -u); -i "
		"initialize-only mode; -S single-tile reoptimization; -k keep temporary tile files; -n skip "
		"statistical costs; -v verbose; -h print snaphu's own detailed help and exit.");
	GMT_Usage(API, 1, "\nAdvanced: -B input cost file; -E output cost file; -F dump all intermediate "
		"arrays; -H selects the initialization method, mst or mcf; -I/-J dual amplitude files (float "
		"format, amplitude flag on/off); -K tile geometry as rows/cols/row-overlap/col-overlap; -L a "
		"single piece as firstrow/firstcol/nrow/ncol; -N number of tile worker threads; -O scratch "
		"directory for tile files; -P assemble previously unwrapped tiles only; -Q print the copyright "
		"notice and exit.");
	GMT_Option(API, "V");
	return GMT_MODULE_USAGE;
}

static int split2(char *buf, char *a, char *b) {
	char *slash = strchr(buf, '/');
	if (!slash) return 1;
	*slash = '\0';
	strcpy(a, buf);
	strcpy(b, slash + 1);
	return 0;
}

static int split4(char *buf, char *a, char *b, char *c, char *d) {
	char *p1 = strchr(buf, '/'); if (!p1) return 1;
	char *p2 = strchr(p1 + 1, '/'); if (!p2) return 1;
	char *p3 = strchr(p2 + 1, '/'); if (!p3) return 1;
	*p1 = '\0'; *p2 = '\0'; *p3 = '\0';
	strcpy(a, buf); strcpy(b, p1 + 1); strcpy(c, p2 + 1); strcpy(d, p3 + 1);
	return 0;
}

EXTERN_MSC int GMT_snaphu(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API);
	struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *infile = NULL, *linelen = NULL;
	char *legacy[96], *final[100];
	char bufs[16][1024];
	int nbuf = 0, argc = 1, error = GMT_NOERROR;
	int bypass_required = 0; /* -h and -Q exit inside snaphu's own arg parser before it ever checks for required args */

	if (!API) return GMT_NOT_A_SESSION;
	if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args);
	if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);

	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;

#define NEWBUF() (bufs[nbuf++])
#define ADDVAL(flag, value) do { legacy[argc++] = (char *)(flag); legacy[argc++] = (char *)(value); } while (0)
#define ADDBOOL(flag) do { legacy[argc++] = (char *)(flag); } while (0)

	for (opt = options; opt; opt = opt->next) {
		switch (opt->option) {
			case 'D': infile = opt->arg; break;
			case 'R': linelen = opt->arg; break;
			case 'o': ADDVAL("-o", opt->arg); break;
			case 'c': ADDVAL("-c", opt->arg); break;
			case 'm': ADDVAL("-m", opt->arg); break;
			case 'M': ADDVAL("-M", opt->arg); break;
			case 'a': ADDVAL("-a", opt->arg); break;
			case 'A': ADDVAL("-A", opt->arg); break;
			case 'e': ADDVAL("-e", opt->arg); break;
			case 'w': ADDVAL("-w", opt->arg); break;
			case 'g': ADDVAL("-g", opt->arg); break;
			case 'G': ADDVAL("-G", opt->arg); break;
			case 'l': ADDVAL("-l", opt->arg); break;
			case 'C': ADDVAL("-C", opt->arg); break;
			case 'f': ADDVAL("-f", opt->arg); break;
			case 'b': ADDVAL("-b", opt->arg); break;
			case 'p': ADDVAL("-p", opt->arg); break;
			case 'u': ADDBOOL("-u"); break;
			case 't': ADDBOOL("-t"); break;
			case 'd': ADDBOOL("-d"); break;
			case 's': ADDBOOL("-s"); break;
			case 'q': ADDBOOL("-q"); break;
			case 'i': ADDBOOL("-i"); break;
			case 'S': ADDBOOL("-S"); break;
			case 'k': ADDBOOL("-k"); break;
			case 'n': ADDBOOL("-n"); break;
			case 'v': ADDBOOL("-v"); break;
			case 'h': ADDBOOL("-h"); bypass_required = 1; break;
			case 'B': ADDVAL("--costinfile", opt->arg); break;
			case 'E': ADDVAL("--costoutfile", opt->arg); break;
			case 'F': ADDBOOL("--dumpall"); break;
			case 'P': ADDBOOL("--assemble"); break;
			case 'Q': ADDBOOL("--copyright"); bypass_required = 1; break;
			case 'N': ADDVAL("--nproc", opt->arg); break;
			case 'O': ADDVAL("--tiledir", opt->arg); break;
			case 'H':
				if (!strcmp(opt->arg, "mst")) ADDBOOL("--mst");
				else if (!strcmp(opt->arg, "mcf")) ADDBOOL("--mcf");
				else { GMT_Report(API, GMT_MSG_ERROR, "-H must be mst or mcf\n"); error = GMT_PARSE_ERROR; }
				break;
			case 'I': {
				char *a1 = NEWBUF(), *a2 = NEWBUF(), tmp[1024];
				snprintf(tmp, sizeof(tmp), "%s", opt->arg);
				if (split2(tmp, a1, a2)) { GMT_Report(API, GMT_MSG_ERROR, "-I requires amp1/amp2\n"); error = GMT_PARSE_ERROR; break; }
				legacy[argc++] = "--aa"; legacy[argc++] = a1; legacy[argc++] = a2;
				break;
			}
			case 'J': {
				char *a1 = NEWBUF(), *a2 = NEWBUF(), tmp[1024];
				snprintf(tmp, sizeof(tmp), "%s", opt->arg);
				if (split2(tmp, a1, a2)) { GMT_Report(API, GMT_MSG_ERROR, "-J requires amp1/amp2\n"); error = GMT_PARSE_ERROR; break; }
				legacy[argc++] = "--AA"; legacy[argc++] = a1; legacy[argc++] = a2;
				break;
			}
			case 'K': {
				char *a1 = NEWBUF(), *a2 = NEWBUF(), *a3 = NEWBUF(), *a4 = NEWBUF(), tmp[1024];
				snprintf(tmp, sizeof(tmp), "%s", opt->arg);
				if (split4(tmp, a1, a2, a3, a4)) { GMT_Report(API, GMT_MSG_ERROR, "-K requires ntilerow/ntilecol/rowovrlp/colovrlp\n"); error = GMT_PARSE_ERROR; break; }
				legacy[argc++] = "--tile"; legacy[argc++] = a1; legacy[argc++] = a2; legacy[argc++] = a3; legacy[argc++] = a4;
				break;
			}
			case 'L': {
				char *a1 = NEWBUF(), *a2 = NEWBUF(), *a3 = NEWBUF(), *a4 = NEWBUF(), tmp[1024];
				snprintf(tmp, sizeof(tmp), "%s", opt->arg);
				if (split4(tmp, a1, a2, a3, a4)) { GMT_Report(API, GMT_MSG_ERROR, "-L requires firstrow/firstcol/nrow/ncol\n"); error = GMT_PARSE_ERROR; break; }
				legacy[argc++] = "--piece"; legacy[argc++] = a1; legacy[argc++] = a2; legacy[argc++] = a3; legacy[argc++] = a4;
				break;
			}
			case 'V': break;
			default: error += gmt_default_option_error(GMT, opt); break;
		}
	}
#undef NEWBUF
#undef ADDVAL
#undef ADDBOOL
	if (!error && !bypass_required && (!infile || !linelen)) error = usage(API, GMT_USAGE);

	if (!error) {
		int i, fargc = 0;
		final[fargc++] = (char *)THIS_MODULE_CLASSIC_NAME;
		if (infile) final[fargc++] = infile;
		if (linelen) final[fargc++] = linelen;
		for (i = 1; i < argc; i++) final[fargc++] = legacy[i];
		error = gmtsar_snaphu_run(fargc, final);
	}

	gmt_end_module(GMT, copy);
	return error;
}
