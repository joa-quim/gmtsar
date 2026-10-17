#define THIS_MODULE_CLASSIC_NAME "phasefilt"
#define THIS_MODULE_MODERN_NAME  "phasefilt"
#define THIS_MODULE_LIB          "gmtsar"
#define THIS_MODULE_PURPOSE      "Apply adaptive nonlinear phase filtering"
#define THIS_MODULE_KEYS         "AG{,BG{,CG(,EG(,GG},QG),OG),PG),TG)"
#define THIS_MODULE_NEEDS        ""
#define THIS_MODULE_OPTIONS      "-V"

#include "gmt_config.h"
#ifdef HAVE_GLIB_GTHREAD
#undef HAVE_GLIB_GTHREAD
#endif
#include "gmt_dev.h"
#include "gmtsar_commands.h"
int gmtsar_phasefilt_run(void *API, int argc, char **argv);

static int usage(struct GMTAPI_CTRL *API, int level) {
	const char *name = gmt_show_name_and_purpose(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_PURPOSE);
	if (level == GMT_MODULE_PURPOSE) return GMT_NOERROR;
	GMT_Usage(API, 0, "usage: %s -A<realgrid> -B<imaggrid> -G<phasegrid> [-C<amp1>] [-E<amp2>] [-N<patchsize>] [-W<alpha>] [-Q<corrgrid>] [-O<realgrid>] [-P<imaggrid>] [-T<diffgrid>] [%s]\n", name, GMT_V_OPT);
	if (level == GMT_SYNOPSIS) return GMT_MODULE_SYNOPSIS;
	GMT_Usage(API, 1, "\n-A/-B are required component grids; -G is filtered phase. -C/-E enable coherence-dependent filtering.");
	GMT_Usage(API, 1, "\n-N sets patch size [32]; -W sets exponent [0.5]. -Q, -O, -P, and -T select optional outputs.");
	GMT_Option(API, "V"); return GMT_MODULE_USAGE;
}

EXTERN_MSC int GMT_phasefilt(void *V_API, int mode, void *args) {
	struct GMTAPI_CTRL *API = gmt_get_api_ptr(V_API); struct GMT_OPTION *options = NULL, *opt;
	struct GMT_CTRL *GMT = NULL, *copy = NULL;
	char *real=NULL,*imag=NULL,*amp1=NULL,*amp2=NULL,*phase=NULL,*corr=NULL,*realout=NULL,*imagout=NULL,*diffout=NULL,*psize=NULL,*alpha=NULL;
	char *legacy[24]; int argc=1,error=0,want_verbose=0;
	if (!API) return GMT_NOT_A_SESSION; if (mode == GMT_MODULE_PURPOSE) return usage(API, mode);
	options = GMT_Create_Options(API, mode, args); if (API->error) return API->error;
	if (!options || options->option == GMT_OPT_USAGE) return usage(API, GMT_USAGE);
	if (options->option == GMT_OPT_SYNOPSIS) return usage(API, GMT_SYNOPSIS);
	GMT = gmt_init_module(API, THIS_MODULE_LIB, THIS_MODULE_CLASSIC_NAME, THIS_MODULE_KEYS, THIS_MODULE_NEEDS, NULL, &options, &copy);
	if (!GMT) return API->error;
	for (opt=options; opt; opt=opt->next) switch (opt->option) {
		case 'A':real=opt->arg;break; case 'B':imag=opt->arg;break; case 'C':amp1=opt->arg;break; case 'E':amp2=opt->arg;break;
		case 'G':phase=opt->arg;break; case 'Q':corr=opt->arg;break; case 'O':realout=opt->arg;break; case 'P':imagout=opt->arg;break;
		case 'T':diffout=opt->arg;break; case 'N':psize=opt->arg;break; case 'W':alpha=opt->arg;break; case 'V':want_verbose=1;break;
		default:error += gmt_default_option_error(GMT,opt);break;
	}
	if (!error && (!real || !imag || !phase || ((amp1 != NULL) != (amp2 != NULL)))) error = usage(API,GMT_USAGE);
	legacy[0]="phasefilt";
#define ADD_PAIR(f,v) do { if (v) { legacy[argc++]=f; legacy[argc++]=v; } } while (0)
	ADD_PAIR("-real",real); ADD_PAIR("-imag",imag); ADD_PAIR("-phasefilt",phase); ADD_PAIR("-amp1",amp1); ADD_PAIR("-amp2",amp2);
	ADD_PAIR("-psize",psize); ADD_PAIR("-alpha",alpha); ADD_PAIR("-corrfilt",corr); ADD_PAIR("-real_out",realout);
	ADD_PAIR("-imag_out",imagout); ADD_PAIR("-diff_out",diffout);
#undef ADD_PAIR
	unsigned int gmtsar_pad = API->pad;	/* the legacy code's grids use the pad its own session had: 0 */
	API->pad = 0U; gmt_set_pad(GMT, 0U);
	if (want_verbose) legacy[argc++]="-v"; if (!error) error=gmtsar_phasefilt_run(API,argc,legacy);
	API->pad = gmtsar_pad; gmt_set_pad(GMT, gmtsar_pad);
	gmt_end_module(GMT,copy); return error;
}
