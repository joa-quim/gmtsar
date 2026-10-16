#include "siocomplex.h"
#include "image_sio.h"
#include <math.h>

fcomplex ALOS_Cmul(fcomplex x, fcomplex y) {
	fcomplex z;
	z.r = x.r * y.r - x.i * y.i;
	z.i = x.i * y.r + x.r * y.i;
	return z;
}

fcomplex ALOS_Cexp(float theta) {
	fcomplex z;
	z.r = cos(theta);
	z.i = sin(theta);
	return z;
}

fcomplex ALOS_Conjg(fcomplex z) {
	fcomplex x;
	x.r = z.r;
	x.i = -z.i;
	return x;
}

fcomplex ALOS_RCmul(float a, fcomplex z) {
	fcomplex x;
	x.r = a * z.r;
	x.i = a * z.i;
	return x;
}

fcomplex ALOS_Cadd(fcomplex x, fcomplex y) {
	fcomplex z;
	z.r = x.r + y.r;
	z.i = x.i + y.i;
	return z;
}

float ALOS_Cabs(fcomplex z) { return hypot(z.r, z.i); }
