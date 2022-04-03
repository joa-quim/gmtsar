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
EXTERN_MSC void write_orb(FILE *, struct ALOS_ORB *);
EXTERN_MSC void calc_height_velocity(struct ALOS_ORB *, struct PRM *, double, double, double *, double *, double *, double *, double *);
EXTERN_MSC void calc_dop(struct PRM *);
EXTERN_MSC void cfft1d_(int *, fcomplex *, int *);
EXTERN_MSC void read_data(fcomplex *, unsigned char *, int, struct PRM *);
EXTERN_MSC void null_sio_struct(struct PRM *);
EXTERN_MSC void get_sio_struct(FILE *, struct PRM *);
EXTERN_MSC void put_sio_struct(struct PRM, FILE *);
EXTERN_MSC void get_string(char *, char *, char *, char *);
EXTERN_MSC void get_int(char *, char *, char *, int *);
EXTERN_MSC void get_double(char *, char *, char *, double *);
EXTERN_MSC void hermite_c(double *, double *, double *, int, int, double, double *, int *);
EXTERN_MSC void interpolate_ALOS_orbit_slow(struct ALOS_ORB *, double, double *, double *, double *, int *);
EXTERN_MSC void interpolate_ALOS_orbit(struct ALOS_ORB *, double *, double *, double *, double, double *, double *, double *, int *);
EXTERN_MSC void get_orbit_info(struct ALOS_ORB *, struct SAR_info);
EXTERN_MSC void get_attitude_info(struct ALOS_ATT *, int, struct SAR_info);
EXTERN_MSC void print_binary_position(struct sarleader_binary *, int, FILE *, FILE *);
EXTERN_MSC void read_ALOS_sarleader(FILE *, struct PRM *, struct ALOS_ORB *);
EXTERN_MSC void set_ALOS_defaults(struct PRM *);
EXTERN_MSC void ALOS_ldr_prm(struct SAR_info, struct PRM *);
EXTERN_MSC int is_big_endian_(void);
EXTERN_MSC int is_big_endian__(void);
EXTERN_MSC void die(char *, char *);
EXTERN_MSC void cross3_(double *, double *, double *);
EXTERN_MSC void get_seconds(struct PRM, double *, double *);
EXTERN_MSC void plh2xyz(double *, double *, double, double);
EXTERN_MSC void xyz2plh(double *, double *, double, double);
EXTERN_MSC void polyfit(double *, double *, double *, int *, int *);
EXTERN_MSC void gauss_jordan(double **, double *, double *, int *);
EXTERN_MSC int find_fft_length(int);
EXTERN_MSC void rng_expand(fcomplex *, int, fcomplex *, int);

#endif /* LIB_FUNCTIONS2_H */
