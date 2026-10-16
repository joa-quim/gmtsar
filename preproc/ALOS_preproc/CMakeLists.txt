#
#	$Id$
#

if (HAVE_M_LIBRARY)
	# link the math library
	set (LINK_LIBS m)
endif (HAVE_M_LIBRARY)

include_directories (include ${GMT_INCLUDE_DIR} ../../gmtsar)

# ALOS's own copy of these lib_src sources (originally a separate ALOS.dll)
# is folded directly into the shared gmtsar target instead of linked as a
# separate library. Several of these files share a basename AND a top-level
# function name with gmtsar's own sources (utils.c, calc_dop.c, hermite_c.c,
# write_orb.c, rng_filter.c, siocomplex.c, polyfit.c) -- those symbols were
# renamed with an ALOS_ prefix throughout this directory tree first (see
# git history) so this fold doesn't collide with gmtsar's own definitions.
set (ALOS_LIB_SOURCES
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/utils.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/null_sio_struct.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/get_sio_struct.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/put_sio_struct.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/calc_dop.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/hermite_c.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/ALOS_ldr_orbit.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/ALOSE_orbits_utils.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/interpolate_ALOS_orbit.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/read_ALOS_sarleader.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/write_ALOS_LED.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/write_orb.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/set_ALOS_defaults.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/write_ALOS_prm.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/rng_expand.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/rng_compress.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/rng_filter.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/find_fft_length.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/siocomplex.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/polyfit.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/plh2xyz.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/xyz2plh.c
	${CMAKE_CURRENT_SOURCE_DIR}/lib_src/cfft1d.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/swap32.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/swap16.c ${CMAKE_CURRENT_SOURCE_DIR}/lib_src/fftpack.c)
set_source_files_properties (${ALOS_LIB_SOURCES} PROPERTIES
	INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_sources (gmtsar PRIVATE ${ALOS_LIB_SOURCES})

set (ALOS_COMMAND_SOURCES
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_baseline/ALOS_baseline.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_baseline/ALOS_llt2rat_sub.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_fbd2fbs/ALOS_fbd2fbs.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_fbd2fbs_SLC/ALOS_fbd2fbs_SLC.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_fbd2ss/ALOS_fbd2ss.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_fbs2fbd/ALOS_fbs2fbd.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_llt2rat/ALOS_llt2rat.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_look/ALOS_look.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_merge/ALOS_merge.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/ALOS_pre_process.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/parse_ALOS_commands.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/read_ALOS_data.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/read_ALOSE_data.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/swap_ALOS_data_info.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process/roi_utils.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SLC/ALOS_pre_process_SLC.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SLC/parse_ALOS_commands.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SLC/read_ALOS_data_SLC.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SLC/swap_ALOS_data_info.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SS/ALOS_pre_process_SS.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SS/parse_ALOS_commands.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SS/read_ALOS_data_SS.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_pre_process_SS/swap_ALOS_data_info.c)
set_source_files_properties (${ALOS_COMMAND_SOURCES} PROPERTIES
	INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_sources (gmtsar PRIVATE ${ALOS_COMMAND_SOURCES}
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_baseline_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_fbd2fbs_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_fbd2fbs_SLC_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_fbd2ss_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_fbs2fbd_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_llt2rat_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_look_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_merge_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_mosaic_ss/ALOS_mosaic_ss.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_mosaic_ss_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/ALOS_mosaic_ss_2frames/ALOS_mosaic_ss_2frames.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_mosaic_ss_2frames_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_pre_process_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_pre_process_SLC_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ALOS_pre_process_SS_module.c)
target_include_directories (gmtsar PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

set (LINK_LIBS ${LINK_LIBS} gmtsar ${GMT_LIBRARY})

add_executable (ALOS_baseline ../../gmtsar/cli/ALOS_baseline.c)
target_link_libraries (ALOS_baseline ${LINK_LIBS})

add_executable (ALOS_fbd2fbs ../../gmtsar/cli/ALOS_fbd2fbs.c)
target_link_libraries (ALOS_fbd2fbs ${LINK_LIBS})

add_executable (ALOS_fbd2fbs_SLC ../../gmtsar/cli/ALOS_fbd2fbs_SLC.c)
target_link_libraries (ALOS_fbd2fbs_SLC ${LINK_LIBS})

add_executable (ALOS_fbd2ss ../../gmtsar/cli/ALOS_fbd2ss.c)
target_link_libraries (ALOS_fbd2ss ${LINK_LIBS})

add_executable (ALOS_fbs2fbd ../../gmtsar/cli/ALOS_fbs2fbd.c)
target_link_libraries (ALOS_fbs2fbd ${LINK_LIBS})

add_executable (ALOS_llt2rat ../../gmtsar/cli/ALOS_llt2rat.c)
target_link_libraries (ALOS_llt2rat ${LINK_LIBS})

add_executable (ALOS_look ../../gmtsar/cli/ALOS_look.c)
target_link_libraries (ALOS_look ${LINK_LIBS})

add_executable (ALOS_merge ../../gmtsar/cli/ALOS_merge.c)
target_link_libraries (ALOS_merge ${LINK_LIBS})

add_executable (ALOS_mosaic_ss ../../gmtsar/cli/ALOS_mosaic_ss.c)
target_link_libraries (ALOS_mosaic_ss ${LINK_LIBS})

add_executable (ALOS_mosaic_ss_2frames ../../gmtsar/cli/ALOS_mosaic_ss_2frames.c)
target_link_libraries (ALOS_mosaic_ss_2frames ${LINK_LIBS})

add_executable (ALOS_pre_process ../../gmtsar/cli/ALOS_pre_process.c)
target_link_libraries (ALOS_pre_process ${LINK_LIBS})

add_executable (ALOS_pre_process_SLC ../../gmtsar/cli/ALOS_pre_process_SLC.c)
target_link_libraries (ALOS_pre_process_SLC ${LINK_LIBS})

add_executable (ALOS_pre_process_SS ../../gmtsar/cli/ALOS_pre_process_SS.c)
target_link_libraries (ALOS_pre_process_SS ${LINK_LIBS})

# add the install targets
install (TARGETS ALOS_baseline ALOS_fbd2fbs ALOS_fbd2fbs_SLC ALOS_fbd2ss ALOS_fbs2fbd ALOS_llt2rat ALOS_look ALOS_merge ALOS_mosaic_ss ALOS_mosaic_ss_2frames ALOS_pre_process ALOS_pre_process_SLC ALOS_pre_process_SS
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
