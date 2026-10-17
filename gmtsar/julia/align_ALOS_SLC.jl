#!/usr/bin/env julia
#       $Id$
#
#  D. Sandwell FEB 4 2010
#  M. Wei MAY 4 2010 - ENVISAT
#
# Align a aligned image to a master image and check results
#
# alias rm 'rm -f'
# unset noclobber
#

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
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

function main(argv::Vector{String})
    #
    # check the number of arguments
    #
    if length(argv) < 2
        println()
        println("Usage: align_ALOS_SLC.jl master_name aligned_name [supermaster_name]")
        println()
        println(" The supermaster_namestem is required if this is secondary alignment.")
        println()
        println("Example: align_ALOS_SLC.jl IMG-HH-ALPSRP055750660-H1.0__A IMG-HH-ALPSRP049040660-H1.0__A ")
        println()
        exit(1)
    end
    master = argv[1]
    aligned = argv[2]
    supermaster = length(argv) == 3 ? argv[3] : nothing

    #
    # focus the master if necessary
    # Do it no matter what for now. Put SLC_file to PRM. Might not be necessary
    #
    if !isfile("$master.SLC")
        symlink("../raw/$master.SLC", "$master.SLC")
        cp("../raw/$master.PRM", "$master.PRM"; force=true)
        run(`update_PRM $master.PRM SLC_file $master.SLC`)
    end
    #
    # focus the aligned image
    #
    # check the range sampling rate
    #
    rng_samp_rate_m = grep_field_int("$master.PRM", "rng_samp_rate")
    rng_samp_rate_s = grep_field_int("$aligned.PRM", "rng_samp_rate")
    if rng_samp_rate_m != rng_samp_rate_s
        println("The range sampling rate for master and aligned differ")
        println("Need to run the interferogram in steps until process2pass.csh is fixed")
        exit(1)
    end
    println("align.csh")
    if !isfile("$aligned.SLC")
        symlink("../raw/$aligned.SLC", "$aligned.SLC")
        cp("../raw/$aligned.PRM", "$aligned.PRM"; force=true)
        run(`update_PRM $aligned.PRM SLC_file $aligned.SLC`)
    end
    #
    # get the starting alignment parameters and run xcorr
    #
    cp("$master.PRM", "$master.PRM0"; force=true)
    cp("$aligned.PRM", "$aligned.PRM0"; force=true)
    if supermaster !== nothing
        RSHIFT = grep_field_cmd(`SAT_baseline $supermaster.PRM $aligned.PRM`, "rshift")
        ASHIFT = grep_field_cmd(`SAT_baseline $supermaster.PRM $aligned.PRM`, "ashift")
        #
        #   use the PRF of the supermaster in the surrogate master
        #
        PRF = grep_field("$supermaster.PRM", "PRF")
        run(`update_PRM $master.PRM PRF $PRF`)
    else
        RSHIFT = grep_field_cmd(`SAT_baseline $master.PRM $aligned.PRM`, "rshift")
        ASHIFT = grep_field_cmd(`SAT_baseline $master.PRM $aligned.PRM`, "ashift")
    end
    run(`update_PRM $aligned.PRM rshift $RSHIFT`)
    run(`update_PRM $aligned.PRM ashift $ASHIFT`)
    println("align.csh")
    println("correlate master and aligned to find offset parameters")
    run(`xcorr $master.PRM $aligned.PRM -xsearch 64 -ysearch 64 -nx 32 -ny 64`)
    #
    mv("$aligned.PRM", "junk.PRM"; force=true)
    cp("$master.PRM0", "$master.PRM"; force=true)
    open("$aligned.PRM", "w") do io
        for line in readlines("junk.PRM")
            if !occursin("shift", line)
                println(io, line)
            end
        end
    end
    #
    # put in the alignment parameters
    #
    open("$aligned.PRM", "a") do io
        run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("fitoffset")) 3 3 freq_xcorr.dat 18`, stdout=io))
    end
    mv("freq_xcorr.dat", "xcorr_$(master)_$(aligned).dat0"; force=true)
    #
    # refocus the second image
    #
    println("resamp aligned")
    run(`resamp $master.PRM $aligned.PRM $aligned.PRMresamp $aligned.SLCresamp 4`)
    rm("$aligned.SLC"; force=true)
    mv("$aligned.SLCresamp", "$aligned.SLC"; force=true)
    cp("$aligned.PRMresamp", "$aligned.PRM"; force=true)

    #
    for f in readdir(".")
        if startswith(f, "junk")
            rm(f; force=true)
        end
    end
    #done
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
