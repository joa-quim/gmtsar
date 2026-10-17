#!/usr/bin/env bash
# Stage the GMTSAR GMT plugin for InteractiveGMT:
#
#   stage_plugin.sh <build dir> <stage dir> <commit>
#
# <stage dir>/gmtsar/lib/gmtsar.{so,dylib,dll}  the plugin (GMT_CUSTOM_LIBS points here)
# <stage dir>/gmtsar/share/gmtsar/              the GMTSAR sharedir: the same files the top-level
#                                               CMakeLists.txt installs (filters, snaphu configs,
#                                               virgin PRM templates, geoid grid)
# <stage dir>/gmtsar/GMTSAR_COMMIT              the commit it was built from
set -euo pipefail
build=$1 stage=$2/gmtsar commit=$3
src=$(cd "$(dirname "$0")/../.." && pwd)

lib=$(find "$build/gmtsar" -maxdepth 1 -type f \( -name gmtsar.so -o -name gmtsar.dylib -o -name gmtsar.dll \) | head -1)
[[ -n $lib ]] || { echo "no gmtsar plugin library in $build/gmtsar"; exit 1; }

mkdir -p "$stage/lib" "$stage/share/gmtsar/filters" "$stage/share/gmtsar/snaphu/config"
cp "$lib" "$stage/lib/"
# macOS: the library's own install name must not be the build directory's absolute path.
if [[ $(uname -s) == Darwin ]]; then
	install_name_tool -id "@rpath/$(basename "$lib")" "$stage/lib/$(basename "$lib")"
	otool -D "$stage/lib/$(basename "$lib")"
fi
cp "$src"/gmtsar/filters/[bfgsxy]* "$stage/share/gmtsar/filters/"
cp "$src"/gmtsar/csh/snaphu.conf.* "$stage/share/gmtsar/snaphu/config/"
cp "$src/preproc/ERS_preproc/scripts/virgin.PRM" "$src/preproc/ENVI_preproc/scripts/virgin_envisat.PRM" \
   "$src"/gmtsar/*.grd "$stage/share/gmtsar/"
echo "$commit" > "$stage/GMTSAR_COMMIT"
ls -la "$stage/lib"
du -sh "$stage"
