#
#	$Id: $
#

if (HAVE_M_LIBRARY)
	# link the math library
	set (LINK_LIBS m)
endif (HAVE_M_LIBRARY)

# ENVI uses the ALOS orbit/PRM ABI.  Keep that include directory ahead of
# gmtsar's similarly named headers, otherwise MSVC picks incompatible PRM and
# lib_functions definitions.
include_directories (include ../ALOS_preproc/include ../../gmtsar ${GMT_INCLUDE_DIR})

add_library (ENVI lib_src/ENVI_ldr_orbit.c lib_src/read_ENVI_orb.c)
target_link_libraries (ENVI gmtsar ${LINK_LIBS})

set (LINK_LIBS ${LINK_LIBS} gmtsar ENVI)

add_library (ENVI_modules OBJECT
	lib_src/ENVI_ldr_orbit.c lib_src/read_ENVI_orb.c
	ASA_CAT/asa_cat.c Dop_orbit/calc_dop_orb_envi.c
	ENVI_baseline/ENVI_baseline.c ENVI_baseline/ENVI_llt2rat_sub.c
	ENVI_decode/asa_im_decode.c ENVI_llt2rat/ENVI_llt2rat.c ENVI_look/ENVI_look.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/asa_cat_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/calc_dop_orb_envi_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ENVI_baseline_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/asa_im_decode_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ENVI_llt2rat_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ENVI_look_module.c)
target_include_directories (ENVI_modules PRIVATE include ../ALOS_preproc/include ../../gmtsar ${GMT_INCLUDE_DIR} ${GDAL_INCLUDE_DIR})
target_sources (gmtsar PRIVATE $<TARGET_OBJECTS:ENVI_modules>)

add_executable (asa_cat ../../gmtsar/cli/asa_cat.c)
target_link_libraries (asa_cat ${LINK_LIBS})

add_executable (calc_dop_orb_envi ../../gmtsar/cli/calc_dop_orb_envi.c)
target_link_libraries (calc_dop_orb_envi ${LINK_LIBS})

add_executable (ENVI_baseline ../../gmtsar/cli/ENVI_baseline.c)
target_link_libraries (ENVI_baseline ${LINK_LIBS})

add_executable (asa_im_decode ../../gmtsar/cli/asa_im_decode.c)
target_link_libraries (asa_im_decode ${LINK_LIBS})

add_executable (ENVI_llt2rat ../../gmtsar/cli/ENVI_llt2rat.c)
target_link_libraries (ENVI_llt2rat ${LINK_LIBS})

add_executable (ENVI_look ../../gmtsar/cli/ENVI_look.c)
target_link_libraries (ENVI_look ${LINK_LIBS})

set (EPR_API_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ENVI_SLC_decode/epr_api-2.3/src)
add_library (epr_api STATIC
	${EPR_API_DIR}/epr_api.c
	${EPR_API_DIR}/epr_band.c
	${EPR_API_DIR}/epr_bitmask.c
	${EPR_API_DIR}/epr_core.c
	${EPR_API_DIR}/epr_dataset.c
	${EPR_API_DIR}/epr_dddb.c
	${EPR_API_DIR}/epr_dsd.c
	${EPR_API_DIR}/epr_dump.c
	${EPR_API_DIR}/epr_field.c
	${EPR_API_DIR}/epr_msph.c
	${EPR_API_DIR}/epr_param.c
	${EPR_API_DIR}/epr_product.c
	${EPR_API_DIR}/epr_ptrarray.c
	${EPR_API_DIR}/epr_record.c
	${EPR_API_DIR}/epr_string.c
	${EPR_API_DIR}/epr_swap.c
	${EPR_API_DIR}/epr_typconv.c)
target_include_directories (epr_api PRIVATE ${EPR_API_DIR})

add_library (ENVI_SLC_decode_modules OBJECT
	ENVI_SLC_decode/envi_slc_decode.c
	ENVI_SLC_decode/envisat_dump_data.c
	ENVI_SLC_decode/envisat_dump_header.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/envi_slc_decode_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/envisat_dump_data_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/envisat_dump_header_module.c)
target_include_directories (ENVI_SLC_decode_modules PRIVATE
	ENVI_SLC_decode include ../ALOS_preproc/include ../S1A_preproc/include ../../gmtsar
	${GMT_INCLUDE_DIR} ${GDAL_INCLUDE_DIR} ${TIFF_INCLUDE_DIR})
target_sources (gmtsar PRIVATE $<TARGET_OBJECTS:ENVI_SLC_decode_modules>)
target_link_libraries (gmtsar epr_api)

add_executable (envi_slc_decode ../../gmtsar/cli/envi_slc_decode.c)
target_link_libraries (envi_slc_decode ${LINK_LIBS})

add_executable (envisat_dump_data ../../gmtsar/cli/envisat_dump_data.c)
target_link_libraries (envisat_dump_data ${LINK_LIBS})

add_executable (envisat_dump_header ../../gmtsar/cli/envisat_dump_header.c)
target_link_libraries (envisat_dump_header ${LINK_LIBS})

# add the install targets
install (TARGETS asa_cat calc_dop_orb_envi ENVI_baseline asa_im_decode ENVI_llt2rat ENVI_look epr_api envi_slc_decode envisat_dump_data envisat_dump_header
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
