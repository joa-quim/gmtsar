/*	$Id: read_data.c 33 2013-04-06 05:37:15Z pwessel $	*/
#include "gmtsar.h"
#include "xcorr.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*-------------------------------------------------------*/
void read_complex_short(FILE *f, int *d, int iy, int jx, int npx, int npy, int nx) {
	int64_t  num_to_seek;
	int i, j;
	int ireal, iimag;
	short *tmp;

	tmp = malloc(2 * nx * sizeof(short)); /* whole line */

	num_to_seek = 2 * iy * nx * sizeof(short);
	fseek(f, num_to_seek, SEEK_SET); /* from beginning */

	/* need to read two parts of complex numbers - use amplitude */
	for (i = 0; i < npy; i++) {
		fread(&tmp[0], 2 * sizeof(short), nx, f); /* read whole line */

		for (j = 0; j < npx; j++) {
			ireal = (int)tmp[2 * (j + jx)];
			iimag = (int)tmp[2 * (j + jx) + 1];
			d[i * npx + j] = (int)rint(sqrt(ireal * ireal + iimag * iimag));
		}
	}

	free((short *)tmp);
}
/*-------------------------------------------------------*/
void read_real_float(FILE *f, int *d, int iy, int jx, int npx, int npy, int nx) {
	int64_t  num_to_seek;
	int i, j;
	float *tmp;

	tmp = malloc(nx * sizeof(float)); /* whole line */

	num_to_seek = iy * nx * sizeof(short);
	fseek(f, num_to_seek, SEEK_SET); /* from beginning */

	/* read the floats */
	for (i = 0; i < npy; i++) {
		fread(&tmp[0], sizeof(float), nx, f); /* read whole line */

		for (j = 0; j < npx; j++)
			d[i * npx + j] = (int)rintf(tmp[j + jx]);
	}

	free((float *)tmp);
}
/*-------------------------------------------------------*/
/*-------------------------------------------------------*/
void read_data(struct xcorr xc) {
	int iy, jx, ishft;

	/* set locations and read data for master */
	iy = xc.loc[iloc].y - xc.npy / 2;
	jx = xc.loc[iloc].x - xc.npx / 2;
	if (verbose)
		fprintf(stderr, " reading data (format %d) at iloc %d %d : %d %d\n", xc.format, xc.loc[iloc].x, xc.loc[iloc].y, jx, iy);

	if (xc.format == 0)
		read_complex_short(xc.data1, xc.d1, iy, jx, xc.npx, xc.npy, xc.m_nx);
	if (xc.format == 1)
		read_real_float(xc.data1, xc.d1, iy, jx, xc.npx, xc.npy, xc.m_nx);

	/* set locations and read data for aligned */
	ishft = (int)xc.loc[iloc].y * xc.astretcha;

	iy = xc.loc[iloc].y + xc.y_offset + ishft - xc.npy / 2;
	jx = xc.loc[iloc].x + xc.x_offset - xc.npx / 2;

	if (verbose)
		fprintf(stderr, " reading data (format %d) at iloc %d %d : %d %d\n", xc.format, xc.loc[iloc].x, xc.loc[iloc].y, jx, iy);

	if (xc.format == 0)
		read_complex_short(xc.data2, xc.d2, iy, jx, xc.npx, xc.npy, xc.s_nx);
	if (xc.format == 1)
		read_real_float(xc.data2, xc.d2, iy, jx, xc.npx, xc.npy, xc.s_nx);
}
/*-------------------------------------------------------*/
void read_complex_short2float(FILE *f, float *d, int iy, int jx, int npx, int npy, int nx) {
	int64_t  num_to_seek;
	int i, j;
	int ireal, iimag;
	short *tmp;

	tmp = malloc(2 * nx * sizeof(short)); /* whole line */

	num_to_seek = 2 * iy * nx * sizeof(short);
	fseek(f, num_to_seek, SEEK_SET); /* from beginning */

	/* need to read two parts of complex numbers - use amplitude */
	for (i = 0; i < npy; i++) {
		fread(&tmp[0], 2 * sizeof(short), nx, f); /* read whole line */

		for (j = 0; j < npx; j++) {
			ireal = (int)tmp[2 * (j + jx)];
			iimag = (int)tmp[2 * (j + jx) + 1];
			d[i * npx + j] = (float)sqrt(ireal * ireal + iimag * iimag);
		}
	}

	free((short *)tmp);
}
