#
#	$Id: CMakeLists.txt 377 2016-08-13 23:07:14Z fwobbe $
#

set (SNAPHU_SOURCES
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_module.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_cost.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_cs2.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_io.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_solver.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_tile.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_util.c
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu_cs2types.h
	${CMAKE_CURRENT_SOURCE_DIR}/snaphu.h)

target_sources (gmtsar PRIVATE ${SNAPHU_SOURCES})
target_include_directories (gmtsar PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# snaphu_module.c alone needs GMT's dev headers and gmtsar_commands.h.  Scope
# these to that one file (not the whole gmtsar target): several other
# sources folded into gmtsar (e.g. preproc/ALOS_preproc/.../ALOS_baseline.c)
# ship their own same-named local headers (PRM.h, etc.), and a target-wide
# include directory here previously shadowed those with GMTSAR's own PRM.h,
# breaking their build.
set_source_files_properties (${CMAKE_CURRENT_SOURCE_DIR}/snaphu_module.c PROPERTIES
	INCLUDE_DIRECTORIES "${GMT_INCLUDE_DIR};${GDAL_INCLUDE_DIR};${CMAKE_CURRENT_SOURCE_DIR}/../../gmtsar")
add_executable (snaphu ../../gmtsar/cli/snaphu.c)
target_include_directories (snaphu PRIVATE ../../gmtsar ${GMT_INCLUDE_DIR})
target_link_libraries (snaphu gmtsar ${GMT_LIBRARY})

if (HAVE_M_LIBRARY)
	# link the math library
	target_link_libraries (snaphu m)
endif (HAVE_M_LIBRARY)

if (WIN32)
	# gethostname() is provided by Winsock on native Windows (MSVC and MinGW).
	target_link_libraries (snaphu ws2_32)
	target_link_libraries (gmtsar ws2_32)
endif (WIN32)

# add the install targets
install (TARGETS snaphu
	ARCHIVE DESTINATION lib
	COMPONENT Runtime
	LIBRARY DESTINATION lib
	COMPONENT Runtime
	RUNTIME DESTINATION bin
	COMPONENT Runtime)

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
