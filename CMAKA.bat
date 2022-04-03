@echo off

set BITS=64
set VC=14

REM md build
REM cd build

cmake -G "Ninja" C:\progs_cygw\GMTdev\gmtsar ^
		-DCMAKE_BUILD_TYPE=Release ^
		-DCMAKE_CXX_COMPILER=cl -DCMAKE_C_COMPILER=cl ^
		-DCMAKE_INSTALL_PREFIX=../compileds/VC%VC%_%BITS% ^
		-DGMT_LIBRARY=C:/progs_cygw/GMTdev/gmt5/compileds/gmt6/VC14_64/lib/gmt.lib ^
		-DGMT_INCLUDE_DIR=C:/progs_cygw/GMTdev/gmt5/compileds/gmt6/VC14_64/include/gmt ^
		-DTIFF_LIBRARY=C:/programs/compa_libs/tiff-4.1.0/compileds/VC14_64/lib/libtiff_i.lib ^
		-DTIFF_INCLUDE_DIR=C:/programs/compa_libs/tiff-4.1.0/compileds/VC14_64/include. ^
		-DLAPACK_LIBRARIES=C:/programs/compa_libs/lapack-3.5.0/compileds/lib/liblapack.lib

REM ninja install

REM cd ..
REM rd /S /Q build
