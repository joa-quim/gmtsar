#define USAGE ALOS_fbd2ss_USAGE
#define settable ALOS_fbd2ss_settable
/***************************************************************************
 * ALOS_fbd_ss reads a raw FBD-HH file and zeroes all the lines            *
 * corresponding to a SW4 scansar file                                     *
 ***************************************************************************/

/***************************************************************************
 * Creator:  David T. Sandwell and Rob Mellors                             *
 *           (Scripps Institution of Oceanography)                         *
 * Date   :  11/03/2009                                                    *
 ***************************************************************************/

/***************************************************************************
 * Modification history:                                                   *
 *                                                                         *
 * DATE                                                                    *
 *                                                                         *
 ***************************************************************************/

#include "image_sio.h"
#include "lib_functions.h"
#include "siocomplex.h"
#include <stdio.h>
#include <stdint.h>

/* fast random number generator */
#define znew (int)(z = 36969 * (z & 65535) + (z >> 16))
typedef uint64_t UL;
static UL z = 362436069, t[256];
void settable(UL i1) {
	int i;
	z = i1;
	for (i = 0; i < 256; i = i + 1)
		t[i] = znew;
}

char *USAGE = "\nALOS_fbd2ss FBD.PRM SW4.PRM ashift ntot a_stretch_a \n\n"
              "  FBD.PRM     PRM file for input  image in fine beam dual "
              "polarization (FBD 14 MHz) (input) \n"
              "  SW4.PRM     PRM file with appropriate lines zeroed to match a "
              "WB1_SW4 file \n"
              "  ashift      azimuth shift needed to align the first row of "
              "the FBD to the SW4 \n"
              "  ntot        total number of rows between bursts in the SW4 = "
              "num_valid_az/6  \n"
              "  a_stretch_a either the parameter from matching or (SW4_PRF - "
              "FBD_PRF)/FBD_PRF  \n\n"
              "  EXAMPLE: ALOS_fbd2ss FBD.PRM SW4.PRM -1046 1684 0.010972 \n\n";

int gmtsar_ALOS_fbd2ss_run(const char *fbd_prm, const char *sw4_prm, int ashift, int ntot0, double a_stretch_a) {
	FILE *prmfile, *datafile, *prmout, *dataout;
	unsigned char *indata;
	int j, k, headsize;

	/*  ashift is the ashift from fitoffset this fbd file should be the aligned */
	/*  nburst is 355 for SW4 */
	/*  ntot is the total number of lines between bursts scaled by the ratio of
	 * the fbd_PRF/SW4_PRF */
	int ibufsize, nburst0 = 355, nburst, ntot;
	int necho, IQ_mean;
	struct PRM r;

	/* flags defined in global_flags.h */
	verbose = 0;
	debug = 0;

	/* fill the struct with default parameters */
	ALOS_null_sio_struct(&r);

	/* open input PRM file and read the parameters */
	if ((prmfile = fopen(fbd_prm, "r")) == NULL)
		ALOS_die("Can't open ", (char *)fbd_prm);
	ALOS_get_sio_struct(prmfile, &r);
	IQ_mean = (int)(r.xmi - 15.5);

	/* compute ntot from the remaining parameters */
	ntot = (int)ntot0 * (1. + a_stretch_a);

	/*   increase the  burst length to ensure complete overlap and shift the
	 * ashift back by 1/4 burst */
	nburst = (int)(1.5 * nburst0);
	ashift = (int)(ashift - nburst0 / 4);

	fprintf(stderr, " ashift, nburst, ntot %d %d %d \n", ashift, nburst, ntot);

	/* open input raw data file */
	if ((datafile = fopen(r.input_file, "rb")) == NULL)
		ALOS_die("Can't open ", r.input_file);

	/* open output PRM file	*/
	if ((prmout = fopen(sw4_prm, "w")) == NULL)
		ALOS_die("Can't open ", (char *)sw4_prm);

	/* assemble the output filename and open for writing */
	sscanf(sw4_prm, "%s", r.input_file);
	r.input_file[strlen(sw4_prm) - 4] = 0;
	strcat(r.input_file, ".raw");
	/* open output file for scansar	 image */
	if ((dataout = fopen(r.input_file, "wb")) == NULL)
		ALOS_die("Can't open ", r.input_file);

	/* compute the sizes for the input and output buffers and allocate the memory
	 */
	ibufsize = r.bytes_per_line;
	headsize = 2 * r.first_sample;
	if ((indata = (unsigned char *)malloc(ibufsize * sizeof(unsigned char))) == NULL) {
		fprintf(stderr, "Sorry, couldn't allocate memory for input indata.\n");
		exit(-1);
	}

	/* read and write the input and output raw files */
	for (k = 0; k < r.num_lines; k++) {
		fread((void *)indata, sizeof(unsigned char), ibufsize, datafile);
		fwrite((void *)indata, sizeof(unsigned char), headsize, dataout);

		/* fill the output array with random 15 or 16 */
		necho = (k + 100 * ntot - ashift) % (ntot);
		if (necho > nburst) {
			for (j = 0; j < ibufsize - headsize; j++)
				indata[j + headsize] = IQ_mean + NULL_DATA + znew % 2;
		}
		fwrite(indata + headsize, sizeof(unsigned char), ibufsize - headsize, dataout);
	}

	if (debug)
		fprintf(stderr, " %d %d %d %d %f %f \n", r.chirp_ext, r.good_bytes, r.bytes_per_line, r.num_rng_bins, r.fs,
		        r.chirp_slope);
	/*  write the output PRM file */
	if ((prmout = fopen(sw4_prm, "w")) == NULL)
		ALOS_die("can't open prfile", (char *)sw4_prm);
	ALOS_put_sio_struct(r, prmout);

	fclose(prmfile);
	fclose(prmout);
	fclose(datafile);
	fclose(dataout);
	return EXIT_SUCCESS;
}

int gmtsar_ALOS_fbd2ss(int argc, char **argv) {
	if (argc < 6)
		ALOS_die(USAGE, "");
	return gmtsar_ALOS_fbd2ss_run(argv[1], argv[2], atoi(argv[3]), atoi(argv[4]), atof(argv[5]));
}
