#!/usr/bin/env julia
#       $Id$
# Xiaohua Xu and David Sandwell Dec 23 2015
#
#  script to align S1 TOPS mode data
#
#  1) Make PRM and LED files for both master and aligned.
#
#  2) Do geometric back geocoding to make the range and azimuth alignment grids
#
#  3) Make PRM, LED and SLC files for both master and aligned that are aligned
#     at the fractional pixel level.
#
# alias rm 'rm -f'
# unset noclobber
#
include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

using Printf

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | grep -v EXCLUDE | awk '{print \$3}'  -- first matching (excluding) line's 3rd field"""
function grep_field_exclude(file::AbstractString, pattern::AbstractString, exclude::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line) && !occursin(exclude, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern (excluding $exclude) in $file")
end

"""cmd | grep PATTERN | awk '{print \$3}'  -- run cmd, 3rd field of first matching output line"""
function grep_field_cmd(cmd::Cmd, pattern::AbstractString)
    out = read(cmd, String)
    for line in split(out, '\n')
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern in output of $cmd")
end

"""echo INPUT | cmd | awk '{print \$N}'  -- feed INPUT as stdin, return Nth field of first output line"""
function pipe_in_field(cmd::Cmd, input::AbstractString, n::Int)
    out = read(pipeline(cmd, stdin=IOBuffer(input)), String)
    for line in split(out, '\n')
        w = split(line)
        if length(w) >= n
            return w[n]
        end
    end
    error("no output line with $n fields from $cmd")
end

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    if length(argv) != 5 && length(argv) != 6
        println(" ")
        println("Usage: align_tops.jl master_prefix master_orb_file aligned_s1a_prefix aligned_orb_file dem.grd [run_with_a/r_ready]")
        println(" ")
        println("Be sure the tiff, xml, orbit and dem files are available in the local directory.")
        println(" ")
        println("To pre-process master only, use 0 to replace aligned orbit file. To skip master images and process aligned images, use 0 to replace master orbit file")
        println(" ")
        println("Example: align_tops.jl s1a-iw3-slc-vv-20150526t014937-20150526t015002-006086-007e23-003 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw3-slc-vv-20150607t014937-20150607t015003-006261-00832e-006 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd ")
        println(" ")
        println("Output: S1_20150526_F3.PRM S1_20150526_F3.LED S1_20150526_F3.SLC S1_20150607_F3.PRM S1_20150607_F3.LED S1_20150607_F3.SLC ")
        println(" ")
        exit(1)
    end
    p1, p2, p3, p4, p5 = argv[1], argv[2], argv[3], argv[4], argv[5]
    #
    #  make sure the files are available
    #
    if p2 != "0" && !isfile("$p1.xml")
        println("****** missing file: " * p1)
        exit(0)
    end
    if p2 != "0" && !isfile(p2)
        println("****** missing file: " * p2)
        exit(0)
    end
    if p4 != "0" && !isfile("$p3.xml")
        println("****** missing file: " * p3)
        exit(0)
    end
    if p4 != "0" && !isfile(p4)
        println("****** missing file: " * p4)
        exit(0)
    end
    if !isfile(p5)
        println("****** missing file: " * p5)
        exit(0)
    end

    mode = length(argv) == 6 ? 1 : 0

    local skip_master
    if p2 == "0"
        skip_master = 1
    elseif p4 == "0"
        skip_master = 2
    elseif p2 != "0" && p4 != "0"
        skip_master = 0
    else
        println("[ERROR]: Wrong input syntax, chose proper input image names ")
        exit(1)
    end

    #
    #  set the full names and create an output prefix
    #
    mtiff = "$p1.tiff"
    mxml = "$p1.xml"
    stiff = "$p3.tiff"
    sxml = "$p3.xml"
    mpre = "S1_" * substr(p1, 16, 8) * "_" * substr(p1, 25, 6) * "_F" * substr(p1, 7, 1)
    spre = "S1_" * substr(p3, 16, 8) * "_" * substr(p3, 25, 6) * "_F" * substr(p3, 7, 1)
    if skip_master == 0 || skip_master == 2
        println(mpre)
    end
    if skip_master == 0 || skip_master == 1
        println(spre)
    end

    #
    #  1) make PRM and LED files for both master and aligned but not the SLC file
    #
    if skip_master == 2
        run(`make_s1a_tops $mxml $mtiff $mpre 1`)
        run(`ext_orb_s1a $mpre.PRM $p2 $mpre`)
        run(`calc_dop_orb $mpre.PRM tmp 0 0`)
        open("$mpre.PRM", "a") do io
            write(io, read("tmp"))
        end
        rm("tmp"; force=true)
        #update_PRM $mpre".PRM" input_file $mpre".raw"
    else
        if skip_master == 0
            run(`make_s1a_tops $mxml $mtiff $mpre 0`)
        end
        run(`make_s1a_tops $sxml $stiff $spre 0`)
        #
        #  replace the LED with the precise orbit
        #
        if skip_master == 0
            run(`ext_orb_s1a $mpre.PRM $p2 $mpre`)
            # calculate the earth radius and make the aligned match the master
            run(`calc_dop_orb $mpre.PRM tmp 0 0`)
            open("$mpre.PRM", "a") do io
                write(io, read("tmp"))
            end
            rm("tmp"; force=true)
        end
        run(`ext_orb_s1a $spre.PRM $p4 $spre`)
        # calculate the earth radius and make the aligned match the master
        earth_radius = grep_field("$mpre.PRM", "earth_radius")
        run(`calc_dop_orb $spre.PRM tmp2 $earth_radius 0`)
        open("$spre.PRM", "a") do io
            write(io, read("tmp2"))
        end
        rm("tmp2"; force=true)
        #
        #  2) do a geometric back projection to determine the alignment parameters
        #
        #  Filter and downsample the topography to 12 seconds or about 360 m
        #
        if mode == 0
            run(`gmt grdfilter $p5 -D3 -Fg2 -I12s -Ni -Gflt.grd`)
            run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf flt.grd -s`, stdout="topo.llt"))
            #
            # map the topography into the range and azimuth of the master and aligned using polynomial refinement
            # can do this in parallel
            #
            # first check whether there are any burst shift
            #
        end
        lontie = grep_field_cmd(`SAT_baseline $mpre.PRM $spre.PRM`, "lon_tie_point")
        lattie = grep_field_cmd(`SAT_baseline $mpre.PRM $spre.PRM`, "lat_tie_point")
        tmp_am = parse(Float64, pipe_in_field(`SAT_llt2rat $mpre.PRM 1`, "$lontie $lattie 0\n", 2))
        tmp_as = parse(Float64, pipe_in_field(`SAT_llt2rat $spre.PRM 1`, "$lontie $lattie 0\n", 2))
        tmp_da = trunc(Int, tmp_as - tmp_am)
        #
        # if ther is, modify the master PRM start_time to get a better r/a estimate
        #
        if mode == 0
            if tmp_da > -1000 && tmp_da < 1000
                job1 = run(pipeline(`SAT_llt2rat $mpre.PRM 1`, stdin="topo.llt", stdout="master.ratll"); wait=false)
                job2 = run(pipeline(`SAT_llt2rat $spre.PRM 1`, stdin="topo.llt", stdout="aligned.ratll"); wait=false)
                wait(job1); wait(job2)
            else
                println("Modifying master PRM by $tmp_da lines...")
                cp("$mpre.PRM", "tmp.PRM"; force=true)
                prf = parse(Float64, grep_field("tmp.PRM", "PRF"))
                ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_start", "SC_clock_start")) - tmp_da / prf / 86400.0)
                run(`update_PRM tmp.PRM clock_start $ttmp`)
                ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_stop", "SC_clock_stop")) - tmp_da / prf / 86400.0)
                run(`update_PRM tmp.PRM clock_stop $ttmp`)
                ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_start")) - tmp_da / prf / 86400.0)
                run(`update_PRM tmp.PRM SC_clock_start $ttmp`)
                ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_stop")) - tmp_da / prf / 86400.0)
                run(`update_PRM tmp.PRM SC_clock_stop $ttmp`)
                #
                #  restore the modified lines
                #
                #SAT_llt2rat tmp.PRM 1 < topo.llt > tmp.ratll &
                job1 = run(pipeline(`SAT_llt2rat tmp.PRM 1`, stdin="topo.llt", stdout="master.ratll"); wait=false)
                job2 = run(pipeline(`SAT_llt2rat $spre.PRM 1`, stdin="topo.llt", stdout="aligned.ratll"); wait=false)
                wait(job1); wait(job2)
                #echo "Restoring $tmp_da lines to master ashifts..."
                #awk '{printf("%.6f %.6f %.6f %.6f %.6f\n",$1,$2-'$tmp_da',$3,$4,$5)}' tmp.ratll > master.ratll
            end
            #
            #  paste the files and compute the dr and da
            #
            #paste master.ratll aligned.ratll | awk '{printf("%.6f %.6f %.6f %.6f %d\n", $6, $6-$1, $7, $7-$2, "100")}' > tmp.dat
            m_lines = readlines("master.ratll")
            al_lines = readlines("aligned.ratll")
            open("tmp.dat", "w") do io
                for (ml, al) in zip(m_lines, al_lines)
                    mf = split(ml)
                    af = split(al)
                    m1 = parse(Float64, mf[1]); m2 = parse(Float64, mf[2])
                    a1v = parse(Float64, af[1]); a2v = parse(Float64, af[2])
                    @printf(io, "%.6f %.6f %.6f %.6f %d\n", m1, a1v - m1, m2, a2v - m2, 100)
                end
            end
            #
            #  make sure the range and azimuth are within the bounds of the aligned
            #
            rmax = parse(Float64, grep_field("$spre.PRM", "num_rng_bins"))
            amax = parse(Float64, grep_field("$spre.PRM", "num_lines"))
            tmp_lines = readlines("tmp.dat")
            if tmp_da > -1000 && tmp_da < 1000
                open("offset.dat", "w") do io
                    for line in tmp_lines
                        w = split(line)
                        v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
                        if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                            println(io, line)
                        end
                    end
                end
            else
                open("offset.dat", "w") do io
                    for line in tmp_lines
                        w = split(line)
                        v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
                        if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                            println(io, line)
                        end
                    end
                end
                open("offset2.dat", "w") do io
                    for line in tmp_lines
                        w = split(line)
                        v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
                        if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                            v2 = parse(Float64, w[2]); v4 = parse(Float64, w[4])
                            @printf(io, "%.6f %.6f %.6f %.6f %d\n", v1, v2, v3 - tmp_da, v4 + tmp_da, 100)
                        end
                    end
                end
            end
            #
            #  extract the range and azimuth data
            #
            open("r.xyz", "w") do io
                for line in readlines("offset.dat")
                    w = split(line)
                    @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[2]))
                end
            end
            open("a.xyz", "w") do io
                for line in readlines("offset.dat")
                    w = split(line)
                    @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[4]))
                end
            end

            #
            #  fit a surface to the range and azimuth offsets
            #
            run(pipeline(`gmt blockmedian r.xyz -R0/$rmax/0/$amax -I16/8 -r -bo3d`, stdout="rtmp.xyz"))
            run(pipeline(`gmt blockmedian a.xyz -R0/$rmax/0/$amax -I16/8 -r -bo3d`, stdout="atmp.xyz"))
            job1 = run(`gmt surface rtmp.xyz -bi3d -R0/$rmax/0/$amax -I16/8 -T0.3 -Grtmp.grd -N1000 -r`; wait=false)
            job2 = run(`gmt surface atmp.xyz -bi3d -R0/$rmax/0/$amax -I16/8 -T0.3 -Gatmp.grd -N1000 -r`; wait=false)
            wait(job1); wait(job2)
            run(`gmt grdmath rtmp.grd FLIPUD = r.grd`)
            run(`gmt grdmath atmp.grd FLIPUD = a.grd`)
            #
        end
        #  3) make PRM, LED and SLC files for both master and aligned that are aligned
        #     at the fractional pixel level but still need a integer alignment from
        #     resamp
        #
        #  make the new PRM files and SLC
        #
        if skip_master == 0
            run(`make_s1a_tops $mxml $mtiff $mpre 1`)
        end
        run(`make_s1a_tops $sxml $stiff $spre 1 r.grd a.grd`)
        #
        #  resamp the aligned and set the aoffset to zero
        #
        cp("$spre.PRM", "$spre.PRM0"; force=true)
        if tmp_da > -1000 && tmp_da < 1000
            run(`update_PRM $spre.PRM ashift 0`)
        else
            run(`update_PRM $spre.PRM ashift $tmp_da`)
            println("Restoring $tmp_da lines with resamp...")
        end
        run(`resamp $mpre.PRM $spre.PRM $spre.PRMresamp $spre.SLCresamp 1`)
        mv("$spre.SLCresamp", "$spre.SLC"; force=true)
        mv("$spre.PRMresamp", "$spre.PRM"; force=true)
        #
        if tmp_da > -1000 && tmp_da < 1000
            open("$spre.PRM", "a") do io
                run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 offset.dat`, stdout=io))
            end
        else
            open("$spre.PRM", "a") do io
                run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 offset2.dat`, stdout=io))
            end
        end
        #
        #   re-extract the lED files
        #
        if skip_master == 0
            run(`ext_orb_s1a $mpre.PRM $p2 $mpre`)
        end
        run(`ext_orb_s1a $spre.PRM $p4 $spre`)
        #
        #  calculate the earth radius and make the aligned match the master
        #
        if skip_master == 0
            run(`calc_dop_orb $mpre.PRM tmp 0 0`)
            open("$mpre.PRM", "a") do io
                write(io, read("tmp"))
            end
            rm("tmp"; force=true)
            #update_PRM $mpre".PRM" input_file $mpre".raw"
        end
        earth_radius2 = grep_field("$mpre.PRM", "earth_radius")
        run(`calc_dop_orb $spre.PRM tmp2 $earth_radius2 0`)
        open("$spre.PRM", "a") do io
            write(io, read("tmp2"))
        end
        rm("tmp2"; force=true)
        #update_PRM $spre".PRM" input_file $spre".raw"
        #
        for f in readdir(".")
            if f in ("topo.llt", "master.ratll", "aligned.ratll", "flt.grd", "r.xyz", "a.xyz") ||
               occursin("tmp", f) || endswith(f, ".PRM0")
                rm(f; force=true)
            end
        end
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
