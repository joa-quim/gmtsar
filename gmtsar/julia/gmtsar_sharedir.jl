#!/usr/bin/env julia
#	$Id: gmtsar_sharedir.csh.in 42 2013-04-08 20:43:57Z pwessel $
# Just report the GMTSAR share directory
#
# gmtsar_sharedir.csh has the install-time path filled in by configure; this port has no
# configure step, so the directory comes from GMTSAR_SHAREDIR when that is set (the filters,
# snaphu configurations and PRM templates installed under <prefix>/share/gmtsar).
function main(argv::Vector{String})
    println(get(ENV, "GMTSAR_SHAREDIR", "/share/gmtsar"))
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
