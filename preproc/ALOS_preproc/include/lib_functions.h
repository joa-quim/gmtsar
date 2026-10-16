/* include files to define sarleader structure */
#ifndef LIB_FUNCTIONS2_H
#define LIB_FUNCTIONS2_H
#include "data_ALOS.h"
#include "data_ALOSE.h"
#include "orbit_ALOS.h"
#include "sarleader_ALOS.h"
#include "sarleader_fdr.h"
#include "../../../declspec.h"
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* function prototypes 				*/
EXTERN_MSC void ALOS_ldr_orbit(struct ALOS_ORB *, struct PRM *);
EXTERN_MSC int write_ALOS_LED(struct ALOS_ORB *, struct PRM *, char *);
EXTERN_MSC void ALOS_write_orb(FILE *, struct ALOS_ORB *);
EXTERN_MSC void ALOS_calc_height_velocity(struct ALOS_ORB *, struct PRM *, double, double, double *, double *, double *, double *, double *);
EXTERN_MSC void ALOS_calc_dop(struct PRM *);
EXTERN_MSC void cfft1d_(int *, fcomplex *, int *);
EXTERN_MSC void read_data(fcomplex *, unsigned char *, int, struct PRM *);
EXTERN_MSC void ALOS_null_sio_struct(struct PRM *);
EXTERN_MSC void ALOS_get_sio_struct(FILE *, struct PRM *);
EXTERN_MSC void ALOS_put_sio_struct(struct PRM, FILE *);
EXTERN_MSC void ALOS_get_string(char *, char *, char *, char *);
EXTERN_MSC void ALOS_get_int(char *, char *, char *, int *);
EXTERN_MSC void ALOS_get_double(char *, char *, char *, double *);
EXTERN_MSC void ALOS_hermite_c(double *, double *, double *, int, int, double, double *, int *);
EXTERN_MSC void interpolate_ALOS_orbit_slow(struct ALOS_ORB *, double, double *, double *, double *, int *);
EXTERN_MSC void interpolate_ALOS_orbit(struct ALOS_ORB *, double *, double *, double *, double, double *, double *, double *, int *);
EXTERN_MSC void get_orbit_info(struct ALOS_ORB *, struct SAR_info);
EXTERN_MSC void get_attitude_info(struct ALOS_ATT *, int, struct SAR_info);
EXTERN_MSC void print_binary_position(struct sarleader_binary *, int, FILE *, FILE *);
EXTERN_MSC void read_ALOS_sarleader(FILE *, struct PRM *, struct ALOS_ORB *);
EXTERN_MSC void set_ALOS_defaults(struct PRM *);
EXTERN_MSC void ALOS_ldr_prm(struct SAR_info, struct PRM *);
EXTERN_MSC int ALOS_is_big_endian_(void);
EXTERN_MSC int ALOS_is_big_endian__(void);
EXTERN_MSC void ALOS_die(char *, char *);
EXTERN_MSC void cross3_(double *, double *, double *);
EXTERN_MSC void ALOS_get_seconds(struct PRM, double *, double *);
EXTERN_MSC void ALOS_plh2xyz(double *, double *, double, double);
EXTERN_MSC void ALOS_xyz2plh(double *, double *, double, double);
EXTERN_MSC void ALOS_polyfit(double *, double *, double *, int *, int *);
EXTERN_MSC void ALOS_gauss_jordan(double **, double *, double *, int *);
EXTERN_MSC int ALOS_find_fft_length(int);
EXTERN_MSC void rng_expand(fcomplex *, int, fcomplex *, int);

#endif /* LIB_FUNCTIONS2_H */
