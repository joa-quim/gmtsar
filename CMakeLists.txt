#
#	$Id$
#
# To modify the cmake process: Edit your cmake/ConfigUser.cmake file
#
# To build out-of-source do (example):
#
#	mkdir build
#	cd build
#	cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
#
# CMAKE_BUILD_TYPE can be: empty, Debug, Release, RelWithDebInfo or MinSizeRel
#

# Make sure the user doesn't play dirty with symlinks
get_filename_component (srcdir "${CMAKE_SOURCE_DIR}" REALPATH)
get_filename_component (bindir "${CMAKE_BINARY_DIR}" REALPATH)

# Disallow in-source builds
if (${srcdir} STREQUAL ${bindir})
	message(FATAL_ERROR "In-source builds are not allowed. "
	"Please create a directory and run cmake from there, passing the path "
	"to this source directory as the last argument. This process created "
	"the file `CMakeCache.txt' and the directory `CMakeFiles' in ${srcdir}. "
	"Please remove them.")
endif (${srcdir} STREQUAL ${bindir})

# Define minimum CMake version required
cmake_minimum_required (VERSION 3.5)

# Use NEW behavior with newer CMake releases
foreach(p
		CMP0025 # CMake 3.0: Compiler id for Apple Clang is now AppleClang
		CMP0079 # Allow subdirectories to extend/link the central gmtsar target
		)
	if(POLICY ${p})
		cmake_policy(SET ${p} NEW)
	endif()
endforeach()

# Define project name and language
project (GMTSAR C)
include (CTest)

# CMake builds the implementations into the GMTSAR module library.  The
# traditional Makefiles still compile these same sources as standalone tools.
add_compile_definitions (GMTSAR_MODULE_BUILD)

# MSVC needs an export table for legacy libraries whose headers do not
# consistently use dllexport.
if (MSVC)
	set (CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
	# Include the fork's neutralized declspec shim before GMT's header of the
	# same name.  This prevents GMT's dllimport macro from being applied to
	# GMTSAR function definitions compiled into our own DLLs.
	add_compile_options (/FI${CMAKE_SOURCE_DIR}/declspec.h)
endif ()

# Much of the preprocessor code calls functions without a visible prototype
# (and has implicit int), which GCC 14 and Clang 16 made errors.  Keep them
# warnings, as they are with MSVC and older compilers.  Headers such as the
# ERS make_prm ones also define (not declare) globals that several files of
# the one library include: -fcommon merges them, as MSVC does and as GCC did
# before version 10 (the Makefile build uses -z muldefs for the same reason).
if (CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
	add_compile_options (-Wno-error=implicit-function-declaration
		-Wno-error=implicit-int -Wno-error=incompatible-pointer-types -fcommon)
endif ()

# Where to find our CMake modules (this variable is visible in subdirectories).
set (CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/modules/"
	CACHE INTERNAL "Location of our custom CMake modules." FORCE)

# Include configuration options (default options and options overridden by user).
include (ConfigCMake)

# Find UNIX commands
include (FindUnixCommands)
find_program (SVN svn)
find_program (GS gs gswin64)

# Find dependent libraries
find_package (GMT REQUIRED)
find_package (TIFF REQUIRED)
if (LAPACK_LIBRARIES)
	# An explicitly supplied LAPACK library is used as given.  The MSVC build
	# passes a known-compatible import library, and the CI plugin build passes
	# the OpenBLAS GMT_jll's libgmt links (LAPACK included).  Avoid
	# FindLAPACK's Fortran/BLAS probes, which are unnecessary here and
	# unreliable in a C-only Visual Studio environment.
	set (LAPACK_FOUND TRUE)
else ()
	find_package (LAPACK REQUIRED)
endif ()

# check for math and POSIX functions
include(ConfigureChecks)

# Add subdirectories
add_subdirectory (gmtsar)
if (EXISTS "${CMAKE_SOURCE_DIR}/snaphu/src/CMakeLists.txt")
	add_subdirectory (snaphu/src)
endif ()
add_subdirectory (preproc)

# The sensor OBJECT libraries are compiled into the gmtsar library, so they
# see GMTSAR's EXTERN_MSC declarations as the library itself does (see the
# LIBRARY_EXPORTS comment in gmtsar/CMakeLists.txt); otherwise GMT's
# declspec.h makes them dllimport references that MinGW cannot resolve.
foreach (_t CSK_modules ENVI_modules ENVI_SLC_decode_modules ERS_modules
		GF3_modules LT1_modules NSR_modules RS2_modules TSX_modules)
	if (TARGET ${_t})
		target_compile_definitions (${_t} PRIVATE LIBRARY_EXPORTS)
	endif ()
endforeach ()

# Install the GMTSAR "sharedir" (filter kernels, snaphu configs, virgin PRM
# templates) -- the CMake build's counterpart to the top-level Makefile's
# `install:` target (see Makefile, sharedir rules). Only the traditional
# ./configure && make path did this; the CMake path (gmtsar/CMakeLists.txt's
# WIN32 block; this is Windows-only in practice today) never had an
# equivalent, so filter/gmtsar_sharedir.csh-dependent tools (filter,
# fitoffset, ...) had no share/gmtsar to resolve. Mirrors the Makefile's
# file selection exactly: gmtsar/filters/[bfgsxy]* (kernel files), csh
# snaphu.conf.* configs, and the two virgin PRM templates.
install (DIRECTORY DESTINATION share/gmtsar/filters)
install (DIRECTORY DESTINATION share/gmtsar/snaphu/config)
file (GLOB _gmtsar_share_filters "${CMAKE_SOURCE_DIR}/gmtsar/filters/[bfgsxy]*")
install (FILES ${_gmtsar_share_filters} DESTINATION share/gmtsar/filters)
file (GLOB _gmtsar_share_snaphu_conf "${CMAKE_SOURCE_DIR}/gmtsar/csh/snaphu.conf.*")
install (FILES ${_gmtsar_share_snaphu_conf} DESTINATION share/gmtsar/snaphu/config)
file (GLOB _gmtsar_share_grds "${CMAKE_SOURCE_DIR}/gmtsar/*.grd")
install (FILES
	"${CMAKE_SOURCE_DIR}/preproc/ERS_preproc/scripts/virgin.PRM"
	"${CMAKE_SOURCE_DIR}/preproc/ENVI_preproc/scripts/virgin_envisat.PRM"
	${_gmtsar_share_grds}
	DESTINATION share/gmtsar)

# Configuration done
message(
	"*  Options:\n"
	"*  GMT library                : ${GMT_LIBRARY}\n"
	"*  GMT include dir            : ${GMT_INCLUDE_DIR}\n"
	"*  TIFF library               : ${TIFF_LIBRARY}\n"
	"*  LAPACK library             : ${LAPACK_LIBRARIES} ${LAPACK_lapack_LIBRARY}\n"
	"*\n"
	"*  Locations:\n"
	"*  Installing GMTSAR in       : ${CMAKE_INSTALL_PREFIX}\n"
)

# For debugging: print all set variables
#get_cmake_property(_variableNames VARIABLES)
#foreach (_variableName ${_variableNames})
#	message(STATUS "${_variableName}=${${_variableName}}")
#endforeach()

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
