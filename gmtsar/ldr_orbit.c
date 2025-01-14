/********************************************************************************
 * Modified from ALOS_ldr_orbit.c * The only difference is that ra and rc is
 *reversed. Do this because it seems  * reversed but don't want to mess ALOS up.
 *So make ENVI one for now		*
 ********************************************************************************/

/********************************************************************************
 * Creator:  Rob Mellors and David T. Sandwell * (San Diego State University,
 *Scripps Institution of Oceanography)  * Date   :  10/03/2007 *
 ********************************************************************************/
/********************************************************************************
 * Modification history: * Date: * 07/13/08    added SC_height_start and
 * SC_height_end parameters               *
 * *****************************************************************************/

#include "gmtsar.h"
#include "orbit.h"
#define FACTOR 1000000
EXTERN_MSC void calc_height_velocity(struct SAT_ORB *, struct PRM *, double, double, double *, double *, double *, double *, double *);
EXTERN_MSC void interpolate_SAT_orbit_slow(struct SAT_ORB *orb, double time, double *, double *, double *, int *);
void polyfit(double *, double *, double *, int *, int *);
EXTERN_MSC void ldr_orbit(struct SAT_ORB *orb, struct PRM *prm);

void ldr_orbit(struct SAT_ORB *orb, struct PRM *prm) {
	double t1, t2;
	double re, height, vg;
	double re_c, re_start, re_end, vg_start, vg_end, vtot, rdot;
	double height_start, height_end;

	if (verbose)
		fprintf(stderr, "ldr_orbit\n");

	t1 = (86400.0) * prm->clock_start + (prm->nrows - prm->num_valid_az) / (2.0 * prm->prf);
	t2 = t1 + prm->num_patches * prm->num_valid_az / prm->prf;

	calc_height_velocity(orb, prm, t1, t1, &height_start, &re_start, &vg_start, &vtot, &rdot);
	calc_height_velocity(orb, prm, t2, t2, &height_end, &re_end, &vg_end, &vtot, &rdot);
	calc_height_velocity(orb, prm, t1, t2, &height, &re_c, &vg, &vtot, &rdot);

	if (verbose) {
		fprintf(stderr, " t1 %lf t1 %lf height_start %lf re_start %lf vg_start%lf\n", t1, t1, height_start, re_start, vg_start);
		fprintf(stderr, " t1 %lf t2 %lf height %lf re_c %lf vg %lf\n", t1, t2, height, re_c, vg);
		fprintf(stderr, " t2 %lf t2 %lf height_end %lf re__end %lf vg_end %lf\n", t2, t2, height_end, re_end, vg_end);
	}

	prm->vel = vg;
	/* use the center earth radius unless there is a value from the command line
	 */
	re = re_c;
	if (prm->RE > 0.)
		re = prm->RE;
	prm->RE = re;
	prm->ht = height + re_c - re;
	prm->ht_start = height_start + re_start - re;
	prm->ht_end = height_end + re_end - re;

	/* write it all out */
	if (verbose) {
		fprintf(stdout, "SC_vel                   = %lf \n", prm->vel);
		fprintf(stdout, "earth_radius             = %lf \n", prm->RE);
		fprintf(stdout, "SC_height                = %lf \n", prm->ht);
		fprintf(stdout, "SC_height_start          = %lf \n", prm->ht_start);
		fprintf(stdout, "SC_height_end            = %lf \n", prm->ht_end);
	}
}
/*---------------------------------------------------------------*/
/* from David Sandwell's code  */
void calc_height_velocity(struct SAT_ORB *orb, struct PRM *prm, double t1, double t2, double *height, double *re2, double *vg,
                          double *vtot, double *rdot) {

	int k, ir, nt, nc = 3;
	double xe, ye, ze;
	double xs, ys, zs;
	double x1, y1, z1;
	double x2, y2, z2;
	double vx, vy, vz, vs, rs;
	double rlat;
	/* double rlatg; */
	double st, ct, arg, re;
	double a[3], b[3], c[3];
	double time[1000], rng[1000], d[3];
	double t0, ro, ra, rc, dt;

	if (verbose)
		fprintf(stderr, " ... calc_height_velocity\n");

	ro = prm->near_range;
	/* ra and rc seems revsersed, but don't want to change ALOS */
	ra = prm->ra; /* ellipsoid parameters */
	rc = prm->rc; /* ellipsoid parameters */

	dt = 200. / prm->prf;
	/* nt = (prm->nrows - prm->num_valid_az)/100.; */
	nt = 100; /* changed to fixed value for TSX, ENVI */

	/* more time stuff */
	t0 = (t1 + t2) / 2.0;
	t1 = t0 - 2.0;
	t2 = t0 + 2.0;

	/* interpolate orbit 				*/
	/* _slow does memory allocation each time 	*/
	interpolate_SAT_orbit_slow(orb, t0, &xs, &ys, &zs, &ir);
	interpolate_SAT_orbit_slow(orb, t1, &x1, &y1, &z1, &ir);
	interpolate_SAT_orbit_slow(orb, t2, &x2, &y2, &z2, &ir);

	rs = sqrt(xs * xs + ys * ys + zs * zs);

	/* calculate stuff */
	vx = (x2 - x1) / 4.0;
	vy = (y2 - y1) / 4.0;
	vz = (z2 - z1) / 4.0;
	vs = sqrt(vx * vx + vy * vy + vz * vz);
	*vtot = vs;

	/* set orbit direction */
	if (vz > 0) {
		strcpy(prm->orbdir, "A");
	}
	else {
		strcpy(prm->orbdir, "D");
	}

	/* geodetic latitude of the satellite */
	rlat = asin(zs / rs);
	/* rlatg = atan(tan(rlat)*ra*ra/(rc*rc)); */

	st = sin(rlat); /* changed from rlatg  to rlat, not sure which is right */
	ct = cos(rlat);
	arg = (ct * ct) / (ra * ra) + (st * st) / (rc * rc);
	re = 1. / (sqrt(arg));
	*re2 = re;
	*height = rs - *re2;

	/*fprintf(stderr,"time %lf xyz %lf %lf %lf geodetic latitude %lf \n",t0,
	 * xs,ys,zs, rlatg/3.14*180);*/

	/* compute the vector orthogonal to both the radial vector and velocity vector
	 */
	a[0] = xs / rs;
	a[1] = ys / rs;
	a[2] = zs / rs;
	b[0] = vx / vs;
	b[1] = vy / vs;
	b[2] = vz / vs;

	cross3(a, b, c);

	/*  compute the look angle */
	ct = (rs * rs + ro * ro - re * re) / (2. * rs * ro);
	st = sin(acos(ct));

	/* add the satellite and LOS vectors to get the new point */
	xe = xs + ro * (-st * c[0] - ct * a[0]);
	ye = ys + ro * (-st * c[1] - ct * a[1]);
	ze = zs + ro * (-st * c[2] - ct * a[2]);
	rlat = asin(ze / re);
	/* rlatg = atan(tan(rlat)*ra*ra/(rc*rc)); */

	/*  compute elipse height in the scene */
	st = sin(rlat); /* rlatg to rlat */
	ct = cos(rlat);
	arg = (ct * ct) / (ra * ra) + (st * st) / (rc * rc);
	re = 1. / (sqrt(arg));

	/* now check range over time */
	for (k = 0; k < nt; k++) {
		time[k] = dt * (k - nt / 2);
		t1 = t0 + time[k];
		interpolate_SAT_orbit_slow(orb, t1, &xs, &ys, &zs, &ir);
		rng[k] = sqrt((xe - xs) * (xe - xs) + (ye - ys) * (ye - ys) + (ze - zs) * (ze - zs)) - ro;
	}

	/* fit a second order polynomial to the range versus time function */
	polyfit(time, rng, d, &nt, &nc);
	*rdot = d[1];
	*vg = sqrt(ro * 2. * d[2]);
}
/*---------------------------------------------------------------*/
