#!/usr/bin/env julia
#       $Id$
# Xiaohua Xu and David Sandwell Dec 23 2015
#
#  script to align S1 TOPS mode data
#
#  1) Make PRM and LED files for both master and aligned.
#
#  2) Do geometric back projection to determine the alignment parameters.
#
#  3) Make PRM, LED and SLC files for both master and aligned that are aligned
#     at the fractional pixel level.
#
# alias rm 'rm -f'
# unset noclobber
#
using Printf

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | tail -1 | awk '{print \$3}'  -- last matching line's 3rd whitespace field"""
function grep_field_last(file::AbstractString, pattern::AbstractString)
    result = nothing
    for line in eachline(file)
        if occursin(pattern, line)
            result = split(line)[3]
        end
    end
    result === nothing && error("pattern not found: $pattern in $file")
    return result
end

"""grep PATTERN file | grep -v EXCLUDE | tail -1 | awk '{print \$3}'"""
function grep_field_exclude_last(file::AbstractString, pattern::AbstractString, exclude::AbstractString)
    result = nothing
    for line in eachline(file)
        if occursin(pattern, line) && !occursin(exclude, line)
            result = split(line)[3]
        end
    end
    result === nothing && error("pattern not found: $pattern (excluding $exclude) in $file")
    return result
end

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    if length(argv) < 5
        println(" ")
        println("Usage: align_tops.jl master_prefix master_orb_file aligned_s1a_prefix aligned_orb_file dem.grd")
        println(" ")
        println("Be sure the tiff, xml, orbit and dem files are available in the local directory.")
        println(" ")
        println("Example: align_tops.jl s1a-iw3-slc-vv-20150526t014937-20150526t015002-006086-007e23-003 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw3-slc-vv-20150607t014937-20150607t015003-006261-00832e-006 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd ")
        println(" ")
        println("Output: S1_20150526_F3.PRM S1_20150526_F3.LED S1_20150526_F3.SLC S1_20150607_F3.PRM S1_20150607_F3.LED S1_20150607_F3.SLC ")
        println(" ")
        exit(1)
    end
    a1, a2, a3, a4, a5 = argv[1], argv[2], argv[3], argv[4], argv[5]
    #
    #  make sure the files are available
    #
    if !isfile("$a1.xml")
        println("****** missing file: " * a1)
        exit(0)
    end
    if !isfile(a2)
        println("****** missing file: " * a2)
        exit(0)
    end
    if !isfile("$a3.xml")
        println("****** missing file: " * a3)
        exit(0)
    end
    if !isfile(a4)
        println("****** missing file: " * a4)
        exit(0)
    end
    if !isfile(a5)
        println("****** missing file: " * a5)
        exit(0)
    end
    #
    #  set the full names and create an output prefix
    #
    mtiff = "$a1.tiff"
    mxml = "$a1.xml"
    stiff = "$a3.tiff"
    sxml = "$a3.xml"
    mpre = "S1" * substr(a1, 16, 8) * "_" * substr(a1, 25, 6) * "_F" * substr(a1, 7, 1)
    spre = "S1" * substr(a3, 16, 8) * "_" * substr(a3, 25, 6) * "_F" * substr(a3, 7, 1)
    swath = substr(a1, 7, 1)
    println(mpre)
    println(spre)
    #
    #  1) make PRM and LED files for both master and aligned but not the SLC file
    #
    run(`make_s1a_tops_6par $mxml $mtiff $mpre 0 0. 0. 0. 0. 0. 0.`)
    run(`make_s1a_tops_6par $sxml $stiff $spre 0 0. 0. 0. 0. 0. 0.`)
    #
    #  replace the LED with the precise orbit
    #
    run(`ext_orb_s1a $mpre.PRM $a2 $mpre`)
    run(`ext_orb_s1a $spre.PRM $a4 $spre`)
    #
    #  calculate the earth radius and make the aligned match the master
    #
    run(`calc_dop_orb $mpre.PRM tmp 0 0`)
    open("$mpre.PRM", "a") do io
        write(io, read("tmp"))
    end
    earth_radius = grep_field("tmp", "earth_radius")
    run(`calc_dop_orb $spre.PRM tmp2 $earth_radius 0`)
    open("$spre.PRM", "a") do io
        write(io, read("tmp2"))
    end
    rm("tmp"; force=true)
    rm("tmp2"; force=true)
    #
    #  2) do a geometric back projection to determine the alignment parameters
    #
    #  Downsample the topography. The topo value is irrelevant so it can be filtered and downsampled.
    #
    run(`gmt grdfilter $a5 -D2 -Fg4 -I30s -Gflt.grd`)
    open("topo.llt", "w") do io
        run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf flt.grd -s`, stdout=io))
    end
    #
    # zero the alignment parameters of the aligned image
    # don'd change the alignment parameters of the master image in case this is a surrogate master
    #
    run(`update_PRM $spre.PRM rshift 0`)
    run(`update_PRM $spre.PRM sub_int_r 0.0`)
    run(`update_PRM $spre.PRM stretch_r 0.0`)
    run(`update_PRM $spre.PRM a_stretch_r 0.0`)
    run(`update_PRM $spre.PRM ashift 0`)
    run(`update_PRM $spre.PRM sub_int_a 0.0`)
    run(`update_PRM $spre.PRM stretch_a 0.0`)
    run(`update_PRM $spre.PRM a_stretch_a 0.0`)
    #
    # map the topography into the range and azimuth of the master and aligned using polynomial refinement
    #
    open("master.ratll", "w") do io
        run(pipeline(`SAT_llt2rat $mpre.PRM 1`, stdin="topo.llt", stdout=io))
    end
    open("aligned.ratll", "w") do io
        run(pipeline(`SAT_llt2rat $spre.PRM 1`, stdin="topo.llt", stdout=io))
    end
    #
    #  paste the files and compute the dr and da
    #
    #paste master.ratll aligned.ratll | awk '{print( $6, $6-$1, $7, $7-$2, "100")}' > tmp.dat
    m_lines = readlines("master.ratll")
    al_lines = readlines("aligned.ratll")
    open("tmp.dat", "w") do io
        for (ml, al) in zip(m_lines, al_lines)
            mf = split(ml)
            af = split(al)
            m1 = parse(Float64, mf[1])
            a1v = parse(Float64, af[1]); a2v = parse(Float64, af[2])
            @printf(io, "%.6f %.6f %.6f %.6f %d\n", a1v, a1v - m1, a2v, a2v - parse(Float64, mf[2]), 100)
        end
    end
    #
    #  make sure the range and azimuth are within the bounds of the master
    #
    rmax = parse(Float64, grep_field("$spre.PRM", "num_rng_bins"))
    amax = parse(Float64, grep_field("$spre.PRM", "num_lines"))
    open("offset.dat", "w") do io
        for line in eachline("tmp.dat")
            w = split(line)
            v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
            if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                println(io, line)
            end
        end
    end
    #
    #  run fitoffset
    #
    open("$spre.PRM", "a") do io
        run(pipeline(`fitoffset.csh 3 3 offset.dat`, stdout=io))
    end
    #
    #  save the rshift and ashift for the end
    #
    rshift = grep_field_last("$spre.PRM", "rshift")
    ashift = grep_field_last("$spre.PRM", "ashift")
    #
    # clean up the mess
    #
    for f in ["topo.llt", "master.ratll", "aligned.ratll", "tmp.dat", "offset.dat", "flt.grd"]
        rm(f; force=true)
    end
    #
    #  3) make PRM, LED and SLC files for both master and aligned that are aligned
    #     at the fractional pixel level but still need a integer alignment from
    #     resamp
    #
    sub_int_r = grep_field_last("$spre.PRM", "sub_int_r")
    sub_int_a = grep_field_last("$spre.PRM", "sub_int_a")
    stretch_r = grep_field_exclude_last("$spre.PRM", "stretch_r", "a_stretch_r")
    stretch_a = grep_field_exclude_last("$spre.PRM", "stretch_a", "a_stretch_a")
    a_stretch_a = grep_field_last("$spre.PRM", "a_stretch_a")
    a_stretch_r = grep_field_last("$spre.PRM", "a_stretch_r")
    #println(rshift, " ", sub_int_r, " ", stretch_r, " ", a_stretch_r, " ", ashift, " ", sub_int_a, " ", stretch_a, " ", a_stretch_a)
    #
    #  make the new PRM files and SLC
    #
    run(`make_s1a_tops_6par $mxml $mtiff $mpre 1 0. 0. 0. 0. 0. 0.`)
    run(`make_s1a_tops_6par $sxml $stiff $spre 1 $sub_int_r $sub_int_a $stretch_a $a_stretch_a $stretch_r $a_stretch_r`)
    #
    #   restore the integer rshift and ashift
    #
    run(`update_PRM $spre.PRM rshift $rshift`)
    run(`update_PRM $spre.PRM ashift $ashift`)
    #
    #   re-extract the lED files
    #
    run(`ext_orb_s1a $mpre.PRM $a2 $mpre`)
    run(`ext_orb_s1a $spre.PRM $a4 $spre`)
    #
    #  calculate the earth radius and make the aligned match the master
    #
    run(`calc_dop_orb $mpre.PRM tmp 0 0`)
    open("$mpre.PRM", "a") do io
        write(io, read("tmp"))
    end
    earth_radius2 = grep_field("tmp", "earth_radius")
    run(`calc_dop_orb $spre.PRM tmp2 $earth_radius2 0`)
    open("$spre.PRM", "a") do io
        write(io, read("tmp2"))
    end
    rm("tmp"; force=true)
    rm("tmp2"; force=true)
    #
    # do integer resampling of the aligned
    #
    run(`resamp $mpre.PRM $spre.PRM $spre.PRMresamp $spre.SLCresamp 1`)
    mv("$spre.SLCresamp", "$spre.SLC"; force=true)
    mv("$spre.PRMresamp", "$spre.PRM"; force=true)
    #
    for f in readdir(".")
        if f in ("topo.llt", "master.ratll", "aligned.ratll", "flt.grd", "r.xyz", "a.xyz") || occursin("tmp", f)
            rm(f; force=true)
        end
    end
end

main(ARGS)
