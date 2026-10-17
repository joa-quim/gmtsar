#!/usr/bin/env julia
#       $Id$
# Xiaopeng Tong Nov 23 2009
#
# unset noclobber
#
# Converts a complex SLC file to a real amplitude grd
# file using optional filter and a PRM file
#
# define the filters
#
include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

function main(argv::Vector{String})
    sharedir = strip(read(`$GMTSAR_JULIA $(gmtsar_script("gmtsar_sharedir"))`, String))
    fil1 = "$sharedir/filters/gauss5x3"
    fil2 = "$sharedir/filters/gauss9x5"
    #
    # check for number of arguments
    #
    if length(argv) != 3
        println("")
        println("Usage: slc2amp.csh filein.PRM rng_dec fileout.grd ")
        println("")
        println("       rng_dec is range decimation")
        println("       e.g. 1 for ERS ENVISAT ALOS FBD")
        println("            2 for ALOS FBS ")
        println("            4 for TSX")
        println("")
        println("Example: slc2amp.csh IMG-HH-ALPSRP055750660-H1.0__A.PRM 2 amp-ALPSRP055750660-H1.0__A.grd")
        println("")
        exit(1)
    end
    #
    # filter the amplitudes done in conv
    # check the input and output filename before
    #
    if (occursin("PRM", argv[1]) || occursin("prm", argv[1])) && occursin("grd", argv[3])
        println(" range decimation is:", " ", argv[2])
        outarg = "$(argv[3])=bf"
        run(`gmt conv -X4 -Y$(argv[2]) -C$fil1 -I$(argv[1]) -G$outarg`)
    else
        println("slc2amp.csh")
        println("wrong filename")
        exit(1)
    end
    #
    # get the zmin and zmax value
    #
    outarg = "$(argv[3])=bf"
    run(`gmt grdmath $outarg 1 MUL = $(argv[3])`)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
