#ifndef _COMPLEX_H
#define _COMPLEX_H
typedef struct SCOMPLEX {
    short r, i;
} scomplex;
typedef struct FCOMPLEX {
    float r, i;
} fcomplex;
typedef struct DCOMPLEX {
    double r, i;
} dcomplex;

#include "../../../declspec.h"
EXTERN_MSC fcomplex Cmul(fcomplex x, fcomplex y);
EXTERN_MSC fcomplex Cexp(float theta);
EXTERN_MSC fcomplex Conjg(fcomplex z);
EXTERN_MSC fcomplex RCmul(float a, fcomplex z);
EXTERN_MSC fcomplex Cadd(fcomplex x, fcomplex y);
EXTERN_MSC float Cabs(fcomplex z);

#endif /* _COMPLEX_H */
