#!/usr/bin/env julia
#       $Id$
# Script to drive the xcorr to do the azimuthal pixel-tracking
# Originated by Matt Wei, April 19, 2010
# Rewrote by Kang Wang
# Last update: Aug. 09, 2013
#
# Revised by Xiaohua Xu, Nov 15, 2013: adding some pre_proc, redefined some parameters, add blockmedian,
# add shaded part, delete some redundant lines, easier to use
#
# Revised by David Sandwell, Dec 28, 2018: corrected azi pixel size using ground velocity and added more comments
#
using Printf

"""find the single subdirectory matching parent/*  (like `cd parent/*/`)"""
function glob_only_dir(parent::AbstractString)
    entries = sort(filter(f -> isdir(joinpath(parent, f)), readdir(parent)))
    return joinpath(parent, entries[1])
end

"""grep PATTERN file | awk -F"=" '{print \$2}'  -- first matching line's value after '=', trimmed"""
function grep_field_eq(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return strip(split(line, "=")[2])
        end
    end
    error("pattern not found: $pattern in $file")
end

"""ln -s srcdir/*suffix .  (errors for individual files are reported, not fatal)"""
function glob_symlink(srcdir::AbstractString, suffix::AbstractString)
    isdir(srcdir) || return
    for f in readdir(srcdir)
        if endswith(f, suffix)
            try
                symlink(joinpath(srcdir, f), f)
            catch e
                println(stderr, "ln: $f: $e")
            end
        end
    end
end

"""cmd | awk '{print \$n}'  -- nth whitespace field of a subprocess's first output line"""
function cmd_field(cmd::Cmd, n::Int)
    out = read(cmd, String)
    return split(out)[n]
end

function main(argv::Vector{String})
    if length(argv) != 7
        println("")
        println("Usage: make_a_offset.csh Master.PRM Aligned.PRM nx ny xsearch ysearch do_xcorr")
        println("")
        println("       nx - number of offsets to compute in the range direction (~num_rng/4)  ")
        println("       ny - number of offsets to compute in the azimuth direction (~num_az/6)  ")
        println("       xsearch - size of correlation window in range (e.g., 16) ")
        println("       ysearch - size of correlation window in azimuth (e.g., 16) ")
        println("       do_xcorr - 1-recalculate xcorr; 0-use results from previous xcorr")
        println("")
        exit(1)
    end
    println("make_a_offset.csh $(argv[1]) $(argv[2]) $(argv[3]) $(argv[4]) $(argv[5]) $(argv[6])")
    #
    master = argv[1]
    aligned = argv[2]
    nx = parse(Float64, argv[3])
    ny = parse(Float64, argv[4])
    xsearch = argv[5]
    ysearch = argv[6]
    do_xcorr = argv[7]
    #
    # pre_proc needed files
    #
    cd(glob_only_dir("intf"))
    mkdir("azi_offset")
    cd("azi_offset")
    #cp ../../../raw/$1 .
    #cp ../../../raw/$2 .
    cp("../../../SLC/$master", master; force=true)
    cp("../../../SLC/$aligned", aligned; force=true)
    #
    glob_symlink("../../../SLC", ".SLC")
    symlink("../../../topo/trans.dat", "trans.dat")
    symlink("../../../topo/dem.grd", "dem.grd")
    #
    PRF = parse(Float64, grep_field_eq(master, "PRF"))
    SC_vel = parse(Float64, grep_field_eq(master, "SC_vel"))
    earth_radius = parse(Float64, grep_field_eq(master, "earth_radius"))
    SC_height = parse(Float64, grep_field_eq(master, "SC_height"))
    #
    #  compute the ground velocity from the effrctive velocity using equation B12
    #
    ground_vel = SC_vel / sqrt(1 + SC_height / earth_radius)
    println("ground velocity: $ground_vel")
    azi_size = @sprintf("%10.3f", ground_vel / PRF)
    println("azi pixel size, $azi_size")
    #
    # these SLC's are already aligned so reset all the offsets to zero
    #
    run(`update_PRM $master rshift 0`)
    run(`update_PRM $master sub_int_r 0`)
    run(`update_PRM $master stretch_r 0.0`)
    run(`update_PRM $master a_stretch_r 0.0`)
    run(`update_PRM $master ashift 0`)
    run(`update_PRM $master sub_int_a 0.0`)
    run(`update_PRM $master stretch_a 0.0`)
    run(`update_PRM $master a_stretch_a 0.0`)
    run(`update_PRM $aligned rshift 0`)
    run(`update_PRM $aligned sub_int_r 0`)
    run(`update_PRM $aligned stretch_r 0.0`)
    run(`update_PRM $aligned a_stretch_r 0.0`)
    run(`update_PRM $aligned ashift 0`)
    run(`update_PRM $aligned sub_int_a 0.0`)
    run(`update_PRM $aligned stretch_a 0.0`)
    run(`update_PRM $aligned a_stretch_a 0.0`)
    #
    # make azimuth offset if do_xcorr = 1
    #
    if do_xcorr == "1"
        run(`xcorr $master $aligned -nx $(argv[3]) -ny $(argv[4]) -xsearch $xsearch -ysearch $ysearch -noshift`)
    end
    #
    # ********assume all offsets are less than 1. pixels
    # ********edit the following line
    #
    open("azi.dat", "w") do io
        for line in eachline("freq_xcorr.dat")
            w = split(line)
            v4 = parse(Float64, w[4])
            if v4 > -1.1 && v4 < 1.1
                println(io, "$(w[1]) $(w[3]) $(w[4]) $(w[5])")
            end
        end
    end
    #
    # do a block median on the offset data and grid the results
    #
    xmin = parse(Float64, cmd_field(`gmt gmtinfo azi.dat -C`, 1))
    xmax = parse(Float64, cmd_field(`gmt gmtinfo azi.dat -C`, 2))
    ymin = parse(Float64, cmd_field(`gmt gmtinfo azi.dat -C`, 3))
    ymax = parse(Float64, cmd_field(`gmt gmtinfo azi.dat -C`, 4))
    #
    xinc = trunc(Int, (xmax - xmin) / (nx - 1))
    yinc = trunc(Int, (ymax - ymin) / (ny - 1))
    #
    xinc = xinc * 12
    yinc = yinc * 12
    println("xinc:$xinc  yinc:$yinc")
    #
    run(pipeline(`gmt blockmedian azi.dat -R$xmin/$xmax/$ymin/$ymax -I$xinc/$yinc -Wi`, `awk '{print $1, $2, $3}'`, stdout="azi_b.dat"))
    #mv azi_b.dat azi.dat
    run(`gmt xyz2grd azi_b.dat -R$xmin/$xmax/$ymin/$ymax -I$xinc/$yinc -Gaoff.grd`)
    run(`gmt grdmath aoff.grd $azi_size MUL = azi_offset.grd`)
    #
    run(pipeline(`gmt grd2cpt azi_offset.grd -Cpolar -E30 -D`, stdout="azioff.cpt"))
    #gmt makecpt -Cpolar -T-4/4/.4 -Z > azioff.cpt
    run(pipeline(`gmt grdimage azi_offset.grd -JX5i -Cazioff.cpt -Q -P`, stdout="azioff.ps"))
    #
    # project to lon/lat coordinates
    #
    run(`proj_ra2ll_ascii.csh trans.dat azi_b.dat aoff.llo`)
    #
    xmin2 = parse(Float64, cmd_field(`gmt gmtinfo aoff.llo -C`, 1))
    xmax2 = parse(Float64, cmd_field(`gmt gmtinfo aoff.llo -C`, 2))
    ymin2 = parse(Float64, cmd_field(`gmt gmtinfo aoff.llo -C`, 3))
    ymax2 = parse(Float64, cmd_field(`gmt gmtinfo aoff.llo -C`, 4))
    #
    xinc2 = @sprintf("%12.5f", (xmax2 - xmin2) / (nx - 1))
    yinc2 = @sprintf("%12.5f", (ymax2 - ymin2) / (ny - 1))
    xinc2 = @sprintf("%.6g", parse(Float64, xinc2) * 12)
    yinc2 = @sprintf("%.6g", parse(Float64, yinc2) * 12)
    #
    println("xinc2:$xinc2  yinc2:$yinc2")
    #
    run(`gmt xyz2grd aoff.llo -R$xmin2/$xmax2/$ymin2/$ymax2 -I$xinc2/$yinc2 -r -fg -Gaoff_ll.grd`)
    run(`gmt grdmath aoff_ll.grd $azi_size MUL = azi_offset_ll.grd`)
    #
    run(`gmt grdsample dem.grd -Gs_dem.grd -R$xmin2/$xmax2/$ymin2/$ymax2 -I$xinc2/$yinc2 -r`)
    run(`gmt grdgradient dem.grd -Gtmp.grd -A325 -Nt.5`)
    run(`gmt grdmath tmp.grd .5 ADD = dem_grd.grd`)
    run(`gmt grdgradient s_dem.grd -Gs_dem_grd.grd -A45 -Nt.5`)
    #
    # plot the azimuth offset
    #
    r_topo = read(`gmt grdinfo dem.grd -T100`, String)
    run(pipeline(`gmt makecpt -Cgray -T-1/1/.1 -Z`, stdout="topo.cpt"))
    #
    x1 = parse(Float64, cmd_field(`gmt grdinfo azi_offset_ll.grd -C`, 2))
    x2 = parse(Float64, cmd_field(`gmt grdinfo azi_offset_ll.grd -C`, 3))
    #
    y1 = parse(Float64, cmd_field(`gmt grdinfo azi_offset_ll.grd -C`, 4))
    y2 = parse(Float64, cmd_field(`gmt grdinfo azi_offset_ll.grd -C`, 5))
    #
    xlim = @sprintf("%.6g", x2 - x1)
    ylim = @sprintf("%.6g", y2 - y1)
    #
    length_ = 20
    width = 16
    #
    scl1 = @sprintf("%.6g", length_ / parse(Float64, ylim))
    scl2 = @sprintf("%.6g", width / parse(Float64, xlim))
    scl = parse(Float64, scl1) < parse(Float64, scl2) ? scl1 : scl2
    #
    bounds = strip(read(`gmt grdinfo -I- azi_offset_ll.grd`, String))
    #
    run(pipeline(`gmt gmtdefaults -Ds`, stdout="gmt.conf"))
    run(`gmt set MAP_FRAME_TYPE plain`)
    #
    run(pipeline(`gmt psbasemap -Baf -BWSne -Jm$(scl)c $bounds -K -P`, stdout="azioff_ll.ps"))
    open("azioff_ll.ps", "a") do io
        run(pipeline(`gmt grdimage dem_grd.grd -J -R -Ctopo.cpt -K -O -Q`, stdout=io))
    end
    #gmt grdimage azi_offset_ll.grd -Is_dem_grd.grd -J -R -Cazioff.cpt -Q -K -O >> azioff_ll.ps
    open("azioff_ll.ps", "a") do io
        run(pipeline(`gmt grdimage azi_offset_ll.grd -J -R -Cazioff.cpt -Q -K -O`, stdout=io))
    end
    open("azioff_ll.ps", "a") do io
        run(pipeline(`gmt pscoast -N3,2p -W1,1p -Slightblue -J -R -K -O -Df -I1`, stdout=io))
    end
    open("azioff_ll.ps", "a") do io
        run(pipeline(`gmt psscale -Razi_offset_ll.grd -J -DJTC+w5c/0.35c+e -Cazioff.cpt -Bxaf -By+lm -O`, stdout=io))
    end
    run(`gmt psconvert azioff_ll.ps -P -Tg -Z`)
    println("Azimuth/Offset map: azioff_ll.png")
    #
    for f in readdir(".")
        if f in ("tmp.grd", "aoff_ll.grd", "aoff.grd", "aoff.llo", "azi.dat", "dem_grd.grd", "grey_tmp.cpt", "s_dem.grd", "temp.dat", "topo.cpt") ||
           startswith(f, "ps2rast") || startswith(f, "raln") || startswith(f, "ralt")
            rm(f; force=true)
        end
    end
end

main(ARGS)
