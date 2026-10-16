#!/usr/bin/env julia
#
#  Eric Lindsey, July 2022
#
# Script to create DEM for GMTSAR, relative to WGS84 ellipsoid
#
function main(argv::Vector{String})
    if length(argv) != 4 && length(argv) != 5
        println("")
        println("Usage: make_dem.csh W E S N [mode]")
        println("      Uses GMT server to download SRTM 1-arcsec data (@earth_relief_xxs)")
        println("      and removes the EGM96 geoid to make heights relative to WGS84.")
        println("")
        println("      mode 1:SRTM-1s 2:SRTM-3s")
        println("")
        println("Example: make_dem.csh -115 -112 32 35 2")
        println("")
        exit(1)
    end
    #
    println("")
    println("START: make_dem.csh")
    println("")

    mode = length(argv) == 5 ? argv[5] : "1"

    #
    # get region in GMT format
    #
    R = "-R$(argv[1])/$(argv[2])/$(argv[3])/$(argv[4])"
    #
    # need to set this for the distribution
    #
    sharedir = strip(read(`gmtsar_sharedir.csh`, String))
    #
    # get srtm data
    #
    if mode == "1"
        run(`gmt grdcut @earth_relief_01s $R -Gdem_ortho.grd`)
    elseif mode == "2"
        run(`gmt grdcut @earth_relief_03s $R -Gdem_ortho.grd`)
    else
        println("[ERROR]:Wrong DEM mode selected.")
    end
    #
    # resample and remove geoid
    #
    run(`gmt grdsample $sharedir/geoid_egm96_icgem.grd -Rdem_ortho.grd -Ggeoid_resamp.grd -Vq`)
    run(`gmt grdmath -Vq dem_ortho.grd geoid_resamp.grd ADD = dem.grd`)
    #
    # clean up
    #
    rm("geoid_resamp.grd"; force=true)
    #
    println("")
    println("created dem.grd, heights relative to WGS84 ellipsoid")
    println("")
    println("END: make_dem.csh")
    println("")
end

main(ARGS)
