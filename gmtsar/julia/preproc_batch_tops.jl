#!/usr/bin/env julia
#       $Id$
#
# Xiaohua(Eric) Xu, Feb 26 2016
# Take previous code, make it work with multiple frames
# Take previous code, make it work with bursts mismatch

# Preprocess and align tops image stacks
# used for time series analysis

# Xiaohua(Eric) Xu, Jan 19 2016
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

"""awk '{ print "S1_"substr(\$1,16,8)"_"substr(\$1,25,6)"_F"substr(\$1,7,1)}'"""
stem_name(name::AbstractString) = "S1_" * substr(name, 16, 8) * "_" * substr(name, 25, 6) * "_F" * substr(name, 7, 1)

"""awk '{ print "S1_"substr(\$1,16,8)"_ALL_F"substr(\$1,7,1)}'"""
mstem_name(name::AbstractString) = "S1_" * substr(name, 16, 8) * "_ALL_F" * substr(name, 7, 1)

"""cat srcs... > dst"""
function cat_files(dst::AbstractString, srcs::Vector{String})
    open(dst, "w") do io
        for s in srcs
            write(io, read(s))
        end
    end
end

"""rm pattern-matching files in cwd by predicate"""
function rm_glob(pred::Function)
    for f in readdir(".")
        if pred(f)
            rm(f; force=true)
        end
    end
end

function main(argv::Vector{String})
    if length(argv) != 3
        println("")
        println("Usage: preproc_batch_tops.csh data.in dem.grd mode")
        println("  preprocess and align a set of tops images in data.in, precise orbits required")
        println("")
        println("  format of data.in:")
        println("    image_name:orbit_name")
        println("")
        println("  example of data.in")
        println("    s1a-iw1-slc-vv-20150626...001:s1a-iw1-slc-vv-20150626...001:s1a-iw1-slc-vv-20150626...001:S1A_OPER_AUX_POEORB_V20150601_20150603.EOF")
        println("    s1a-iw1-slc-vv-20150715...001:s1a-iw1-slc-vv-20150715...001:s1a-iw1-slc-vv-20150715...001:S1A_OPER_AUX_POEORB_V20150625_20150627.EOF")
        println("")
        println("  outputs:")
        println("    baseline.ps (mode 1)")
        println("    *.PRM *.LED *.SLC(mode 2)")
        println("")
        println("  Note:")
        println("    The names must be in time order in each line to be stitched together")
        println("")
        println("Reference: Xu, X., Sandwell, D.T., Tymofyeyeva, E., González-Ortega, A. and Tong, X., ")
        println("    2017. Tectonic and Anthropogenic Deformation at the Cerro Prieto Geothermal ")
        println("    Step-Over Revealed by Sentinel-1A InSAR. IEEE Transactions on Geoscience and ")
        println("    Remote Sensing.")
        exit(1)
    end

    # set up some parameters
    mode = parse(Int, argv[3])
    sl = 1
    local earth_radius

    # sample the dem
    if mode == 2
        run(`gmt grdfilter $(argv[2]) -D2 -Fg2 -I12s -Gflt.grd`)
        run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf flt.grd -s`, stdout="topo.llt"))
    end

    # first line is the super-master, all images aligned to it
    first_field = split(readlines(argv[1])[1], ":")[1]
    master = stem_name(first_field)
    mmaster = mstem_name(first_field)
    # clean up a little bit
    rm_glob(f -> occursin(".PRM", f) || endswith(f, ".SLC") || endswith(f, ".LED") || startswith(f, "tmp"))
    isfile("baseline_table.dat") && rm("baseline_table.dat"; force=true)

    # loop over all the acquisitions
    for line in readlines(argv[1])
        # record the first one as the stem_master
        first_field_line = split(line, ":")[1]
        stem_master = stem_name(first_field_line)
        m_stem_master = mstem_name(first_field_line)
        if mode == 1

            # for mode 1, generate baseline_plots
            image = split(line, ":")[1]
            orbit = split(line, ":")[end]

            # generate prms and leds
            run(`gmt make_s1a_tops -A$image.xml -B$image.tiff -G$m_stem_master -M0`)
            run(`gmt ext_orb_s1a -A$m_stem_master.PRM -B$orbit -G$m_stem_master`)

            # get the height and baseline info
            cp("$m_stem_master.PRM", "junk1"; force=true)
            run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E0 -D0`)
            cat_files("$m_stem_master.PRM", ["junk1", "junk2"])

            run(`gmt update_PRM -A$m_stem_master.PRM -Ninput_file -C$m_stem_master.raw`)
            run(`gmt update_PRM -A$m_stem_master.PRM -NSLC_file -C$m_stem_master.SLC`)
            run(`gmt update_PRM -A$m_stem_master.PRM -Nled_file -C$m_stem_master.LED`)
            #baseline_table.csh $mmaster.PRM $m_stem_master.PRM >> baseline_table.dat
            #baseline_table.csh $mmaster.PRM $m_stem_master.PRM GMT >> table.gmt

            # clean up the mess
            rm("junk1"; force=true)
            rm("junk2"; force=true)
        elseif mode == 2
            # for mode 2, stitch and align all the images

            # find the files to be stitched
            fields_all = split(line, ":")
            open("tmp.filelist", "w") do io
                for f in fields_all[1:end-1]
                    println(io, f)
                end
            end
            orbit = fields_all[end]

            isfile("tmp.stitchlist") && rm("tmp.stitchlist"; force=true)
            tmp_da = 0

            # loop over all the files in this line
            rm_glob(f -> occursin("par", f))
            for file in readlines("tmp.filelist")
                # generate prms and leds
                stem = stem_name(file)

                # get images aligned
                if sl == 1
                    # sl=1 means processing the super_master image, simpley generate images and stitch them together
                    run(`gmt make_s1a_tops -A$file.xml -B$file.tiff -G$stem -M1`)
                    run(`gmt ext_orb_s1a -A$stem.PRM -B$orbit -G$stem`)
                    open("tmp.stitchlist", "a") do io
                        println(io, stem)
                    end
                else
                    # sl>1 measn processing aligned images, point-by-point alignment and corregistration is required
                    run(`gmt make_s1a_tops -A$file.xml -B$file.tiff -G$stem -M0`)
                    run(`gmt ext_orb_s1a -A$stem.PRM -B$orbit -G$stem`)

                    # compute the time difference between first frame and the rest frames
                    t1 = @sprintf("%.13f", parse(Float64, grep_field_exclude("$stem_master.PRM", "clock_start", "SC_clock_start")))
                    t2 = @sprintf("%.13f", parse(Float64, grep_field_exclude("$stem.PRM", "clock_start", "SC_clock_start")))
                    prf = @sprintf("%.6f", parse(Float64, grep_field("$stem_master.PRM", "PRF")))
                    nl = trunc(Int, (parse(Float64, t2) - parse(Float64, t1)) * parse(Float64, prf) * 86400.0 + 0.2)
                    println("Shifting the master PRM by $nl lines...")
                    cp("$master.PRM", "tmp.PRM"; force=true)

                    # shift the super-master's PRM based on $nl so SAT_llt2rat gives precise estimate.
                    ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_start", "SC_clock_start")) + nl / parse(Float64, prf) / 86400.0)
                    run(`gmt update_PRM -Atmp.PRM -Nclock_start -C$ttmp`)
                    ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_stop", "SC_clock_stop")) + nl / parse(Float64, prf) / 86400.0)
                    run(`gmt update_PRM -Atmp.PRM -Nclock_stop -C$ttmp`)
                    ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_start")) + nl / parse(Float64, prf) / 86400.0)
                    run(`gmt update_PRM -Atmp.PRM -NSC_clock_start -C$ttmp`)
                    ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_stop")) + nl / parse(Float64, prf) / 86400.0)
                    run(`gmt update_PRM -Atmp.PRM -NSC_clock_stop -C$ttmp`)

                    # compute whether there are any image offset
                    if tmp_da == 0
                        cp("tmp.PRM", "junk1.PRM"; force=true)
                        cp("$stem.PRM", "junk2.PRM"; force=true)
                        run(`gmt calc_dop_orb -Ajunk1.PRM -Bjunk -E$earth_radius -D0`)
                        open("junk1.PRM", "a") do io
                            write(io, read("junk"))
                        end
                        run(`gmt calc_dop_orb -Ajunk2.PRM -Bjunk -E$earth_radius -D0`)
                        open("junk2.PRM", "a") do io
                            write(io, read("junk"))
                        end
                        lontie = grep_field_cmd(`gmt SAT_baseline -Ajunk1.PRM -Bjunk2.PRM`, "lon_tie_point")
                        lattie = grep_field_cmd(`gmt SAT_baseline -Ajunk1.PRM -Bjunk2.PRM`, "lat_tie_point")
                        tmp_am = parse(Float64, pipe_in_field(`gmt SAT_llt2rat -Atmp.PRM -P1`, "$lontie $lattie 0\n", 2))
                        tmp_as = parse(Float64, pipe_in_field(`gmt SAT_llt2rat -A$stem.PRM -P1`, "$lontie $lattie 0\n", 2))
                        tmp_da = trunc(Int, tmp_as - tmp_am)
                        rm("junk1.PRM"; force=true)
                        rm("junk2.PRM"; force=true)
                        rm("junk"; force=true)
                    end

                    # in case the images are offset by more than a burst, shift the super-master's PRM again so SAT_llt2rat gives precise estimate
                    if tmp_da > -1000 && tmp_da < 1000
                        cp("tmp.PRM", "junk1"; force=true)
                        run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E$earth_radius -D0`)
                        cat_files("tmp.PRM", ["junk1", "junk2"])
                        cp("$stem.PRM", "junk1"; force=true)
                        run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E$earth_radius -D0`)
                        cat_files("$stem.PRM", ["junk1", "junk2"])
                        rm("junk1"; force=true)
                        rm("junk2"; force=true)

                        job1 = run(pipeline(`gmt SAT_llt2rat -Atmp.PRM -P1`, stdin="topo.llt", stdout="tmpm.dat"); wait=false)
                        job2 = run(pipeline(`gmt SAT_llt2rat -A$stem.PRM -P1`, stdin="topo.llt", stdout="tmp1.dat"); wait=false)
                        wait(job1)
                        wait(job2)
                    else
                        println("Modifying master PRM by $tmp_da lines...")
                        prf2 = grep_field("tmp.PRM", "PRF")
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_start", "SC_clock_start")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`gmt update_PRM -Atmp.PRM -Nclock_start -C$ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_stop", "SC_clock_stop")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`gmt update_PRM -Atmp.PRM -Nclock_stop -C$ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_start")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`gmt update_PRM -Atmp.PRM -NSC_clock_start -C$ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_stop")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`gmt update_PRM -Atmp.PRM -NSC_clock_stop -C$ttmp`)

                        cp("tmp.PRM", "junk1"; force=true)
                        run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E$earth_radius -D0`)
                        cat_files("tmp.PRM", ["junk1", "junk2"])
                        cp("$stem.PRM", "junk1"; force=true)
                        run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E$earth_radius -D0`)
                        cat_files("$stem.PRM", ["junk1", "junk2"])
                        rm("junk1"; force=true)
                        rm("junk2"; force=true)

                        job1 = run(pipeline(`gmt SAT_llt2rat -Atmp.PRM -P1`, stdin="topo.llt", stdout="tmpm.dat"); wait=false)
                        job2 = run(pipeline(`gmt SAT_llt2rat -A$stem.PRM -P1`, stdin="topo.llt", stdout="tmp1.dat"); wait=false)
                        wait(job1)
                        wait(job2)
                    end

                    # get r, dr, a, da, SNR table to be used by fitoffset.csh
                    m_lines = readlines("tmpm.dat")
                    al_lines = readlines("tmp1.dat")
                    open("tmp.dat", "w") do io
                        for (ml, al) in zip(m_lines, al_lines)
                            mf = split(ml)
                            af = split(al)
                            m1 = parse(Float64, mf[1]); m2 = parse(Float64, mf[2])
                            a1v = parse(Float64, af[1]); a2v = parse(Float64, af[2])
                            @printf(io, "%.6f %.6f %.6f %.6f %d\n", m1, a1v - m1, m2, a2v - m2, 100)
                        end
                    end
                    rmax = parse(Float64, grep_field("$stem.PRM", "num_rng_bins"))
                    amax = parse(Float64, grep_field("$stem.PRM", "num_lines"))
                    open("offset.dat", "w") do io
                        for line2 in readlines("tmp.dat")
                            w = split(line2)
                            v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
                            if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                                println(io, line2)
                            end
                        end
                    end

                    # prepare the offset parameters for the stitched image
                    open("par_tmp.dat", "a") do io
                        for line2 in readlines("offset.dat")
                            w = split(line2)
                            v1 = parse(Float64, w[1]); v2 = parse(Float64, w[2]); v3 = parse(Float64, w[3])
                            v4 = parse(Float64, w[4]); v5 = parse(Float64, w[5])
                            if tmp_da > -1000 && tmp_da < 1000
                                @printf(io, "%.6f %.6f %.6f %.6f %d\n", v1, v2, v3 + nl, v4, round(Int, v5))
                            else
                                @printf(io, "%.6f %.6f %.6f %.6f %d\n", v1, v2, v3 + nl - tmp_da, v4 + tmp_da, round(Int, v5))
                            end
                        end
                    end

                    # prepare the rshift and ashift look up table to be used by make_s1a_tops
                    open("r.xyz", "w") do io
                        for line2 in readlines("offset.dat")
                            w = split(line2)
                            @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[2]))
                        end
                    end
                    open("a.xyz", "w") do io
                        for line2 in readlines("offset.dat")
                            w = split(line2)
                            @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[4]))
                        end
                    end
                    run(pipeline(`gmt blockmedian r.xyz -R0/$rmax/0/$amax -I8/4 -r -bo3d`, stdout="rtmp.xyz"))
                    run(pipeline(`gmt blockmedian a.xyz -R0/$rmax/0/$amax -I8/4 -r -bo3d`, stdout="atmp.xyz"))
                    job1 = run(`gmt surface rtmp.xyz -bi3d -R0/$rmax/0/$amax -I8/4 -Grtmp.grd -T0.5 -N1000 -r`; wait=false)
                    job2 = run(`gmt surface atmp.xyz -bi3d -R0/$rmax/0/$amax -I8/4 -Gatmp.grd -T0.5 -N1000 -r`; wait=false)
                    wait(job1)
                    wait(job2)
                    run(`gmt grdmath rtmp.grd FLIPUD = r.grd`)
                    run(`gmt grdmath atmp.grd FLIPUD = a.grd`)

                    # generate the image with point-by-point shifts
                    run(`gmt make_s1a_tops -A$file.xml -B$file.tiff -G$stem -M1 -Cr.grd -Da.grd`)

                    # need to update shift parameter so stitch_tops will know how to stitch
                    open("$stem.PRM", "a") do io
                        run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 offset.dat`, stdout=io))
                    end
                    #fitoffset.csh 1 1 offset.dat >> $stem.PRM

                    open("tmp.stitchlist", "a") do io
                        println(io, stem)
                    end
                end
            end

            nf = length(readlines("tmp.stitchlist"))
            # get the name for stitched file
            stem = mstem_name(first_field_line)

            # stitch images together and get the precise orbit
            if nf > 1
                run(`gmt stitch_tops -Atmp.stitchlist -G$stem`)
            else
                tmp_stem = strip(read("tmp.stitchlist", String))
                cp("$tmp_stem.PRM", "$stem.PRM"; force=true)
                cp("$tmp_stem.LED", "$stem.LED"; force=true)
                mv("$tmp_stem.SLC", "$stem.SLC"; force=true)

                run(`gmt update_PRM -A$stem.PRM -Ninput_file -C$stem.raw`)
                run(`gmt update_PRM -A$stem.PRM -NSLC_file -C$stem.SLC`)
                run(`gmt update_PRM -A$stem.PRM -Nled_file -C$stem.LED`)
            end
            run(`gmt ext_orb_s1a -A$stem.PRM -B$orbit -G$stem`)

            # for images except the super-master
            if sl != 1
                cp("$stem.PRM", "$stem.PRM0"; force=true)
                #if ($bshift != 0) echo "Updated shift caused by burst offset is $bshift"
                if tmp_da > -1000 && tmp_da < 1000
                    run(`gmt update_PRM -A$stem.PRM -Nashift -C0`)
                else
                    run(`gmt update_PRM -A$stem.PRM -Nashift -C$tmp_da`)
                    println("Restoring $tmp_da lines shift to the image...")
                end
                run(`gmt update_PRM -A$stem.PRM -Nrshift -C0`)

                run(`gmt resamp -A$mmaster.PRM -B$stem.PRM -G$stem.PRMresamp -S$stem.SLCresamp -I1`)
                mv("$stem.PRMresamp", "$stem.PRM"; force=true)
                mv("$stem.SLCresamp", "$stem.SLC"; force=true)

                open("$stem.PRM", "a") do io
                    run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 par_tmp.dat`, stdout=io))
                end
            end

            cp("$stem.PRM", "junk1"; force=true)
            if sl == 1
                run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E0 -D0`)
                earth_radius = grep_field("junk2", "earth_radius")
            else
                run(`gmt calc_dop_orb -Ajunk1 -Bjunk2 -E$earth_radius -D0`)
            end
            cat_files("$stem.PRM", ["junk1", "junk2"])
            rm("junk1"; force=true)
            rm("junk2"; force=true)
            sl = 2
        end
    end

    # create baseline table
    open("prmlist", "w") do io
        for f in sort(filter(f -> occursin("ALL", f) && endswith(f, "PRM"), readdir(".")))
            println(io, f)
        end
    end
    for prm_aligned in readlines("prmlist")
        open("baseline_table.dat", "a") do io
            run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("baseline_table")) $mmaster.PRM $prm_aligned`, stdout=io))
        end
        open("table.gmt", "a") do io
            run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("baseline_table")) $mmaster.PRM $prm_aligned GMT`, stdout=io))
        end
    end

    # for mode 1, plot the time-baseline figure
    if mode == 1
        open("text", "w") do io
            for line2 in readlines("table.gmt")
                w = split(line2)
                year = 2014 + parse(Float64, w[1]) / 365.25
                println(io, "$(@sprintf("%.6g", year)) $(w[2]) $(w[7])")
            end
        end
        info = split(strip(read(`gmt gmtinfo text -C`, String)))
        region = [
            @sprintf("%.6g", parse(Float64, info[1]) - 0.5),
            @sprintf("%.6g", parse(Float64, info[2]) + 0.5),
            @sprintf("%.6g", parse(Float64, info[3]) - 50),
            @sprintf("%.6g", parse(Float64, info[4]) + 50),
        ]
        run(pipeline(`gmt pstext text -JX8.8i/6.8i -R$(region[1])/$(region[2])/$(region[3])/$(region[4]) -D0.2/0.2 -X1.5i -Y1i -K -N -F+f8,Helvetica+j5`, stdout="baseline.ps"))
        open("text2", "w") do io
            for line2 in readlines("text")
                w = split(line2)
                println(io, "$(w[1]) $(w[2])")
            end
        end
        open("baseline.ps", "a") do io
            run(pipeline(`gmt psxy text2 -Sp0.2c -G0 -R -JX -Ba0.5:"year":/a50g00f25:"baseline (m)":WSen -O`, stdout=io))
        end
        rm("text"; force=true)
        rm("text2"; force=true)
        rm("table.gmt"; force=true)
        run(`gmt psconvert baseline.ps -Tf -A`)
        rm("baseline.ps"; force=true)
    end

    # clean up a little bit
    if mode == 2
        rm_glob(f -> startswith(f, "tmp") || f == "topo.llt" || f == "flt.grd" || startswith(f, "atmp") || startswith(f, "rtmp"))
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
