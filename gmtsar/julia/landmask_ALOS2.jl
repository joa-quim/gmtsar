#!/usr/bin/env julia
#       $Id$

# make a landmask

#
function main(argv::Vector{String})
    if length(argv) != 1
        println("")
        println("Usage: landmask.csh region_cut[0/10600/0/27648]")
        println("")
        println("    make a landmask in radar coordinates ")
        println("NOTE: The region_cut can be specified in batch.config file")
        println("")
        exit(1)
    end

    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end

    println("")
    println("MAKE LANDMASK -- START")
    println("REQUIRE FULL RESOLUTION COASTLINE FROM GMT")
    println("")

    grdinfo_Ineg = split(strip(read(`gmt grdinfo -I- dem.grd`, String)))
    grdinfo_I = split(strip(read(`gmt grdinfo -I dem.grd`, String)))
    run(`gmt grdlandmask -Glandmask.grd $grdinfo_Ineg $grdinfo_I $V -NNaN/1 -Df`)
    run(`proj_ll2ra.csh trans.dat landmask.grd landmask_ra.grd`)
    # if the landmask region is smaller than the region_cut pad with NaN
    run(pipeline(`gmt grd2xyz landmask_ra.grd -bo`, stdout="landmask_ra.xyz"))
    grdinfo_I2 = split(strip(read(`gmt grdinfo -I landmask_ra.grd`, String)))
    run(`gmt xyz2grd landmask_ra.xyz -bi -r -R$(argv[1]) $grdinfo_I2 -Gtmp.grd`)
    mv("tmp.grd", "landmask_ra.grd"; force=true)
    run(`gmt grdsample landmask_ra.grd -Gtmp.grd -R$(argv[1]) -I2/32 -nl+t0.1`)
    mv("tmp.grd", "landmask_ra.grd"; force=true)

    # cleanup
    rm("landmask.grd"; force=true)
    rm("landmask_ra.xyz"; force=true)

    println("MAKE LANDMASK -- END")
    #
end

main(ARGS)
