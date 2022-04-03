/*      $Id: sbas.h 39 2016-06-18 03/16/24 Xiaohua Xu $  */

#ifndef SBAS_H
#define SBAS_H
/* sbas functions */
#include<stdint.h>
#include<stdio.h>
#include"gmt.h"

EXTERN_MSC int parse_command_ts(int64_t, char **, float *, double *, double *, double *, int64_t *, int64_t *, int64_t *, int64_t *);
EXTERN_MSC int allocate_memory_ts(int64_t **, double **, double **, double **, float **, char ***, char ***, int64_t **, double **,
                       int64_t **, double **, double **, double **, int64_t **, float **, float **, float **, float **, float **,
                       float **, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t **, int64_t);
EXTERN_MSC int init_array_ts(double *, double *, float *, float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t);
EXTERN_MSC int read_table_data_ts(void *, FILE *, FILE *, char **, char **, int64_t *, float *, int64_t *, float *, float *, int64_t,
                       int64_t, int64_t, int64_t, struct GMT_GRID **, int64_t *, double *);
EXTERN_MSC int init_G_ts(double *, double *, int64_t, int64_t, int64_t, int64_t, int64_t *, int64_t *, double *, float, float *, double);
EXTERN_MSC int64_t lsqlin_sov_ts(int64_t xdim, int64_t ydim, float *disp, float *vel, int64_t *flag, double *d, double *ds, double *time,
                      double *G, double *Gs, double *A, float *var, float *phi, int64_t N, int64_t S, int64_t m, int64_t n,
                      double *work, int64_t lwork, int64_t flag_dem, float *dem, int64_t flag_rms, float *res, int64_t *jpvt,
                      double wl, double *atm_rms);
EXTERN_MSC int write_output_ts(void *, struct GMT_GRID *, int64_t, char **, int64_t, int64_t, int64_t, int64_t, int64_t, float *, float *,
                    float *, float *, float *, double, int64_t, int64_t *);
EXTERN_MSC int free_memory_ts(int64_t, float *, float *, char **, char **, float *, double *, double *, double *, int64_t *, double *,
                   double *, int64_t *, float *, float *, double *, int64_t *, float *, float *, double *, int64_t *, int64_t *, int64_t);
EXTERN_MSC int sum_intfs(float *, int64_t *, float *, int64_t, int64_t, int64_t);
EXTERN_MSC int connect_(int64_t *, int64_t *, double *, int64_t *, int64_t *, int64_t, int64_t, int64_t, int64_t);
EXTERN_MSC double compute_noise(float *, int64_t, int64_t);
EXTERN_MSC int apply_screen(float *, float *, int64_t, int64_t, int64_t, int64_t *);
EXTERN_MSC int remove_ts(float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t *, int64_t *);
EXTERN_MSC int rank_double(double *, int64_t *, int64_t);

#endif /* LIB_FUNCTIONS_H */
