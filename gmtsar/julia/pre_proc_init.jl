#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong, Mar 2 2010
#  modified by D. Sandwell MAR 11 2010
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

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""mirrors awk's 1-indexed substr(\$1,start,len)"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    #
    # check the number of arguments
    #
    if length(argv) != 2
        println("")
        println("Usage: pre_proc_init.csh SAT data.in")
        println("")
        println("       preprocess a set of images using default Dopper centroid, rear_range and radius, number of patches")
        println("       a baseline-time plot will be generated")
        println("       after running this command ")
        println("       the user should choose an appropriate master image ")
        println("       the user should also decide a common Dopper centroid, rear_range and radius, number of patches to run batch processing")
        println("       the data with completely different Doppler centroid or baselines can be omitted from further processing")
        println("")
        println(" SAT can be ALOS ERS or ENVI(ENVISAT)")
        println("")
        println("       format of data.in is:")
        println("         line 1: master_name")
        println("         line 2 and below: aligned_name")
        println("")
        println("       example of data.in for ALOS is:")
        println("         IMG-HH-ALPSRP096010650-H1.0__A")
        println("         IMG-HH-ALPSRP089300650-H1.0__A")
        println("         IMG-HH-ALPSRP236920650-H1.0__A")
        println("")
        println("       example of data.in for ERS is:")
        println("         e1_05783")
        println("         e1_07787")
        println("         e1_10292")
        println("")
        println("       example of data.in for ENVISAT is:")
        println("         ENV1_2_127_2925_07195")
        println("         ENV1_2_127_2925_12706")
        println("         ENV1_2_127_2925_13207")
        println("")
        println("Example: pre_proc_init.csh ENVI data.in")
        println("")
        exit(1)
    end

    SAT = argv[1]
    if SAT != "ALOS" && SAT != "ENVI" && SAT != "ERS"
        println("")
        println(" SAT can be ALOS ERS or ENVI(ENVISAT)")
        println("")
        exit(1)
    end
    #
    # open and read data.in table
    #
    println("")
    println("running pre_proc_init.csh")
    println("")
    println("preprocess master image")
    datalines = readlines(argv[2])
    line1 = split(datalines[1])
    local master
    if SAT == "ERS" || SAT == "ENVI"
        master = line1[1]
    elseif SAT == "ALOS"
        master = substr(line1[1], 8, length(line1[1]) - 7)
    end
    #
    # unpack the master if necessary
    #
    local NEAR, RAD, FD1, rng_samp_rate_m
    if SAT == "ERS" || SAT == "ENVI"

        if !isfile("$master.raw") || !isfile("$master.LED")
            run(`$(SAT)_pre_process $master 0 0 0`)
        end

        println("before baseline")
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh $master.PRM $master.PRM GMT`, stdout="table.gmt"))
        println("after baseline")

    elseif SAT == "ALOS"

        if !isfile("IMG-HH-$master.raw") || !isfile("IMG-HH-$master.PRM")
            run(`$(SAT)_pre_process IMG-HH-$master LED-$master`)
        end

        NEAR = grep_field("IMG-HH-$master.PRM", "near_range")
        RAD = grep_field("IMG-HH-$master.PRM", "earth_radius")
        rng_samp_rate_m = grep_field_int("IMG-HH-$master.PRM", "rng_samp_rate")
        FD1 = grep_field("IMG-HH-$master.PRM", "fd1")

        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM`, stdout="baseline_table.dat"))
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM GMT`, stdout="table.gmt"))

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
                run(`$(SAT)_pre_process $aligned 0 0 0`)
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
                run(`$(SAT)_pre_process IMG-HH-$aligned LED-$aligned`)
            end
            #
            # check the range sampling rate of the aligned images and do conversion if necessary
            #
            rng_samp_rate_s = grep_field_int("IMG-HH-$aligned.PRM", "rng_samp_rate")
            t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)
            if t == "1.0"
                println("The range sampling rate for master and aligned images are: " * string(rng_samp_rate_m))
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
                println("Use the FBS mode image as master")
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

    if SAT == "ERS" || SAT == "ENVI"
        open("text", "w") do io
            for line in eachline("table.gmt")
                w = split(line)
                v1 = parse(Float64, w[1])
                println(io, "$(1992 + v1 / 365.25) $(w[2]) $(w[7])")
            end
        end
        #    awk '{print 1992+$1/365.25,$2,7,$4,$5,$6,$7}' < table.gmt > text
        #    awk '{print 1992+$1/365.25,$2,7,-45,$5,$6,$7}' < table.gmt > text
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
    #  set region = `minmax text -C | awk '{print $1-0.5, $2+0.5, -1200, 1200}'`
    run(pipeline(`gmt pstext text -JX8.8i/6.8i -R$(region[1])/$(region[2])/$(region[3])/$(region[4]) -D0.2/0.2 -X1.5i -Y1i -K -N -F+f8,Helvetica+j5`, stdout="stacktable_all.ps"))
    open("text2", "w") do io
        for line in eachline("text")
            w = split(line)
            println(io, "$(w[1]) $(w[2])")
        end
    end
    open("stacktable_all.ps", "a") do io
        run(pipeline(`gmt psxy text2 -Sp0.2c -G0 -R -JX -Ba1:"year":/a200g00f100:"baseline (m)":WSen -O`, stdout=io))
    end

    #
    # clean up the mess
    #
    rm("text"; force=true)
    rm("text2"; force=true)
end

main(ARGS)
