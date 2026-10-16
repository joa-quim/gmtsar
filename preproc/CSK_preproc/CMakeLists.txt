#
#	$Id: $
#

if (HAVE_M_LIBRARY)
	# link the math library
	set (LINK_LIBS m)
endif (HAVE_M_LIBRARY)

include_directories (include ../../gmtsar ../S1A_preproc/include ${HDF5_INCLUDE_DIR} ${GMT_INCLUDE_DIR})

set (LINK_LIBS ${LINK_LIBS} gmtsar)

if (WIN32)
add_definitions(/DH5_BUILT_AS_DYNAMIC_LIB)
endif (WIN32)

add_library (CSK_modules OBJECT src_raw/make_raw_csk.c src_slc/make_slc_csk.c src_slc2/make_slc_csk2.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_raw_csk_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_slc_csk_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_slc_csk2_module.c)
target_include_directories (CSK_modules PRIVATE include ../../gmtsar ../S1A_preproc/include ${HDF5_INCLUDE_DIR} ${GMT_INCLUDE_DIR} ${GDAL_INCLUDE_DIR})
target_sources (gmtsar PRIVATE $<TARGET_OBJECTS:CSK_modules>)
target_link_libraries (gmtsar ${HDF5_LIBRARY})

add_executable (make_raw_csk ../../gmtsar/cli/make_raw_csk.c)
target_link_libraries (make_raw_csk ${LINK_LIBS})

add_executable (make_slc_csk ../../gmtsar/cli/make_slc_csk.c)
target_link_libraries (make_slc_csk ${LINK_LIBS})

add_executable (make_slc_csk2 ../../gmtsar/cli/make_slc_csk2.c)
target_link_libraries (make_slc_csk2 ${LINK_LIBS})

# add the install targets
install (TARGETS make_raw_csk make_slc_csk make_slc_csk2
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
