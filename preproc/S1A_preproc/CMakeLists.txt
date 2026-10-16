#
#	$Id: $
#

if (HAVE_M_LIBRARY)
	# link the math library
	set (LINK_LIBS m)
endif (HAVE_M_LIBRARY)

include_directories (include ../../gmtsar ${GMT_INCLUDE_DIR} ${TIFF_INCLUDE_DIR})

target_sources (gmtsar PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/lib/xml.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_orbit/ext_orb_s1a.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/ext_orb_s1a_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_spec_div/spectral_diversity.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/spectral_diversity_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_stitch/merge_swath.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/merge_swath_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_stitch/stitch_tops.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/stitch_tops_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_swath/make_slc_s1a.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_slc_s1a_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_tops/make_s1a_tops.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_s1a_tops_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_tops/make_s1a_tops_6par.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_s1a_tops_6par_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/src_assembly/assemble_tops.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/assemble_tops_module.c)
target_include_directories (gmtsar PRIVATE include ../../gmtsar ${GMT_INCLUDE_DIR} ${TIFF_INCLUDE_DIR} ${GDAL_INCLUDE_DIR})
target_link_libraries (gmtsar ${TIFF_LIBRARY})

set (LINK_LIBS ${LINK_LIBS} gmtsar)

add_executable (ext_orb_s1a ../../gmtsar/cli/ext_orb_s1a.c)
target_link_libraries (ext_orb_s1a ${LINK_LIBS})

add_executable (spectral_diversity ../../gmtsar/cli/spectral_diversity.c)
target_link_libraries (spectral_diversity ${LINK_LIBS})

add_executable (merge_swath ../../gmtsar/cli/merge_swath.c)
target_link_libraries (merge_swath ${LINK_LIBS})

add_executable (stitch_tops ../../gmtsar/cli/stitch_tops.c)
target_link_libraries (stitch_tops ${LINK_LIBS})

add_executable (make_slc_s1a ../../gmtsar/cli/make_slc_s1a.c)
target_link_libraries (make_slc_s1a ${LINK_LIBS})

add_executable (make_s1a_tops ../../gmtsar/cli/make_s1a_tops.c)
target_link_libraries (make_s1a_tops ${LINK_LIBS})

add_executable (make_s1a_tops_6par ../../gmtsar/cli/make_s1a_tops_6par.c)
target_link_libraries (make_s1a_tops_6par ${LINK_LIBS})

add_executable (assemble_tops ../../gmtsar/cli/assemble_tops.c)
target_link_libraries (assemble_tops ${LINK_LIBS})


# add the install targets
install (TARGETS ext_orb_s1a spectral_diversity merge_swath stitch_tops make_slc_s1a make_s1a_tops make_s1a_tops_6par assemble_tops
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
