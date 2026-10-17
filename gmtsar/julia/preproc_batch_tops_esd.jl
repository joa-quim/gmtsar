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

"""sort -n file | awk '{a[i++]=\$1} END{print a[int(i/2)]}'"""
function median_awk(file::AbstractString)
    vals = sort(parse.(Float64, readlines(file)))
    n = length(vals)
    return vals[fld(n, 2) + 1]
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

"""awk 'NR == N {print \$0}' < file  -- Nth line (1-indexed), "" if out of range"""
function nth_line_or_empty(file::AbstractString, n::Int)
    n < 1 && return ""
    lines = readlines(file)
    (n > length(lines)) && return ""
    return lines[n]
end

function main(argv::Vector{String})
    if length(argv) != 4
        println("")
        println("Usage: preproc_batch_tops_esd.csh data.in dem.grd mode esd_mode")
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
        println("  esd_mode:")
        println("    0 for average, 1 for median, 2 for interpolation")
        println("")
        println("  Note:")
        println("    The names must be in time order in each line to be stitched together")
        println("")
        exit(1)
    end

    # set up some parameters
    mode = parse(Int, argv[3])
    esd = parse(Int, argv[4])
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
    rm_glob(f -> occursin(".PRM", f) || endswith(f, ".SLC") || endswith(f, ".LED") || occursin("tmp", f))
    isfile("baseline_table.dat") && rm("baseline_table.dat"; force=true)
    isfile("masterlist") && rm("masterlist"; force=true)
    sharedir = strip(read(`$GMTSAR_JULIA $(gmtsar_script("gmtsar_sharedir"))`, String))

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
            run(`make_s1a_tops $image.xml $image.tiff $m_stem_master 0`)
            run(`ext_orb_s1a $m_stem_master.PRM $orbit $m_stem_master`)

            # get the height and baseline info
            cp("$m_stem_master.PRM", "junk1"; force=true)
            run(`calc_dop_orb junk1 junk2 0 0`)
            cat_files("$m_stem_master.PRM", ["junk1", "junk2"])

            run(`update_PRM $m_stem_master.PRM input_file $m_stem_master.raw`)
            run(`update_PRM $m_stem_master.PRM SLC_file $m_stem_master.SLC`)
            run(`update_PRM $m_stem_master.PRM led_file $m_stem_master.LED`)
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
            count = 0
            for file in readlines("tmp.filelist")
                # generate prms and leds
                count += 1
                stem = stem_name(file)

                # get images aligned
                if sl == 1
                    # sl=1 means processing the super_master image, simpley generate images and stitch them together
                    run(`make_s1a_tops $file.xml $file.tiff $stem 1`)
                    run(`make_s1a_tops $file.xml $file.tiff $stem 2`)
                    run(`ext_orb_s1a $stem.PRM $orbit $stem`)
                    open("masterlist", "a") do io
                        println(io, stem)
                    end
                    open("tmp.stitchlist", "a") do io
                        println(io, stem)
                    end
                else
                    # sl>1 measn processing aligned images, point-by-point alignment and corregistration is required
                    run(`make_s1a_tops $file.xml $file.tiff $stem 0`)
                    run(`ext_orb_s1a $stem.PRM $orbit $stem`)

                    # compute the time difference between first frame and the rest frames
                    tmp_master = nth_line_or_empty("masterlist", count)
                    tmp_master == "" && (tmp_master = nth_line_or_empty("masterlist", count - 1))
                    tmp_master == "" && (tmp_master = nth_line_or_empty("masterlist", count - 2))

                    cp("$tmp_master.PRM", "tmp.PRM"; force=true)
                    t1 = @sprintf("%.13f", parse(Float64, grep_field_exclude("$master.PRM", "clock_start", "SC_clock_start")))
                    t2 = @sprintf("%.13f", parse(Float64, grep_field_exclude("$tmp_master.PRM", "clock_start", "SC_clock_start")))
                    prf = @sprintf("%.6f", parse(Float64, grep_field("$master.PRM", "PRF")))
                    nl = trunc(Int, (parse(Float64, t2) - parse(Float64, t1)) * parse(Float64, prf) * 86400.0 + 0.2)

                    # compute whether there are any image offset
                    if tmp_da == 0
                        cp("tmp.PRM", "junk1.PRM"; force=true)
                        cp("$stem.PRM", "junk2.PRM"; force=true)
                        run(`calc_dop_orb junk1.PRM junk $earth_radius 0`)
                        open("junk1.PRM", "a") do io
                            write(io, read("junk"))
                        end
                        run(`calc_dop_orb junk2.PRM junk $earth_radius 0`)
                        open("junk2.PRM", "a") do io
                            write(io, read("junk"))
                        end
                        lontie = grep_field_cmd(`SAT_baseline junk1.PRM junk2.PRM`, "lon_tie_point")
                        lattie = grep_field_cmd(`SAT_baseline junk1.PRM junk2.PRM`, "lat_tie_point")
                        tmp_am = parse(Float64, pipe_in_field(`SAT_llt2rat tmp.PRM 1`, "$lontie $lattie 0\n", 2))
                        tmp_as = parse(Float64, pipe_in_field(`SAT_llt2rat $stem.PRM 1`, "$lontie $lattie 0\n", 2))
                        tmp_da = trunc(Int, tmp_as - tmp_am)
                        rm("junk1.PRM"; force=true)
                        rm("junk2.PRM"; force=true)
                        rm("junk"; force=true)
                    end

                    # in case the images are offset by more than a burst, shift the super-master's PRM again so SAT_llt2rat gives precise estimate
                    if tmp_da > -1000 && tmp_da < 1000
                        cp("tmp.PRM", "junk1"; force=true)
                        run(`calc_dop_orb junk1 junk2 $earth_radius 0`)
                        cat_files("tmp.PRM", ["junk1", "junk2"])
                        cp("$stem.PRM", "junk1"; force=true)
                        run(`calc_dop_orb junk1 junk2 $earth_radius 0`)
                        cat_files("$stem.PRM", ["junk1", "junk2"])
                        rm("junk1"; force=true)
                        rm("junk2"; force=true)

                        job1 = run(pipeline(`SAT_llt2rat tmp.PRM 1`, stdin="topo.llt", stdout="tmpm.dat"); wait=false)
                        job2 = run(pipeline(`SAT_llt2rat $stem.PRM 1`, stdin="topo.llt", stdout="tmp1.dat"); wait=false)
                        wait(job1)
                        wait(job2)
                    else
                        println("Modifying master PRM by $tmp_da lines...")
                        prf2 = grep_field("tmp.PRM", "PRF")
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_start", "SC_clock_start")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`update_PRM tmp.PRM clock_start $ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field_exclude("tmp.PRM", "clock_stop", "SC_clock_stop")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`update_PRM tmp.PRM clock_stop $ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_start")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`update_PRM tmp.PRM SC_clock_start $ttmp`)
                        ttmp = @sprintf("%.12f", parse(Float64, grep_field("tmp.PRM", "SC_clock_stop")) - tmp_da / parse(Float64, prf2) / 86400.0)
                        run(`update_PRM tmp.PRM SC_clock_stop $ttmp`)

                        cp("tmp.PRM", "junk1"; force=true)
                        run(`calc_dop_orb junk1 junk2 $earth_radius 0`)
                        cat_files("tmp.PRM", ["junk1", "junk2"])
                        cp("$stem.PRM", "junk1"; force=true)
                        run(`calc_dop_orb junk1 junk2 $earth_radius 0`)
                        cat_files("$stem.PRM", ["junk1", "junk2"])
                        rm("junk1"; force=true)
                        rm("junk2"; force=true)

                        #SAT_llt2rat tmp.PRM 1 < topo.llt > tmp_tmp.dat &
                        job1 = run(pipeline(`SAT_llt2rat tmp.PRM 1`, stdin="topo.llt", stdout="tmpm.dat"); wait=false)
                        job2 = run(pipeline(`SAT_llt2rat $stem.PRM 1`, stdin="topo.llt", stdout="tmp1.dat"); wait=false)
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
                    run(`make_s1a_tops $file.xml $file.tiff $stem 2 r.grd a.grd`)

                    if tmp_da > -1000 && tmp_da < 1000
                        run(pipeline(`spectral_diversity $tmp_master $stem 0 $sharedir/filters/gauss25x7`, stdout="tmp"))
                    else
                        run(pipeline(`spectral_diversity $tmp_master $stem $tmp_da $sharedir/filters/gauss25x7`, stdout="tmp"))
                    end

                    spec_sep = parse(Float64, grep_field("tmp", "spectral_spectrationXdta"))
                    open("tmp2", "w") do io
                        for line2 in readlines("ddphase")
                            w = split(line2)
                            println(io, w[3])
                        end
                    end

                    if esd == 2
                        res_shift = median_awk("tmp2") / 2.0 / 3.141592653 / spec_sep
                        println("Updating azimuth shift with mapping the residual da ...(mapping $res_shift)")
                        open("test", "w") do io
                            for line2 in readlines("ddphase")
                                w = split(line2)
                                println(io, "$(w[1]) $(w[2]) $(w[3])")
                            end
                        end
                        rmax2 = rmax + 1000
                        amax2 = amax + 1000
                        run(pipeline(`gmt blockmedian test -R-1000/$rmax2/-1000/$amax2 -I400/100`, `gmt greenspline -Gtest.grd -R-1000/$rmax2/-1000/$amax2 -I400/100 -D1 -Cn900 -r -V`))
                        run(`gmt grdfilter test.grd -D0 -Fg8000/1500 -Gtest2.grd -V`)
                        run(`gmt grdsample test2.grd -Gtest_b.grd -Ra.grd -nc`)

                        run(`gmt grdmath test_b.grd FLIPUD $spec_sep DIV 2 PI MUL DIV = res_shift.grd`)
                        run(`gmt grdmath a.grd res_shift.grd ADD = tmp.grd`)
                        mv("tmp.grd", "a.grd"; force=true)
                        mv("tmp", "spec_div_output"; force=true)
                        rm_glob(f -> startswith(f, "test"))
                    else
                        local res_shift
                        if esd == 1
                            res_shift = median_awk("tmp2") / 2.0 / 3.141592653 / spec_sep
                        else
                            res_shift = parse(Float64, grep_field("tmp", "residual_shift"))
                        end
                        println("Updating azimuth shift with a constant...(medain $res_shift)")
                        run(`gmt grdmath a.grd $res_shift ADD = tmp.grd`)
                        mv("tmp.grd", "a.grd"; force=true)
                    end

                    #set res_shift = `sort -n tmp2 | awk ' { a[i++]=$1; } END { print a[int(i/2)]; }' | awk '{print $1/2.0/3.141592653/'$spec_sep'}'`

                    #echo "Updating ashift table with spectral diversity estimate ($res_shift)..."
                    #gmt grdmath a.grd $res_shift ADD = tmp.grd
                    #mv tmp.grd a.grd

                    run(`make_s1a_tops $file.xml $file.tiff $stem 1 r.grd a.grd`)

                    mv("r.grd", "$(stem)_r.grd"; force=true)
                    mv("a.grd", "$(stem)_a.grd"; force=true)

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
                run(`stitch_tops tmp.stitchlist $stem`)
            else
                tmp_stem = strip(read("tmp.stitchlist", String))
                cp("$tmp_stem.PRM", "$stem.PRM"; force=true)
                cp("$tmp_stem.LED", "$stem.LED"; force=true)
                mv("$tmp_stem.SLC", "$stem.SLC"; force=true)

                run(`update_PRM $stem.PRM input_file $stem.raw`)
                run(`update_PRM $stem.PRM SLC_file $stem.SLC`)
                run(`update_PRM $stem.PRM led_file $stem.LED`)
            end
            run(`ext_orb_s1a $stem.PRM $orbit $stem`)

            # for images except the super-master
            if sl != 1
                cp("$stem.PRM", "$stem.PRM0"; force=true)
                #if ($bshift != 0) echo "Updated shift caused by burst offset is $bshift"
                if tmp_da > -1000 && tmp_da < 1000
                    run(`update_PRM $stem.PRM ashift 0`)
                else
                    run(`update_PRM $stem.PRM ashift $tmp_da`)
                    println("Restoring $tmp_da lines shift to the image...")
                end
                run(`update_PRM $stem.PRM rshift 0`)

                run(`resamp $mmaster.PRM $stem.PRM $stem.PRMresamp $stem.SLCresamp 1`)
                mv("$stem.PRMresamp", "$stem.PRM"; force=true)
                mv("$stem.SLCresamp", "$stem.SLC"; force=true)

                open("$stem.PRM", "a") do io
                    run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 par_tmp.dat`, stdout=io))
                end
            end

            cp("$stem.PRM", "junk1"; force=true)
            if sl == 1
                run(`calc_dop_orb junk1 junk2 0 0`)
                earth_radius = grep_field("junk2", "earth_radius")
            else
                run(`calc_dop_orb junk1 junk2 $earth_radius 0`)
            end
            cat_files("$stem.PRM", ["junk1", "junk2"])
            rm("junk1"; force=true)
            rm("junk2"; force=true)
            sl += 1
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
        rm_glob(f -> startswith(f, "tmp") || f == "topo.llt" || f == "flt.grd" || startswith(f, "atmp") ||
                     startswith(f, "rtmp") || endswith(f, "SLCL") || endswith(f, "SLCH") || endswith(f, "BB"))
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
