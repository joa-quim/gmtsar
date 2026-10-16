#!/usr/bin/env julia
#	$Id: gmtsar_sharedir.csh.in 42 2013-04-08 20:43:57Z pwessel $
# Just report the GMTSAR share directory
function main(argv::Vector{String})
    println("/share/gmtsar")
end

main(ARGS)
