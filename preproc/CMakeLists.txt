#
#	$Id$
#

# Add subdirectories
add_subdirectory (ALOS_preproc)
add_subdirectory (S1A_preproc)
add_subdirectory (ERS_preproc)
add_subdirectory (ENVI_preproc)
add_subdirectory (TSX_preproc)
add_subdirectory (RS2_preproc)
add_subdirectory (GF3_preproc)
add_subdirectory (LT1_preproc)
if (HDF5_INCLUDE_DIR AND HDF5_LIBRARY)
	add_subdirectory (CSK_preproc)
	add_subdirectory (NSR_preproc)
endif ()

# vim: textwidth=78 noexpandtab tabstop=2 softtabstop=2 shiftwidth=2
