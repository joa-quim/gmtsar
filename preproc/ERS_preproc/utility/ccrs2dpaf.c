#define USAGE ccrs2dpaf_USAGE
/* program to transform CCRS format to DPAF format of ERS data
 method: CCRS has 12060 bytes per line. DPAF has 11644. Read 12060 bytes from
 CCRS file and print 11644 bytes to new file */

#include "../include/soi.h"
#include <stdlib.h>
#include <string.h>

int gmtsar_ccrs2dpaf_run(const char *ifile, const char *ofile) {
	FILE *fpi, *fpo;
	unsigned char *indata;
	int ccrs_length = 12060, dpaf_length = 11644;
	int n;

	if ((fpi = fopen(ifile, "rb")) == NULL) {
		fprintf(stderr, "Can't open file %s \n", ifile);
		exit(-1);
	}

	if ((n = fseek(fpi, ccrs_length, 0)) != 0) {
		perror(ifile);
		exit(-1);
	}

	if ((fpo = fopen(ofile, "wb")) == NULL) {
		fprintf(stderr, "Can't open output file %s \n", ofile);
		exit(-1);
	}

	/* allocate memory */
	if ((indata = (unsigned char *)malloc(ccrs_length * sizeof(unsigned char))) == NULL) {
		fprintf(stderr, "Sorry, couldn't allocate memory for input indata.\n");
		exit(-1);
	}

	/* read data */
	while (n = (fread((void *)indata, sizeof(unsigned char), ccrs_length, fpi)) == ccrs_length) {
		memcpy(indata + 210, indata + 200, 8);
		if (n = (fwrite((void *)indata, sizeof(unsigned char), dpaf_length, fpo)) != dpaf_length) {
			fprintf(stderr, "Problem writing data \n");
		}
	}

	fclose(fpi);
	fclose(fpo);
	return EXIT_SUCCESS;
}

int gmtsar_ccrs2dpaf(int argc, char **argv) {
	if (argc < 3) {
		fprintf(stderr, "Usage: %s ccrs_raw out_file \n", argv[0]);
		return EXIT_FAILURE;
	}
	return gmtsar_ccrs2dpaf_run(argv[1], argv[2]);
}
