# Write a CMake initial-cache file that points GMTSAR's finders at GMT_jll and the libraries it
# brings (GDAL, libtiff, OpenBLAS32, HDF5, netCDF), for the GMT plugin built for InteractiveGMT.
# GMT.jl decides which GMT_jll users get, so it is resolved through GMT.jl, in an environment
# that the smoke test then uses again.
#
#   julia jll_cache.jl <envdir> <cache.cmake> <libdirs.txt>
#
# <libdirs.txt> receives the directories holding GMT_jll's shared libraries (Linux and macOS:
# their lib/; Windows: their bin/, and Julia's own bin/, which the process running GMT.jl
# has loaded too), one per line, for the dependency checks.

using Pkg
Pkg.activate(ARGS[1])
Pkg.add(["GMT", "GMT_jll"]; io = devnull)
using GMT_jll

const WIN = Sys.iswindows()
fwd(p) = replace(p, '\\' => '/')

# Julia's own bin directory is in LIBPATH_list too; its libraries must not be linked against.
libdirs = unique(filter(d -> isdir(d) && normpath(d) != normpath(Sys.BINDIR),
                        vcat(joinpath(GMT_jll.artifact_dir, WIN ? "bin" : "lib"), GMT_jll.LIBPATH_list)))

# The artifact (prefix) whose shared libraries include one named <stem>*.
function owner(stem)
	for d in libdirs
		any(f -> startswith(f, stem), readdir(d)) && return dirname(d)
	end
	error("no $stem* in the GMT_jll libraries")
end

# The file to link with, in that artifact's lib/: the import library on Windows. The shortest
# matching name, so libtiff.so is taken over libtiffxx.so and libhdf5.so over libhdf5_hl.so.
function linklib(prefix, stem)
	ext = WIN ? ".dll.a" : Sys.isapple() ? ".dylib" : ".so"
	L = joinpath(prefix, "lib")
	f = filter(f -> startswith(f, stem) && endswith(f, ext), readdir(L))
	isempty(f) && error("no $stem*$ext in $L")
	return fwd(joinpath(L, first(sort(f; by = length))))
end

gmt    = GMT_jll.artifact_dir
gdal   = owner("libgdal")
tiff   = owner("libtiff")
hdf5   = owner("libhdf5")
blas   = owner("libopenblas.")      # "." so Julia's own libopenblas64_ never matches
netcdf = owner("libnetcdf")

open(ARGS[2], "w") do io
	c(var, val, typ = "STRING") = println(io, "set($var \"", val, "\" CACHE $typ \"\")")
	c("CMAKE_PREFIX_PATH", join(unique(fwd.(dirname.(libdirs))), ';'))
	c("GMT_INCLUDE_DIR",   fwd(joinpath(gmt, "include", "gmt")), "PATH")
	c("GMT_LIBRARY",       WIN ? fwd(joinpath(gmt, "lib", "gmt.dll.a")) : linklib(gmt, "libgmt"), "FILEPATH")
	# gmt-config is a script with the build machine's paths in it: never run it.
	c("GMT_CONFIG",        WIN ? "\${CMAKE_COMMAND}" : "/usr/bin/true", "FILEPATH")
	c("GDAL_INCLUDE_DIR",  fwd(joinpath(gdal, "include")), "PATH")
	c("TIFF_INCLUDE_DIR",  fwd(joinpath(tiff, "include")), "PATH")
	c("TIFF_LIBRARY",      linklib(tiff, "libtiff"), "FILEPATH")
	# LAPACK as libgmt gets it: OpenBLAS32_jll's libopenblas (32-bit integers, LAPACK included),
	# already in the process with GMT. Not LAPACK32_jll: on Windows its import library names a
	# liblapack.dll that the artifact does not have (it ships liblapack32.dll).
	c("LAPACK_LIBRARIES",  linklib(blas, "libopenblas"))
	c("HDF5_INCLUDE_DIR",  fwd(joinpath(hdf5, "include")), "PATH")
	c("HDF5_LIBRARY",      linklib(hdf5, "libhdf5"), "FILEPATH")
	# GMT's gmt_dev.h -> gmt_shore.h includes <netcdf.h>; only GMT_jll has it.
	c("CMAKE_C_FLAGS",     "-I" * fwd(joinpath(netcdf, "include")))
end

write(ARGS[3], join(fwd.(WIN ? vcat(libdirs, Sys.BINDIR) : libdirs), '\n'))
println("GMT_jll ", pkgversion(GMT_jll), " at ", gmt)
print(read(ARGS[2], String))
