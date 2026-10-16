#ifndef GMTSAR_COMMANDS_H
#define GMTSAR_COMMANDS_H

#include "../declspec.h"

#ifdef __cplusplus
extern "C" {
#endif

EXTERN_MSC int gmtsar_get_PRM(int argc, char **argv);
EXTERN_MSC int gmtsar_update_PRM(int argc, char **argv);
EXTERN_MSC int gmtsar_calc_dop_orb(int argc, char **argv);
EXTERN_MSC int gmtsar_nearest_grid(int argc, char **argv);
EXTERN_MSC int gmtsar_cut_slc(int argc, char **argv);
EXTERN_MSC int gmtsar_phase2topo(int argc, char **argv);
EXTERN_MSC int gmtsar_conv(int argc, char **argv);
EXTERN_MSC int gmtsar_fitoffset(int argc, char **argv);
EXTERN_MSC int gmtsar_xcorr(int argc, char **argv);
EXTERN_MSC int gmtsar_split_aperture(int argc, char **argv);
EXTERN_MSC int gmtsar_p_scatter(int argc, char **argv);
EXTERN_MSC int gmtsar_solid_tide(int argc, char **argv);
EXTERN_MSC int gmtsar_sbas(int argc, char **argv);
EXTERN_MSC int gmtsar_bperp(int argc, char **argv);
EXTERN_MSC int gmtsar_make_gaussian_filter(int argc, char **argv);
EXTERN_MSC int gmtsar_offset_topo(int argc, char **argv);
EXTERN_MSC int gmtsar_split_spectrum(int argc, char **argv);
EXTERN_MSC int gmtsar_extend_orbit(int argc, char **argv);
EXTERN_MSC int gmtsar_esarp(int argc, char **argv);
EXTERN_MSC int gmtsar_phasediff(int argc, char **argv);
EXTERN_MSC int gmtsar_phasefilt(int argc, char **argv);
EXTERN_MSC int gmtsar_resamp(int argc, char **argv);
EXTERN_MSC int gmtsar_SAT_baseline(int argc, char **argv);
EXTERN_MSC int gmtsar_SAT_llt2rat(int argc, char **argv);
EXTERN_MSC int gmtsar_SAT_look(int argc, char **argv);
EXTERN_MSC int gmtsar_phasediff_get_topo_phase(int argc, char **argv);
EXTERN_MSC int gmtsar_geocode_slc(int argc, char **argv);
EXTERN_MSC int gmtsar_ext_orb_s1a(int argc, char **argv);
EXTERN_MSC int gmtsar_spectral_diversity(int argc, char **argv);
EXTERN_MSC int gmtsar_merge_swath(int argc, char **argv);
EXTERN_MSC int gmtsar_stitch_tops(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_s1a(int argc, char **argv);
EXTERN_MSC int gmtsar_make_s1a_tops(int argc, char **argv);
EXTERN_MSC int gmtsar_make_s1a_tops_6par(int argc, char **argv);
EXTERN_MSC int gmtsar_assemble_tops(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_baseline(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_fbd2fbs(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_fbd2fbs_SLC(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_fbd2ss(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_fbs2fbd(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_llt2rat(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_look(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_merge(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_mosaic_ss(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_mosaic_ss_2frames(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_pre_process(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_pre_process_SLC(int argc, char **argv);
EXTERN_MSC int gmtsar_ALOS_pre_process_SS(int argc, char **argv);
EXTERN_MSC int gmtsar_snaphu(int argc, char **argv);
EXTERN_MSC int gmtsar_ers_line_fixer(int argc, char **argv);
EXTERN_MSC int gmtsar_read_data_file_ccrs(int argc, char **argv);
EXTERN_MSC int gmtsar_read_data_file_dpaf(int argc, char **argv);
EXTERN_MSC int gmtsar_read_sarleader_ccrs(int argc, char **argv);
EXTERN_MSC int gmtsar_read_sarleader_dpaf(int argc, char **argv);
EXTERN_MSC int gmtsar_ccrs2dpaf(int argc, char **argv);
EXTERN_MSC int gmtsar_asa_cat(int argc, char **argv);
EXTERN_MSC int gmtsar_calc_dop_orb_envi(int argc, char **argv);
EXTERN_MSC int gmtsar_ENVI_baseline(int argc, char **argv);
EXTERN_MSC int gmtsar_asa_im_decode(int argc, char **argv);
EXTERN_MSC int gmtsar_ENVI_llt2rat(int argc, char **argv);
EXTERN_MSC int gmtsar_ENVI_look(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_tsx(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_rs2(int argc, char **argv);
EXTERN_MSC int gmtsar_make_raw_csk(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_csk(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_csk2(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_gf3(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_lt1(int argc, char **argv);
EXTERN_MSC int gmtsar_ext_orb_lt1(int argc, char **argv);
EXTERN_MSC int gmtsar_make_slc_nsr(int argc, char **argv);
EXTERN_MSC int gmtsar_envi_slc_decode(int argc, char **argv);
EXTERN_MSC int gmtsar_envisat_dump_data(int argc, char **argv);
EXTERN_MSC int gmtsar_envisat_dump_header(int argc, char **argv);

/* GMT-compatible module ABI.  These are the stable entry points intended
 * for GMT_Call_Module-style consumers and language bindings. */
EXTERN_MSC int GMT_bperp(void *API, int mode, void *args);
EXTERN_MSC int GMT_calc_dop_orb(void *API, int mode, void *args);
EXTERN_MSC int GMT_conv(void *API, int mode, void *args);
EXTERN_MSC int GMT_cut_slc(void *API, int mode, void *args);
EXTERN_MSC int GMT_extend_orbit(void *API, int mode, void *args);
EXTERN_MSC int GMT_fitoffset(void *API, int mode, void *args);
EXTERN_MSC int GMT_get_PRM(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_gaussian_filter(void *API, int mode, void *args);
EXTERN_MSC int GMT_nearest_grid(void *API, int mode, void *args);
EXTERN_MSC int GMT_offset_topo(void *API, int mode, void *args);
EXTERN_MSC int GMT_p_scatter(void *API, int mode, void *args);
EXTERN_MSC int GMT_phase2topo(void *API, int mode, void *args);
EXTERN_MSC int GMT_sbas(void *API, int mode, void *args);
EXTERN_MSC int GMT_solid_tide(void *API, int mode, void *args);
EXTERN_MSC int GMT_split_aperture(void *API, int mode, void *args);
EXTERN_MSC int GMT_split_spectrum(void *API, int mode, void *args);
EXTERN_MSC int GMT_update_PRM(void *API, int mode, void *args);
EXTERN_MSC int GMT_xcorr(void *API, int mode, void *args);
EXTERN_MSC int GMT_esarp(void *API, int mode, void *args);
EXTERN_MSC int GMT_phasediff(void *API, int mode, void *args);
EXTERN_MSC int GMT_phasefilt(void *API, int mode, void *args);
EXTERN_MSC int GMT_resamp(void *API, int mode, void *args);
EXTERN_MSC int GMT_SAT_baseline(void *API, int mode, void *args);
EXTERN_MSC int GMT_SAT_llt2rat(void *API, int mode, void *args);
EXTERN_MSC int GMT_SAT_look(void *API, int mode, void *args);
EXTERN_MSC int GMT_phasediff_get_topo_phase(void *API, int mode, void *args);
EXTERN_MSC int GMT_geocode_slc(void *API, int mode, void *args);
EXTERN_MSC int GMT_ext_orb_s1a(void *API, int mode, void *args);
EXTERN_MSC int GMT_spectral_diversity(void *API, int mode, void *args);
EXTERN_MSC int GMT_merge_swath(void *API, int mode, void *args);
EXTERN_MSC int GMT_stitch_tops(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_s1a(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_s1a_tops(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_s1a_tops_6par(void *API, int mode, void *args);
EXTERN_MSC int GMT_assemble_tops(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_baseline(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_fbd2fbs(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_fbd2fbs_SLC(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_fbd2ss(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_fbs2fbd(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_llt2rat(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_look(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_merge(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_mosaic_ss(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_mosaic_ss_2frames(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_pre_process(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_pre_process_SLC(void *API, int mode, void *args);
EXTERN_MSC int GMT_ALOS_pre_process_SS(void *API, int mode, void *args);
EXTERN_MSC int GMT_snaphu(void *API, int mode, void *args);
EXTERN_MSC int GMT_ers_line_fixer(void *API, int mode, void *args);
EXTERN_MSC int GMT_read_data_file_ccrs(void *API, int mode, void *args);
EXTERN_MSC int GMT_read_data_file_dpaf(void *API, int mode, void *args);
EXTERN_MSC int GMT_read_sarleader_ccrs(void *API, int mode, void *args);
EXTERN_MSC int GMT_read_sarleader_dpaf(void *API, int mode, void *args);
EXTERN_MSC int GMT_ccrs2dpaf(void *API, int mode, void *args);
EXTERN_MSC int GMT_asa_cat(void *API, int mode, void *args);
EXTERN_MSC int GMT_calc_dop_orb_envi(void *API, int mode, void *args);
EXTERN_MSC int GMT_ENVI_baseline(void *API, int mode, void *args);
EXTERN_MSC int GMT_asa_im_decode(void *API, int mode, void *args);
EXTERN_MSC int GMT_ENVI_llt2rat(void *API, int mode, void *args);
EXTERN_MSC int GMT_ENVI_look(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_tsx(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_rs2(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_raw_csk(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_csk(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_csk2(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_gf3(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_lt1(void *API, int mode, void *args);
EXTERN_MSC int GMT_ext_orb_lt1(void *API, int mode, void *args);
EXTERN_MSC int GMT_make_slc_nsr(void *API, int mode, void *args);
EXTERN_MSC int GMT_envi_slc_decode(void *API, int mode, void *args);
EXTERN_MSC int GMT_envisat_dump_data(void *API, int mode, void *args);
EXTERN_MSC int GMT_envisat_dump_header(void *API, int mode, void *args);

/* GMT supplement discovery entry points (devdocs/custom_supplements.rst):
 * dlsym-resolved by GMT itself as "gmtsar_module_*", defined in the
 * generated gmt_gmtsar_glue.c. Declared here only so in-tree callers (e.g.
 * tests) can link against them directly instead of via dlsym. */
EXTERN_MSC int gmtsar_module_show_all(void *API);
EXTERN_MSC int gmtsar_module_list_all(void *API);
EXTERN_MSC int gmtsar_module_classic_all(void *API);
EXTERN_MSC const char *gmtsar_module_keys(void *API, char *candidate);
EXTERN_MSC const char *gmtsar_module_group(void *API, char *candidate);

#ifdef __cplusplus
}
#endif

#endif
