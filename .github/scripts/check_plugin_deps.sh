#!/usr/bin/env bash
# Every library the GMTSAR plugin links must be one GMT_jll brings (already in the process that
# runs GMT.jl), or a base system library. Anything else -- a system GMT, GDAL, HDF5, a MinGW
# runtime DLL, a UCRT import -- fails the build.
#
#   check_plugin_deps.sh <plugin library> <libdirs.txt from jll_cache.jl> <build dir>
#
# Windows also checks that every module of the plugin's own table is exported: GMT finds a module
# by its exported GMT_<name>, and MinGW exports only the dllexport'ed symbols once there is one.
set -euo pipefail
lib=$1
jll=$(while IFS= read -r d; do d=${d%$'\r'}; [[ -d $d ]] && ls "$d"; done < "$2" | tr 'A-Z' 'a-z' | sort -u)
bad=0

case "$(uname -s)" in
Linux)
	for n in $(readelf -d "$lib" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do
		if grep -qxF "$n" <<< "$jll"; then w=jll
		elif [[ $n =~ ^(libc|libm|libdl|libpthread|librt|libgcc_s|libgomp|ld-linux-x86-64)\.so ]]; then w=system
		else w=BAD; bad=1
		fi
		echo "   $w  $n"
	done
	echo "   GLIBC max: $(objdump -T "$lib" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
	;;
Darwin)
	for n in $(otool -L "$lib" | tail -n +2 | awk '{print $1}'); do
		case $n in
			@rpath/*|@loader_path/*|/usr/lib/*|/System/*) echo "   ok   $n" ;;
			*) echo "   BAD  $n"; bad=1 ;;
		esac
	done
	;;
*)	# MSYS2 on Windows
	sys='^(kernel32|msvcrt|ws2_32|advapi32|user32|shell32|ole32|oleaut32|shlwapi|bcrypt|crypt32|secur32|iphlpapi|dbghelp|psapi|winmm|gdi32|comdlg32|ntdll)\.dll$'
	for n in $(objdump -p "$lib" | sed -n 's/^\s*DLL Name: //p'); do
		l=$(tr 'A-Z' 'a-z' <<< "$n")
		if [[ $l =~ ^(api-ms-win-crt|ucrtbase|libwinpthread|libgcc|libstdc) ]]; then w=BAD
		elif [[ $l =~ $sys ]]; then w=system
		elif grep -qxF "$l" <<< "$jll"; then w=jll
		else w=BAD
		fi
		[[ $w == BAD ]] && bad=1
		echo "   $w  $n"
	done
	info=$(find "$3" -name gmt_gmtsar_moduleinfo.h | head -1)
	objdump -p "$lib" | awk '/\[Ordinal\/Name Pointer\] Table/ {f=1; next} f && /^\t\[/ {print $NF}' | sort -u > exports.txt
	for m in $(grep -o '{"[A-Za-z0-9_]*"' "$info" | tr -d '{"'); do
		grep -qx "GMT_$m" exports.txt || { echo "MISSING export GMT_$m"; bad=1; }
	done
	for f in show_all list_all classic_all keys group; do
		grep -qx "gmtsar_module_$f" exports.txt || { echo "MISSING export gmtsar_module_$f"; bad=1; }
	done
	echo "   $(grep -c '{"' "$info") modules, all exported unless listed above"
	;;
esac
exit $bad
