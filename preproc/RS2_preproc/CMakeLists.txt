#
#	$Id: $
#

if (HAVE_M_LIBRARY)
	# link the math library
	set (LINK_LIBS m)
endif (HAVE_M_LIBRARY)

include_directories (include ../../gmtsar ../S1A_preproc/include ${GMT_INCLUDE_DIR} ${TIFF_INCLUDE_DIR})

set (LINK_LIBS ${LINK_LIBS} gmtsar)

add_library (RS2_modules OBJECT src/make_slc_rs2.c ${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar/make_slc_rs2_module.c)
target_include_directories (RS2_modules PRIVATE include ../../gmtsar ../S1A_preproc/include ${GMT_INCLUDE_DIR} ${TIFF_INCLUDE_DIR} ${GDAL_INCLUDE_DIR})
target_sources (gmtsar PRIVATE $<TARGET_OBJECTS:RS2_modules>)

add_executable (make_slc_rs2 ../../gmtsar/cli/make_slc_rs2.c)
target_link_libraries (make_slc_rs2 ${LINK_LIBS})


# add the install targets
install (TARGETS make_slc_rs2
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
