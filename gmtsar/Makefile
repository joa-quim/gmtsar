#	$Id: Makefile 109 2015-01-19 23:01:24Z sandwell $
#
#	makefile for gmtsar directory (sbas.c not included yet)

include ../config.mk

INCLUDES	= $(GMT_INC) -I./ -I$(TIFF_INC)

LIB_C		= aastretch.c acpatch.c calc_dop.c conv2d.c do_freq_xcorr.c \
		  do_time_int_xcorr.c fft_bins.c fft_interpolate_routines.c \
		  file_stuff.c geoxyz.c get_locations.c get_params.c hermite_c.c \
		  highres_corr.c interpolate_orbit.c intp_coef.c ldr_orbit.c \
		  parse_xcorr_input.c plxyz.c polyfit.c print_results.c radopp.c \
		  read_orb.c read_xcorr_data.c SAT_llt2rat_sub.c \
		  rmpatch.c rng_cmp.c rng_ref.c set_prm_defaults.c shift.c \
		  sio_struct.c siocomplex.c spline.c trans_col.c utils.c utils_complex.c \
		  write_orb.c sbas_utils.c stringutils.c update_PRM_sub.c rng_filter.c \
		  lib_strfuncs.c get_PRM.c get_PRM_module.c update_PRM.c update_PRM_module.c calc_dop_orb.c calc_dop_orb_module.c \
		  nearest_grid.c nearest_grid_module.c \
		  cut_slc.c cut_slc_module.c phase2topo.c phase2topo_module.c conv.c conv_module.c fitoffset.c fitoffset_module.c \
		  xcorr.c xcorr_module.c split_aperture.c split_aperture_module.c \
		  p_scatter.c p_scatter_module.c solid_tide.c solid_tide_module.c sbas.c sbas_module.c bperp.c bperp_module.c \
		  make_gaussian_filter.c make_gaussian_filter_module.c \
		  offset_topo.c offset_topo_module.c split_spectrum.c split_spectrum_module.c extend_orbit.c extend_orbit_module.c \
		  esarp.c esarp_module.c phasediff.c phasediff_module.c \
		  phasefilt.c phasefilt_module.c resamp.c resamp_module.c SAT_baseline.c SAT_baseline_module.c \
		  SAT_llt2rat.c SAT_llt2rat_module.c SAT_look.c SAT_look_module.c \
		  phasediff_get_topo_phase.c phasediff_get_topo_phase_module.c geocode_slc.c geocode_slc_module.c gmtsar_modules.c

LIB_O		= $(LIB_C:.c=.o)
LIB		= libgmtsar.$(LIBEXT)

#-------------------------------------------------------------------------------
#	library
#-------------------------------------------------------------------------------

$(LIB):		$(LIB_O)
		$(AR) cvur $@ $?
		$(RANLIB) $@

lib:		$(LIB)

PROGS_C		=

PROGS_O         = $(PROGS_C:.c=.o)
LEGACY_PROGS    = $(PROGS_C:.c=)
CLI_PROGS       = get_PRM update_PRM calc_dop_orb nearest_grid cut_slc phase2topo \
		  conv fitoffset xcorr split_aperture p_scatter \
		  solid_tide sbas bperp make_gaussian_filter offset_topo split_spectrum \
		  extend_orbit esarp phasediff phasefilt resamp SAT_baseline \
		  SAT_llt2rat SAT_look phasediff_get_topo_phase geocode_slc
PROGS           = $(LEGACY_PROGS) $(CLI_PROGS)

#-------------------------------------------------------------------------------
#	software targets
#-------------------------------------------------------------------------------

all:		$(PROGS)

install:	all
		$(INSTALL) -d $(bindir)
		$(INSTALL) $(PROGS) $(bindir)
		ls csh/*.csh csh/*.sh csh/*.py > /tmp/t.lis
		$(INSTALL) `cat /tmp/t.lis` $(bindir)
		rm -f /tmp/t.lis

uninstall:
		cd $(bindir); rm -f $(PROGS)
		cd csh; ls *.csh *.sh *.py > /tmp/t.lis
		cd $(bindir); rm -f `cat /tmp/t.lis`
		rm -f /tmp/t.lis

spotless::	clean

clean:	
		rm -f *.a *.o *% core tags $(PROGS)

#-------------------------------------------------------------------------------
#	program rules
#-------------------------------------------------------------------------------

$(LEGACY_PROGS):	$(PROGS_O) $(LIB)
		$(CC) $(LDFLAGS) $@.o $(GMTSAR) $(GMT_LIB) $(LALIBS) $(LIBS)  -L$(TIFF_LIB) -ltiff -lm -o $@

$(CLI_PROGS): %: cli/%.o $(LIB)
		$(CC) $(LDFLAGS) cli/$@.o $(GMTSAR) $(GMT_LIB) $(LALIBS) $(LIBS) -L$(TIFF_LIB) -ltiff -lm -o $@
