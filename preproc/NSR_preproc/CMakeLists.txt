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

add_library (NSR_modules OBJECT src_slc/make_slc_nsr.c ${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_slc_nsr_module.c)
target_include_directories (NSR_modules PRIVATE ../../gmtsar ../S1A_preproc/include ${HDF5_INCLUDE_DIR} ${GMT_INCLUDE_DIR} ${GDAL_INCLUDE_DIR})
target_sources (gmtsar PRIVATE $<TARGET_OBJECTS:NSR_modules>)
target_link_libraries (gmtsar ${HDF5_LIBRARY})

add_executable (make_slc_nsr ../../gmtsar/cli/make_slc_nsr.c)
target_link_libraries (make_slc_nsr ${LINK_LIBS})

# add the install targets
install (TARGETS make_slc_nsr
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
