/********************************************************************************
 * Creator:  Rob Mellors and David T. Sandwell * (San Diego State University,
 *Scripps Institution of Oceanography)  * Date   :  10/03/2007 *
 ********************************************************************************/
/********************************************************************************
 * Modification history: * Date: * 07/13/08    adjusted the stop time in case of
 * a prf change.                  *
 * *****************************************************************************/
#include "image_sio.h"
#include "lib_functions.h"
/*
int is_big_endian_(void);
int is_big_endian__(void);
void die (char *, char *);
void cross3_(double *, double *, double *);
void    get_seconds(struct PRM, double *, double *);
*/
/*---------------------------------------------------------------*/
/* check endian of machine 	*/
/* 1 if big; -1 if little	*/
int is_big_endian_() {
	union {
		int64_t l;
		char c[sizeof(int64_t)];
	} u;
	u.l = 1;
	return (u.c[sizeof(int64_t) - 1] == 1 ? 1 : -1);
}
int is_big_endian__() { return is_big_endian_(); }
/*---------------------------------------------------------------*/
/*---------------------------------------------------------------*/
/* write out error message and exit 				*/
/* use two strings to allow more complicated error messages 	*/
void die(char *s1, char *s2) {
	fprintf(stderr, " %s %s \n", s1, s2);
	exit(1);
}
/*---------------------------------------------------------------*/
/************************************************************************
 * cross3 is a routine to take the cross product of 3-D vectors         *
 *************************************************************************/
void cross3_(double *a, double *b, double *c)

/* input and output vectors  having 3 elements */

{

	c[0] = (a[1] * b[2]) - (a[2] * b[1]);
	c[1] = (-a[0] * b[2]) + (a[2] * b[0]);
	c[2] = (a[0] * b[1]) - (a[1] * b[0]);
}
/*---------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/* find seconds		*/
void get_seconds(struct PRM p, double *start, double *end) {
	int m;
	double doy;
	double n_secs_day;
	double prf_master;

	n_secs_day = 24.0 * 60.0 * 60.0;
	doy = p.clock_start;
	m = p.nrows - p.num_valid_az;

	/*  adjust the prf to use the a_rsatretch_a scale factor which was
	    needed to match the aligned image to the master image */

	prf_master = p.prf / (1. + p.a_stretch_a);

	*start = n_secs_day * doy + (p.ashift + p.sub_int_a) / (prf_master) + (1.0 * m) / (2.0 * prf_master);
	*end = *start + p.num_patches * p.num_valid_az / prf_master;
}
/*---------------------------------------------------------------------------*/
