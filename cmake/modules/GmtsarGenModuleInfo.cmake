# GmtsarGenModuleInfo.cmake — generate gmt_gmtsar_moduleinfo.h for the
# GMTSAR out-of-tree GMT supplement.
#
# Vendored/adapted from GMT's cmake/modules/GmtGenExtraHeaders.cmake and its
# devdocs/custom_supplements.rst out-of-tree template (LGPL, GMT Team), with
# two changes: (1) module sources are given as absolute paths, not basenames
# relative to a single SRC_DIR -- GMTSAR's *_module.c files are not all in
# one directory (snaphu_module.c lives under snaphu/src/); (2) the path list
# is read from a file (SRCS_LIST_FILE, one path per line) rather than a
# command-line -D variable -- GMTSAR has 70+ module sources, and passing
# them all inline blows past NMake/cmd's command-line length limit.
#
# Invoke with `cmake -P GmtsarGenModuleInfo.cmake -D OUTPUT_FILE=<path>
#   -D SRCS_LIST_FILE=<path to a newline-separated list of absolute paths>`.
#
# Scrapes THIS_MODULE_MODERN_NAME / CLASSIC_NAME / LIB / PURPOSE / KEYS from
# each source. Output is the body of a `static struct GMT_MODULEINFO
# modules[]` initializer; gmt_gmtsar_glue.c #includes it directly.

if (NOT DEFINED OUTPUT_FILE)
	message (FATAL_ERROR "GmtsarGenModuleInfo: OUTPUT_FILE not set")
endif ()
if (NOT DEFINED SRCS_LIST_FILE)
	message (FATAL_ERROR "GmtsarGenModuleInfo: SRCS_LIST_FILE not set")
endif ()

file (STRINGS "${SRCS_LIST_FILE}" PROGS_SRCS)

set (_moduleinfo "")
foreach (_prog_src ${PROGS_SRCS})
	file (READ "${_prog_src}" _src)

	set (_modern "")
	set (_classic "")
	set (_legacy "")
	set (_lib "")
	set (_purpose "")
	set (_keys "")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_MODERN_NAME[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_modern "${CMAKE_MATCH_1}")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_CLASSIC_NAME[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_classic "${CMAKE_MATCH_1}")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_NAME[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_legacy "${CMAKE_MATCH_1}")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_LIB[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_lib "${CMAKE_MATCH_1}")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_PURPOSE[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_purpose "${CMAKE_MATCH_1}")

	string (REGEX MATCH "#define[ \t]+THIS_MODULE_KEYS[ \t]+\"([^\"\n]*)\"" _m "${_src}")
	set (_keys "${CMAKE_MATCH_1}")

	if ("${_modern}" STREQUAL "")
		set (_modern "${_legacy}")
	endif ()
	if ("${_classic}" STREQUAL "")
		set (_classic "${_legacy}")
	endif ()

	if ("${_modern}" STREQUAL "")
		message (WARNING "GmtsarGenModuleInfo: ${_prog_src} has no THIS_MODULE_*_NAME -- skipping")
		continue ()
	endif ()
	if ("${_lib}" STREQUAL "")
		message (WARNING "GmtsarGenModuleInfo: ${_prog_src} has no THIS_MODULE_LIB -- skipping")
		continue ()
	endif ()
	if ("${_purpose}" STREQUAL "")
		message (WARNING "GmtsarGenModuleInfo: ${_prog_src} has no THIS_MODULE_PURPOSE")
	endif ()

	set (_row "\t{\"${_modern}\", \"${_classic}\", \"${_lib}\", \"${_purpose}\", \"${_keys}\"},")
	if (_moduleinfo)
		set (_moduleinfo "${_moduleinfo}\n${_row}")
	else ()
		set (_moduleinfo "${_row}")
	endif ()
endforeach ()

file (WRITE "${OUTPUT_FILE}" "${_moduleinfo}\n")
