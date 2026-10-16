#!/usr/bin/env julia
#       $Id$

# Align RAW or SLC images using orbits and DEM
# by Kang Wang in June. 2018
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

"""cat srcs... > dst"""
function cat_files(dst::AbstractString, srcs::Vector{String})
    open(dst, "w") do io
        for s in srcs
            write(io, read(s))
        end
    end
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
        println()
        println("Usage: align_batch_geometry.jl data_type(RAW/SLC) secondary_align(0/1) data.in")
        println()
        println("       align a set of images to a common master using geometric alignment ")
        println("       used the precise orbit and a dem")
        println("       run this at the top level directory")
        println("       it will create a new SLC directory ")
        println()
        println("  format of data.in is the same as data.in in used in pre_proc_batch.csh:")
        println("       format of data.in is:")
        println("         line 1: master_name ")
        println("         line 2 and below: aligned_name")
        println()
        println("       example of data.in for ALOS is:")
        println("         IMG-HH-ALPSRP096010650-H1.0__A")
        println("         IMG-HH-ALPSRP089300650-H1.0__A")
        println("         IMG-HH-ALPSRP236920650-H1.0__A")
        println()
        println("       example of data.in for ERS is:")
        println("         e1_05783")
        println("         e1_07787")
        println("         e1_10292")
        println()
        println("       example of data.in for ENVISAT is:")
        println("         ENV1_2_127_2925_07195")
        println("         ENV1_2_127_2925_12706")
        println("         ENV1_2_127_2925_13207")
        println()
        println("       example of data.in for ENVI_SLC is:")
        println("         ASA_IMS_1PNESA20030908_175832_000000182019_00399_07968_0000")
        println("         ASA_IMS_1PNESA20040719_175832_000000182028_00399_12477_0000")
        println("         ASA_IMS_1PNESA20051121_175837_000000172042_00399_19491_0000")
        println()
        println("Example: align_batch_geometry.jl RAW 1 data.in")
        println()
        exit(1)
    end

    data_type = argv[1]
    secondary_align = argv[2]
    datafile = argv[3]

    if data_type != "RAW" && data_type != "SLC"
        println("data type must be RAW or SLC")
        exit(1)
    end
    #
    # make working directories
    #
    mkpath("SLC/")
    #
    # clean up
    #
    run(`cleanup.csh SLC`)
    println()
    println("START ALIGN A STACK OF IMAGES")
    println()
    #
    # link the needed files from the raw directory
    #
    cd("SLC") do
        glob_symlink("../raw", ".PRM")
        glob_symlink("../raw", ".LED")
        if data_type == "RAW"
            glob_symlink("../raw", ".raw")
        else
            glob_symlink("../raw", ".SLC")
        end
        #
        # make sure dem.grd is there
        #
        if !isfile("../topo/dem.grd")
            println("DEM file not found!")
            exit(1)
        end

        println("Downsample the DEM data")
        run(`gmt grdfilter ../topo/dem.grd -D3 -Fg2 -I12s -Ni -Gflt.grd`)
        open("topo.llt", "w") do io
            run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf flt.grd -s`, stdout=io))
        end

        lines_in = readlines(joinpath("..", datafile))
        master = split(lines_in[1])[1]
        open("aligned.list", "w") do io
            for line in lines_in[2:end]
                w = split(line)
                if !isempty(w)
                    println(io, w[1])
                end
            end
        end

        mv("$master.PRM", "$master.PRM0"; force=true)

        println("calculating the SAT height for master $master")
        run(`calc_dop_orb $master.PRM0 $master.log 0`)
        cat_files("$master.PRM", ["$master.PRM0", "$master.log"])
        open("$master.PRM", "a") do io
            println(io, "fdd1                    = 0")
            println(io, "fddd1                   = 0")
        end
        rm("$master.log"; force=true)

        earth_radius = grep_field_last("$master.PRM", "earth_radius")
        fd1 = grep_field_last("$master.PRM", "fd1")
        run(`update_PRM $master.PRM earth_radius $earth_radius`)
        run(`update_PRM $master.PRM fd1 $fd1`)

        open("master.ratll", "w") do io
            run(pipeline(`SAT_llt2rat $master.PRM 1`, stdin="topo.llt", stdout=io))
        end

        rmax = parse(Float64, grep_field("$master.PRM", "num_rng_bins"))
        amax = parse(Float64, grep_field("$master.PRM", "num_lines"))

        if data_type == "RAW"
            println("Focusing the master - START")
            run(`sarp.csh $master.PRM`)
            println("Focusing the master - END")
        end

        aligned_names = readlines("aligned.list")
        naligned = length(aligned_names)
        ialigned = 0

        for aligned in aligned_names
            ialigned += 1
            println("working on  $aligned  [ $ialigned / $naligned ]")

            mv("$aligned.PRM", "$aligned.PRM0"; force=true)
            run(`calc_dop_orb $aligned.PRM0 $aligned.log $earth_radius`)

            cat_files("$aligned.PRM", ["$aligned.PRM0", "$aligned.log"])
            open("$aligned.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end

            run(`update_PRM $aligned.PRM earth_radius $earth_radius`)
            run(`update_PRM $aligned.PRM fd1 $fd1`)

            rm("$aligned.log"; force=true)

            if data_type == "RAW"
                println("Focusing the aligned - START")
                run(`sarp.csh $aligned.PRM`)
                println("Focusing the aligned - END")
            end

            open("aligned.ratll", "w") do io
                run(pipeline(`SAT_llt2rat $aligned.PRM 1`, stdin="topo.llt", stdout=io))
            end

            m_lines = readlines("master.ratll")
            a_lines = readlines("aligned.ratll")
            open("tmp.dat", "w") do io
                for (ml, al) in zip(m_lines, a_lines)
                    mf = split(ml)
                    af = split(al)
                    m1 = parse(Float64, mf[1]); m2 = parse(Float64, mf[2])
                    a1 = parse(Float64, af[1]); a2 = parse(Float64, af[2])
                    @printf(io, "%.6f %.6f %.6f %.6f %d\n", m1, a1 - m1, m2, a2 - m2, 100)
                end
            end
            open("offset.dat", "w") do io
                for line in eachline("tmp.dat")
                    w = split(line)
                    v1 = parse(Float64, w[1]); v3 = parse(Float64, w[3])
                    if v1 > 0 && v1 < rmax && v3 > 0 && v3 < amax
                        println(io, line)
                    end
                end
            end
            open("r.xyz", "w") do io
                for line in eachline("offset.dat")
                    w = split(line)
                    @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[2]))
                end
            end
            open("a.xyz", "w") do io
                for line in eachline("offset.dat")
                    w = split(line)
                    @printf(io, "%.6f %.6f %.6f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[4]))
                end
            end

            open("$aligned.PRM", "a") do io
                run(pipeline(`fitoffset.csh 3 3 offset.dat`, stdout=io))
            end
            run(`resamp $master.PRM $aligned.PRM $aligned.PRMresamp $aligned.SLCresamp 4`)
            mv("$aligned.SLC", "$aligned.SLC_old"; force=true)
            mv("$aligned.SLCresamp", "$aligned.SLC"; force=true)
            cp("$aligned.PRMresamp", "$aligned.PRM"; force=true)
            #
            #  do a secondary alignment with xcorr if requested
            #
            if parse(Int, secondary_align) > 0
                cp("$aligned.PRM", "tmp.PRM"; force=true)
                run(`update_PRM tmp.PRM rshift 0`)
                run(`update_PRM tmp.PRM ashift 0`)
                run(`update_PRM tmp.PRM sub_int_r 0.0`)
                run(`update_PRM tmp.PRM sub_int_a 0.0`)
                run(`update_PRM tmp.PRM stretch_r 0.0`)
                run(`update_PRM tmp.PRM stretch_a 0.0`)
                run(`update_PRM tmp.PRM a_stretch_r 0.0`)
                run(`update_PRM tmp.PRM a_stretch_a 0.0`)
                run(`xcorr $master.PRM tmp.PRM -xsearch 128 -ysearch 256 -nx 15 -ny 30`)
                open("tmp.PRM", "a") do io
                    run(pipeline(`fitoffset.csh 1 1 freq_xcorr.dat 20`, stdout=io))
                end
                run(`resamp $master.PRM tmp.PRM $aligned.PRMresamp $aligned.SLCresamp 4`)
                mv("$aligned.SLC", "$aligned.SLC_old"; force=true)
                mv("$aligned.SLCresamp", "$aligned.SLC"; force=true)
                #
                #  keep the old $aligned.PRM  because it has nearly the correct shifts needed for phasediff
                #
                #   cp $aligned.PRMresamp $aligned.PRM
            end
        end
        #
        #  cleanup the mess
        #
        rm_glob(f -> startswith(f, "tmp"))
        rm_glob(f -> endswith(f, "old"))
        rm_glob(f -> endswith(f, "resamp"))
        rm_glob(f -> endswith(f, ".raw") || endswith(f, ".PRM0"))
    end
end

main(ARGS)
