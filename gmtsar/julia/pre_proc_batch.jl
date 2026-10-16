#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong, Mar 2 2010
#  modified by D. Sandwell MAR 11 2010
#  modified by A Hogrelius May 22 2017 (added support for ENVI_SLC)
#  modified by D. Sandwell NOV 11 2011 (added support for TSX)
#
#  preprocess all the data based on data.in table file and generate:
#  1. raw files
#  2. PRM files
#  3. time-baseline plot for user to create stacking pairs

#  format in data.in table file:
#  	line 1: master_name
# 	line 2 and below: aligned_name

# alias rm 'rm -f'
# unset noclobber

using Printf

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field, "" if none"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    return ""
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""cat srcs... > dst"""
function cat_files(dst::AbstractString, srcs::Vector{String})
    open(dst, "w") do io
        for s in srcs
            write(io, read(s))
        end
    end
end

"""mirrors awk's 1-indexed substr(\$1,start,len)"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    #
    # check the number of arguments
    #
    if length(argv) != 3
        println()
        println("Usage: pre_proc_batch.jl SAT data.in batch.config")
        println("       preprocess a set of images using a common rear_range and radius")
        println()
        println(" SAT can be ALOS ERS ENVI(ENVISAT) ENVI_SLC TSX")
        println()
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
        println("       example of data.in for TSX is:")
        println("         20171231")
        println("         20180111")
        println("         20180122")
        println()
        println("Example: pre_proc_batch.jl ENVI data.in batch.config")
        println()
        exit(1)
    end

    SAT = argv[1]
    if SAT != "ALOS" && SAT != "ENVI" && SAT != "ENVI_SLC" && SAT != "ERS" && SAT != "TSX"
        println()
        println(" SAT can be ALOS ERS ENVI(ENVISAT) ENVI_SLC or TSX ")
        println()
        exit(1)
    end
    #
    # read parameters from configuration file
    #
    num_patches = grep_field(argv[3], "num_patches")
    near_range = grep_field(argv[3], "near_range")
    earth_radius = grep_field(argv[3], "earth_radius")
    fd = grep_field(argv[3], "fd1")
    #
    commandline = String[]
    if SAT == "ERS" || SAT == "ENVI"
        if near_range != ""
            push!(commandline, near_range)
        else
            push!(commandline, "0")
        end

        if earth_radius != ""
            push!(commandline, earth_radius)
        else
            push!(commandline, "0")
        end

        if num_patches != ""
            push!(commandline, num_patches)
        else
            push!(commandline, "0")
        end

        if fd != ""
            push!(commandline, fd)
        end

    elseif SAT == "ALOS"
        if earth_radius != ""
            push!(commandline, "-radius"); push!(commandline, earth_radius)
        end
        if near_range != ""
            push!(commandline, "-near"); push!(commandline, near_range)
        end
        if num_patches != ""
            push!(commandline, "-npatch"); push!(commandline, num_patches)
        end
        if fd != ""
            push!(commandline, "-fd1"); push!(commandline, fd)
        end
    end

    println(join(commandline, " "))
    #
    # open and read data.in table
    #
    println()
    println("START PREPROCESS A STACK OF IMAGES")
    println()
    println("preprocess master image")
    datalines = readlines(argv[2])
    line1 = split(datalines[1])
    local master
    if SAT == "ERS" || SAT == "ENVI" || SAT == "ENVI_SLC" || SAT == "TSX"
        master = line1[1]
    elseif SAT == "ALOS"
        master = substr(line1[1], 8, length(line1[1]) - 7)
    end
    #
    # unpack the master if necessary
    #
    local NEAR, RAD, FD1, npatch, rng_samp_rate_m
    if SAT == "ERS" || SAT == "ENVI"

        if !isfile("$master.raw") || !isfile("$master.LED")
            run(`$(SAT)_pre_process $master $(commandline...)`)
        end

        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        FD1 = grep_field("$master.PRM", "fd1")
        npatch = grep_field("$master.PRM", "num_patch")

        println("before baseline")
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM GMT`, stdout="table.gmt"))
        println("after baseline")

    elseif SAT == "ENVI_SLC"

        if earth_radius == ""
            earth_radius = "0"
        end

        if !isfile("$master.SLC") || !isfile("$master.LED")
            run(`ENVI_SLC_pre_process $master $earth_radius`)
        end

        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        FD1 = grep_field("$master.PRM", "fd1")
        npatch = grep_field("$master.PRM", "num_patch")

        println("before baseline")
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM GMT`, stdout="table.gmt"))
        println("after baseline")
    elseif SAT == "ALOS"

        if !isfile("IMG-HH-$master.raw") || !isfile("IMG-HH-$master.PRM")
            run(`$(SAT)_pre_process IMG-HH-$master LED-$master $(commandline...)`)
        end

        NEAR = grep_field("IMG-HH-$master.PRM", "near_range")
        RAD = grep_field("IMG-HH-$master.PRM", "earth_radius")
        rng_samp_rate_m = grep_field_int("IMG-HH-$master.PRM", "rng_samp_rate")
        FD1 = grep_field("IMG-HH-$master.PRM", "fd1")
        npatch = grep_field("IMG-HH-$master.PRM", "num_patch")

        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM GMT`, stdout="table.gmt"))

    elseif SAT == "TSX"

        if !isfile("$master.raw") || !isfile("$master.PRM")
            run(`make_slc_tsx $master.xml $master.cos $master`)
            cp("$master.PRM", "$master.PRM0"; force=true)
            run(`calc_dop_orb $master.PRM0 $master.log 0 0`)
            cat_files("$master.PRM", ["$master.PRM0", "$master.log"])
            open("$master.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
        end

        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        rng_samp_rate_m = grep_field_int("$master.PRM", "rng_samp_rate")
        FD1 = grep_field("$master.PRM", "fd1")
        npatch = grep_field("$master.PRM", "num_patch")

        run(pipeline(`baseline_table.csh $master.PRM $master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM GMT`, stdout="table.gmt"))

    end
    #
    # loop and unpack the aligned image using the same earth radius and near range as the master image
    #
    aligned_tokens = String[]
    for l in datalines[2:end]
        append!(aligned_tokens, split(l))
    end
    for line2 in aligned_tokens
        println("pre_proc_batch.csh")
        println("preprocess aligned images")
        if SAT == "ERS" || SAT == "ENVI"

            aligned = line2
            if !isfile("$aligned.raw") || !isfile("$aligned.LED")
                run(`$(SAT)_pre_process $aligned $NEAR $RAD $npatch $FD1`)
            end
            open("baseline_table.dat", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM`, stdout=io))
            end
            open("table.gmt", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM GMT`, stdout=io))
            end

        elseif SAT == "TSX"

            aligned = line2
            if !isfile("$aligned.SLC") || !isfile("$aligned.LED")
                run(`make_slc_tsx $aligned.xml $aligned.cos $aligned`)
            end
            RAD = grep_field("$master.PRM", "earth_radius")
            cp("$aligned.PRM", "$aligned.PRM0"; force=true)
            run(`calc_dop_orb $aligned.PRM0 $aligned.log $RAD 0`)
            cat_files("$aligned.PRM", ["$aligned.PRM0", "$aligned.log"])
            open("$aligned.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
            open("baseline_table.dat", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM`, stdout=io))
            end
            open("table.gmt", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM GMT`, stdout=io))
            end

        elseif SAT == "ENVI_SLC"

            aligned = line2
            if !isfile("$aligned.SLC") || !isfile("$aligned.LED")
                run(`$(SAT)_pre_process $aligned $RAD`)
            end
            open("baseline_table.dat", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM`, stdout=io))
            end
            open("table.gmt", "a") do io
                run(pipeline(`baseline_table.csh $master.PRM $aligned.PRM GMT`, stdout=io))
            end

        elseif SAT == "ALOS"

            aligned = substr(line2, 8, length(line2) - 7)
            if !isfile("IMG-HH-$aligned.raw") || !isfile("IMG-HH-$aligned.PRM")
                run(`$(SAT)_pre_process IMG-HH-$aligned LED-$aligned -fd1 $FD1 -near $NEAR -radius $RAD -npatch $npatch`)
            end
            #
            # check the range sampling rate of the aligned images and do conversion if necessary
            #
            rng_samp_rate_s = grep_field_int("IMG-HH-$aligned.PRM", "rng_samp_rate")
            t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)
            if t == "1.0"
                println("The range sampling rate for master and aligned images are: $rng_samp_rate_m")
                #
                open("baseline_table.dat", "a") do io
                    run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$aligned.PRM`, stdout=io))
                end
                open("table.gmt", "a") do io
                    run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$aligned.PRM GMT`, stdout=io))
                end
            elseif t == "2.0"
                println("Convert the aligned image from FBD to FBS mode")
                run(`ALOS_fbd2fbs IMG-HH-$aligned.PRM IMG-HH-$(aligned)_FBS.PRM`)
                #
                open("baseline_table.dat", "a") do io
                    run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$(aligned)_FBS.PRM`, stdout=io))
                end
                open("table.gmt", "a") do io
                    run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$(aligned)_FBS.PRM GMT`, stdout=io))
                end
                println("Overwriting the old aligned image")
                mv("IMG-HH-$(aligned)_FBS.PRM", "IMG-HH-$aligned.PRM"; force=true)
                run(`update_PRM IMG-HH-$aligned.PRM input_file IMG-HH-$aligned.raw`)
                mv("IMG-HH-$(aligned)_FBS.raw", "IMG-HH-$aligned.raw"; force=true)

            elseif t == "0.5"
                println("Use FBS mode image as master")
                exit(1)
            else
                println("The range sampling rate for master and aligned images are not convertable")
                exit(1)
            end
            # end of the if ($SAT == ALOS)
        end
        # end of the loop over aligned images
    end

    #
    # make baseline plots
    #

    if SAT == "ERS" || SAT == "ENVI" || SAT == "ENVI_SLC"
        open("text", "w") do io
            for line in eachline("table.gmt")
                w = split(line)
                v1 = parse(Float64, w[1])
                println(io, "$(1992 + v1 / 365.25) $(w[2]) $(w[7])")
            end
        end
        #    awk '{print 1992+$1/365.25,$2,7,$4,$5,$6,$7}' < table.gmt > text
        #    awk '{print 1992+$1/365.25,$2,7,-45,$5,$6,$7}' < table.gmt > text
    elseif SAT == "TSX"
        open("text", "w") do io
            for line in eachline("table.gmt")
                w = split(line)
                v1 = parse(Float64, w[1])
                println(io, "$(2007 + v1 / 365.25) $(w[2]) $(w[7])")
            end
        end
    elseif SAT == "ALOS"
        open("text", "w") do io
            for line in eachline("table.gmt")
                w = split(line)
                v1 = parse(Float64, w[1])
                println(io, "$(2006.5 + (v1 - 181) / 365.25) $(w[2]) $(w[7])")
            end
        end
        #    awk '{print 2006.5+($1-181)/365.25,$2,9,$4,$5,$6,$7}' < table.gmt > text
    end
    gmtinfo_out = read(`gmt gmtinfo text -C`, String)
    gi = split(strip(gmtinfo_out))
    region = [
        string(parse(Float64, gi[1]) - 0.5),
        string(parse(Float64, gi[2]) + 0.5),
        string(parse(Float64, gi[3]) - 500),
        string(parse(Float64, gi[4]) + 500),
    ]
    # set region = `minmax text -C | awk '{print $1-0.5, $2+0.5, -1200, 1200}'`
    open("stacktable_all.ps", "w") do io
        run(pipeline(`gmt pstext text -JX8.8i/6.8i -R$(region[1])/$(region[2])/$(region[3])/$(region[4]) -D0.2/0.2 -X1.5i -Y1i -K -N -F+f8,Helvetica+j5`, stdout=io))
    end
    open("text2", "w") do io
        for line in eachline("text")
            w = split(line)
            println(io, "$(w[1]) $(w[2])")
        end
    end
    open("stacktable_all.ps", "a") do io
        run(pipeline(`gmt psxy text2 -Sp0.2c -G0 -R -JX -Ba1:"year":/a200g00f100:"baseline (m)":WSen -O`, stdout=io))
    end

    println()
    println("END PREPROCESS A STACK OF IMAGES")
    println()

    #
    # clean up the mess
    #
    rm("text"; force=true)
    rm("text2"; force=true)
    for f in readdir(".")
        if endswith(f, ".PRM0")
            rm(f; force=true)
        end
    end
end

main(ARGS)
