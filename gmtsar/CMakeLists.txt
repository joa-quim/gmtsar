#
#	$Id$
#

if (WIN32)
	# Real clean-machine failure (2026-07-24, fresh conda env on another
	# host): find_package(TIFF REQUIRED) succeeded but left TIFF_LIBRARY
	# empty, so TIFF silently vanished from GMTSAR_LINK_LIBS and the ONE
	# executable calling libtiff directly (split_spectrum.c: TIFFOpen/
	# TIFFReadScanline/...) failed at link with undefined references --
	# every other target linked fine, hiding the root cause. conda-forge's
	# libtiff has shipped its import library under both names
	# (libtiff.lib and/or tiff.lib) across builds; coalesce explicitly
	# and FAIL AT CONFIGURE TIME if nothing resolves, never link without
	# TIFF silently. (Fresh cache var for the fallback: a stale
	# TIFF_LIBRARY-NOTFOUND in CMakeCache.txt would otherwise pin the
	# fallback search to its old failure.)
	if (NOT TIFF_LIBRARY AND TIFF_LIBRARIES)
		set (TIFF_LIBRARY ${TIFF_LIBRARIES})
	endif ()
	if (NOT TIFF_LIBRARY)
		find_library (TIFF_LIBRARY_WIN_FALLBACK NAMES tiff libtiff)
		if (TIFF_LIBRARY_WIN_FALLBACK)
			set (TIFF_LIBRARY ${TIFF_LIBRARY_WIN_FALLBACK})
		endif ()
	endif ()
	if (NOT TIFF_LIBRARY)
		message (FATAL_ERROR "TIFF import library not found (checked "
			"TIFF_LIBRARY, TIFF_LIBRARIES, and a direct search for "
			"tiff.lib/libtiff.lib) -- refusing to configure a build that "
			"would silently drop TIFF from the link line and fail only at "
			"split_spectrum.exe's link step. Is libtiff installed in the "
			"conda env this build is using?")
	endif ()
endif (WIN32)

set (GMTSAR_LINK_LIBS ${GMT_LIBRARY} ${TIFF_LIBRARY} ${LAPACK_LIBRARIES})

if (HAVE_M_LIBRARY)
	# link the math library
	set (GMTSAR_LINK_LIBS ${GMTSAR_LINK_LIBS} m)
endif (HAVE_M_LIBRARY)

include_directories (${GMT_INCLUDE_DIR} ${TIFF_INCLUDE_DIR} ${GETOPT_INC})

# Genuine out-of-tree GMT module sources include gmt_dev.h, whose installed
# headers expose GDAL types.  Locate headers only; GMT itself owns the linkage.
if (NOT GDAL_INCLUDE_DIR)
	find_path (GDAL_INCLUDE_DIR gdal.h PATH_SUFFIXES gdal)
endif ()
if (NOT GDAL_INCLUDE_DIR)
	message (FATAL_ERROR "GDAL headers are required to compile GMT module sources")
endif ()
include_directories (${GDAL_INCLUDE_DIR})

if (WIN32)
	# sbas_utils.c / resamp.c / sbas.c need a local mmap()/munmap() shim
	# on MSVC.  It covers the subset
	# they actually use (see compat_win32/sys/mman.h).
	include_directories (${CMAKE_CURRENT_SOURCE_DIR}/compat_win32
		${CMAKE_SOURCE_DIR})
endif (WIN32)

# ---- GMT supplement plumbing ------------------------------------------
# See ../GMT_MODULE_CONVERSION_STATUS.md and
# <gmt-source>/doc/rst/source/devdocs/custom_supplements.rst.  An
# out-of-tree GMT supplement (this DLL) does not get the moduleinfo
# header + glue translation unit that GMT auto-generates for in-tree
# src/<suppl>/ directories, so we reproduce that generation here.  The
# generated glue exports gmtsar_module_show_all/_list_all/_classic_all/
# _keys/_group, which is how `gmt --show-modules`/`gmt --help`/
# GMT_Encode_Options discover this DLL's modules via dlsym("gmtsar_module_*").
set (GMTSAR_SUPPL_NAME gmtsar)
# One line only: this gets substituted straight into a C string literal in
# the generated glue -- GMTSAR_PACKAGE_DESCRIPTION_SUMMARY has embedded
# newlines and would break the build.
set (GMTSAR_SUPPL_PURPOSE "GMTSAR: InSAR processing modules for GMT")

file (GLOB GMTSAR_MODULE_SRCS "${CMAKE_CURRENT_SOURCE_DIR}/*_module.c")
if (EXISTS "${CMAKE_SOURCE_DIR}/snaphu/src/CMakeLists.txt")
	# snaphu_module.c is folded into this same "gmtsar" target by
	# ../snaphu/src/CMakeLists.txt (target_sources), so its GMT_snaphu
	# entry point ends up in this DLL too -- include it in the scrape.
	list (APPEND GMTSAR_MODULE_SRCS "${CMAKE_SOURCE_DIR}/snaphu/src/snaphu_module.c")
endif ()

set (GMTSAR_MODULEINFO_H "${CMAKE_CURRENT_BINARY_DIR}/gmt_${GMTSAR_SUPPL_NAME}_moduleinfo.h")
set (GMTSAR_GLUE_C "${CMAKE_CURRENT_BINARY_DIR}/gmt_${GMTSAR_SUPPL_NAME}_glue.c")

# 70+ absolute paths blow past NMake/cmd's command-line length limit if
# passed as a single -D argument (hit "expanded command line ... too long"
# with all module sources inline). Write the list to a file instead and
# have the generator read it.
set (GMTSAR_MODULE_SRCS_FILE "${CMAKE_CURRENT_BINARY_DIR}/gmtsar_module_srcs.txt")
string (REPLACE ";" "\n" _gmtsar_module_srcs_lines "${GMTSAR_MODULE_SRCS}")
file (WRITE "${GMTSAR_MODULE_SRCS_FILE}" "${_gmtsar_module_srcs_lines}\n")

add_custom_command (
	OUTPUT "${GMTSAR_MODULEINFO_H}"
	COMMAND ${CMAKE_COMMAND}
		-D "OUTPUT_FILE=${GMTSAR_MODULEINFO_H}"
		-D "SRCS_LIST_FILE=${GMTSAR_MODULE_SRCS_FILE}"
		-P "${CMAKE_SOURCE_DIR}/cmake/modules/GmtsarGenModuleInfo.cmake"
	DEPENDS
		${GMTSAR_MODULE_SRCS}
		"${GMTSAR_MODULE_SRCS_FILE}"
		"${CMAKE_SOURCE_DIR}/cmake/modules/GmtsarGenModuleInfo.cmake"
	COMMENT "Generating ${GMTSAR_SUPPL_NAME} moduleinfo header"
	VERBATIM)

set (SHARED_LIB_NAME "${GMTSAR_SUPPL_NAME}")
set (SHARED_LIB_PURPOSE "${GMTSAR_SUPPL_PURPOSE}")
configure_file (
	"${CMAKE_CURRENT_SOURCE_DIR}/gmt_gmtsar_glue.c.in"
	"${GMTSAR_GLUE_C}"
	@ONLY)

add_library (gmtsar aastretch.c acpatch.c calc_dop.c conv2d.c do_freq_xcorr.c
	do_time_int_xcorr.c fft_bins.c fft_interpolate_routines.c file_stuff.c
	geoxyz.c get_locations.c get_params.c hermite_c.c highres_corr.c
	interpolate_orbit.c intp_coef.c ldr_orbit.c parse_xcorr_input.c plxyz.c
	polyfit.c print_results.c radopp.c read_orb.c read_xcorr_data.c
	SAT_llt2rat_sub.c rmpatch.c rng_cmp.c rng_ref.c set_prm_defaults.c shift.c
	sio_struct.c siocomplex.c spline.c trans_col.c utils.c utils_complex.c
	write_orb.c sbas_utils.c stringutils.c update_PRM_sub.c rng_filter.c
	lib_strfuncs.c get_PRM.c get_PRM_module.c update_PRM.c update_PRM_module.c calc_dop_orb.c calc_dop_orb_module.c
	nearest_grid.c nearest_grid_module.c
	cut_slc.c cut_slc_module.c phase2topo.c phase2topo_module.c conv.c conv_module.c fitoffset.c fitoffset_module.c
	xcorr.c xcorr_module.c split_aperture.c split_aperture_module.c
	p_scatter.c p_scatter_module.c solid_tide.c solid_tide_module.c sbas.c sbas_module.c bperp.c bperp_module.c
	make_gaussian_filter.c make_gaussian_filter_module.c
	offset_topo.c offset_topo_module.c split_spectrum.c split_spectrum_module.c extend_orbit.c extend_orbit_module.c
	esarp.c esarp_module.c phasediff.c phasediff_module.c
	phasefilt.c phasefilt_module.c resamp.c resamp_module.c SAT_baseline.c SAT_baseline_module.c
	SAT_llt2rat.c SAT_llt2rat_module.c SAT_look.c SAT_look_module.c
	phasediff_get_topo_phase.c phasediff_get_topo_phase_module.c geocode_slc.c geocode_slc_module.c
	"${GMTSAR_GLUE_C}" "${GMTSAR_MODULEINFO_H}"
	gmtsar.h gmtsar_commands.h lib_functions.h llt2xyz.h orbit.h
	sarleader_ALOS.h sarleader_fdr.h sfd_complex.h siocomplex.h soi.h xcorr.h)
target_link_libraries (gmtsar ${GMTSAR_LINK_LIBS})
target_include_directories (gmtsar PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
# GMT's declspec.h flips EXTERN_MSC to __declspec(dllexport) when
# LIBRARY_EXPORTS is defined (relevant to non-MSVC Windows toolchains; MSVC
# here relies on CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS instead, set above).
target_compile_definitions (gmtsar PRIVATE LIBRARY_EXPORTS)

set (GMTSAR_LINK_LIBS ${GMTSAR_LINK_LIBS} gmtsar)

add_executable (bperp cli/bperp.c gmtsar_commands.h)
target_link_libraries (bperp ${GMTSAR_LINK_LIBS})

add_executable (calc_dop_orb cli/calc_dop_orb.c gmtsar_commands.h)
target_link_libraries (calc_dop_orb ${GMTSAR_LINK_LIBS})

add_executable (conv cli/conv.c gmtsar_commands.h)
target_link_libraries (conv ${GMTSAR_LINK_LIBS})

add_executable (esarp cli/esarp.c gmtsar_commands.h)
target_link_libraries (esarp ${GMTSAR_LINK_LIBS})

add_executable (extend_orbit cli/extend_orbit.c gmtsar_commands.h)
target_link_libraries (extend_orbit ${GMTSAR_LINK_LIBS})

add_executable (make_gaussian_filter cli/make_gaussian_filter.c gmtsar_commands.h)
target_link_libraries (make_gaussian_filter ${GMTSAR_LINK_LIBS})

add_executable (offset_topo cli/offset_topo.c gmtsar_commands.h)
target_link_libraries (offset_topo ${GMTSAR_LINK_LIBS})

add_executable (phase2topo cli/phase2topo.c gmtsar_commands.h)
target_link_libraries (phase2topo ${GMTSAR_LINK_LIBS})

add_executable (phasediff cli/phasediff.c gmtsar_commands.h)
target_link_libraries (phasediff ${GMTSAR_LINK_LIBS})

add_executable (phasefilt cli/phasefilt.c gmtsar_commands.h)
target_link_libraries (phasefilt ${GMTSAR_LINK_LIBS})

add_executable (resamp cli/resamp.c gmtsar_commands.h)
target_link_libraries (resamp ${GMTSAR_LINK_LIBS})

add_executable (SAT_baseline cli/SAT_baseline.c gmtsar_commands.h)
target_link_libraries (SAT_baseline ${GMTSAR_LINK_LIBS})

add_executable (SAT_llt2rat cli/SAT_llt2rat.c gmtsar_commands.h)
target_link_libraries (SAT_llt2rat ${GMTSAR_LINK_LIBS})

add_executable (SAT_look cli/SAT_look.c gmtsar_commands.h)
target_link_libraries (SAT_look ${GMTSAR_LINK_LIBS})

add_executable (sbas cli/sbas.c gmtsar_commands.h)
target_link_libraries (sbas ${GMTSAR_LINK_LIBS})

add_executable (update_PRM cli/update_PRM.c gmtsar_commands.h)
target_link_libraries (update_PRM ${GMTSAR_LINK_LIBS})

add_executable (get_PRM cli/get_PRM.c gmtsar_commands.h)
target_link_libraries (get_PRM ${GMTSAR_LINK_LIBS})

add_executable (nearest_grid cli/nearest_grid.c gmtsar_commands.h)
target_link_libraries (nearest_grid ${GMTSAR_LINK_LIBS})
if (BUILD_TESTING)
	add_executable (test_nearest_grid_module tests/test_nearest_grid_module.c)
	target_include_directories (test_nearest_grid_module PRIVATE ${GMT_INCLUDE_DIR})
	target_link_libraries (test_nearest_grid_module gmtsar ${GMT_LIBRARY})
	add_test (NAME nearest_grid_virtual_grid COMMAND test_nearest_grid_module)
endif ()

add_executable (fitoffset cli/fitoffset.c gmtsar_commands.h)
target_link_libraries (fitoffset ${GMTSAR_LINK_LIBS})
if (MSVC)
	# fitoffset.c is the only file calling POSIX getline().
	set_source_files_properties (fitoffset.c PROPERTIES COMPILE_OPTIONS
		/FI${CMAKE_CURRENT_SOURCE_DIR}/compat_win32/getline_shim.h)
endif (MSVC)

add_executable (solid_tide cli/solid_tide.c gmtsar_commands.h)
target_link_libraries (solid_tide ${GMTSAR_LINK_LIBS})

add_executable (p_scatter cli/p_scatter.c gmtsar_commands.h)
target_link_libraries (p_scatter ${GMTSAR_LINK_LIBS})

add_executable (split_spectrum cli/split_spectrum.c gmtsar_commands.h)
target_link_libraries (split_spectrum ${GMTSAR_LINK_LIBS})

add_executable (cut_slc cli/cut_slc.c gmtsar_commands.h)
target_link_libraries (cut_slc ${GMTSAR_LINK_LIBS})

add_executable (split_aperture cli/split_aperture.c gmtsar_commands.h)
target_link_libraries (split_aperture ${GMTSAR_LINK_LIBS})

add_executable (phasediff_get_topo_phase cli/phasediff_get_topo_phase.c gmtsar_commands.h)
target_link_libraries (phasediff_get_topo_phase ${GMTSAR_LINK_LIBS})

add_executable (geocode_slc cli/geocode_slc.c gmtsar_commands.h)
target_link_libraries (geocode_slc ${GMTSAR_LINK_LIBS})
if (MSVC)
	# geocode_slc includes the Win32 mmap implementation.  It needs only the
	# core file-mapping API; excluding the COM/XML headers also prevents their
	# generic method names from colliding with GMT/GMTSAR C identifiers.
	target_compile_definitions (geocode_slc PRIVATE WIN32_LEAN_AND_MEAN)
endif (MSVC)

add_executable (xcorr cli/xcorr.c gmtsar_commands.h)
target_link_libraries (xcorr ${GMTSAR_LINK_LIBS})

# add the install targets
install (TARGETS gmtsar bperp calc_dop_orb conv esarp extend_orbit make_gaussian_filter offset_topo phase2topo phasediff phasefilt resamp SAT_baseline SAT_llt2rat SAT_look sbas xcorr update_PRM get_PRM nearest_grid fitoffset solid_tide p_scatter split_spectrum cut_slc split_aperture phasediff_get_topo_phase geocode_slc
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

install (FILES gmtsar_commands.h DESTINATION include/gmtsar)

add_subdirectory (csh)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
