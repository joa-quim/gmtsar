#include "../gmtsar_commands.h"
#include "gmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
	void *API=GMT_Create_Session("phasefilt",2U,0U,NULL); char converted[32][4096],*args[32]; int i,n=0,status=EXIT_FAILURE;
	if (!API) return EXIT_FAILURE;
	if (argc==2 && argv[1][0]=='-') { status=GMT_phasefilt(API,1,argv+1); goto done; }
	for (i=1;i<argc && n<31;++i) {
		char option=0;
		if (!strcmp(argv[i],"-v")) { args[n++]="-V"; continue; }
		if (!strcmp(argv[i],"-diff")) { snprintf(converted[n],sizeof(converted[n]),"-Tfiltdiff.grd"); args[n]=converted[n]; ++n; continue; }
		if (!strcmp(argv[i],"-complex_out")) {
			snprintf(converted[n],sizeof(converted[n]),"-Ofiltphase_real.grd"); args[n]=converted[n]; ++n;
			snprintf(converted[n],sizeof(converted[n]),"-Pfiltphase_imag.grd"); args[n]=converted[n]; ++n; continue;
		}
		if (i+1>=argc) goto done;
		option=!strcmp(argv[i],"-real")?'A':!strcmp(argv[i],"-imag")?'B':!strcmp(argv[i],"-amp1")?'C':!strcmp(argv[i],"-amp2")?'E':!strcmp(argv[i],"-phasefilt")?'G':!strcmp(argv[i],"-corrfilt")?'Q':!strcmp(argv[i],"-psize")?'N':!strcmp(argv[i],"-alpha")?'W':0;
		if (!option) goto done; snprintf(converted[n],sizeof(converted[n]),"-%c%s",option,argv[++i]); args[n]=converted[n]; ++n;
	}
	for (i=0;i<n && args[i][1]!='G';++i) {} if (i==n) { snprintf(converted[n],sizeof(converted[n]),"-Gfiltphase.grd"); args[n]=converted[n]; ++n; }
	status=GMT_phasefilt(API,n,args);
done: GMT_Destroy_Session(API); return status;
}
