#!/usr/bin/env julia
#       $Id$
#
#  April 21, 1999 - David T. Sandwell
#  May 23, 2017 - Anders Hogrelius, updated to fully support Envisat formatted SLC data
#  August 12, 2026 - DTS changed to use mktime which requires gawk
#
#  Script to calculate a table of parameters from master and
#  aligned PRM files.
#
# unset noclobber
# setenv TZ UTC
#
#  Modified by M.Wei to add ALOS function, 9/27/06
#
using Dates

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""cut -cSTART-END / awk substr(\$1,start,len)  -- 1-indexed substring"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

"""gawk 'mktime("YEAR 01 01 00 00 00")' under TZ=UTC -- seconds since epoch"""
mktime_utc(year::Int) = Dates.datetime2unix(DateTime(year, 1, 1, 0, 0, 0))

function main(argv::Vector{String})
    if length(argv) < 2
        println(" ")
        println("Usage: baseline_table master.PRM aligned.PRM [GMT] ")
        println("               [GMT] creates table for pstext")
        println(" ")
        println(" Output:")
        println(" sat_orb aligned_time aligned_days(1992ERS,2006ALOS) Bpl Bperp xshift yshift")
        println(" ")
        exit(1)
    end
    #
    # Detect if we are dealing with Envisat formatted ERS SLC data without using SC_identity
    # Kludge to get correct SC_identity functionality until we can correct the values throughout the chain
    #
    ERSSLC = substr(argv[1], 1, 10)

    #
    #  get the time information from the master
    #
    MT0 = grep_field(argv[1], "SC_clock_start")
    MTF = grep_field(argv[1], "SC_clock_stop")
    MSC = grep_field(argv[1], "SC_identity")
    #
    #  get the time information from the alignedr
    #
    ST0 = grep_field(argv[2], "SC_clock_start")
    STF = grep_field(argv[2], "SC_clock_stop")
    SSC = grep_field(argv[2], "SC_identity")

    #
    # convert the start time to days since 1992
    #
    T0 = parse(Int, split(grep_field(argv[2], "SC_clock_start"), ".")[1])
    DAY = T0 % 1000
    #
    local YDAY
    if SSC == "1" || SSC == "2"
        run(pipeline(`SAT_baseline $(argv[1]) $(argv[2])`, stdout="temp"))
        t0 = mktime_utc(1992)
        YR = div(T0, 1000)
        t1 = mktime_utc(YR)
        YDAY = trunc(Int, (t1 - t0) / 86400.0 + 0.5) + DAY - 1
    elseif SSC == "4" || SSC == "6"
        run(pipeline(`SAT_baseline $(argv[1]) $(argv[2])`, stdout="temp"))
        t0 = mktime_utc(1992)
        YR = div(T0, 1000)
        t1 = mktime_utc(YR)
        YDAY = trunc(Int, (t1 - t0) / 86400.0 + 0.5) + DAY - 1
    elseif SSC == "5"
        run(pipeline(`SAT_baseline $(argv[1]) $(argv[2])`, stdout="temp"))
        YR1 = div(T0, 1000)
        local t0
        if YR1 < 2013
            t0 = mktime_utc(2006)
        else
            t0 = mktime_utc(2014)
        end
        YR = div(T0, 1000)
        t1 = mktime_utc(YR)
        YDAY = trunc(Int, (t1 - t0) / 86400.0 + 0.5) + DAY - 1
    else
        run(pipeline(`SAT_baseline $(argv[1]) $(argv[2])`, stdout="temp"))
        local t0
        if SSC == "7" || SSC == "8"
            t0 = mktime_utc(2007)
        elseif SSC == "9"
            t0 = mktime_utc(2008)
        elseif SSC == "10"
            t0 = mktime_utc(2014)
        else
            t0 = mktime_utc(2020)
        end
        YR = div(T0, 1000)
        t1 = mktime_utc(YR)
        YDAY = trunc(Int, (t1 - t0) / 86400.0 + 0.5) + DAY
    end
    #
    #  get the needed parameters from temp
    #
    BPL = grep_field("temp", "B_parallel")
    BPR = grep_field("temp", "B_perpendicular")
    XS = grep_field("temp", "xshift")
    YS = grep_field("temp", "yshift")
    NM = grep_field(argv[2], "SC_identity")
    local ORB
    if SSC == "5"
        YR1 = div(T0, 1000)
        if YR1 < 2013
            input_field = grep_field(argv[2], "input_file")
            ORB = substr(input_field, 14, 5)
        else
            input_field = grep_field(argv[2], "input_file")
            if length(argv) < 3
                ORB = substr(input_field, 1, length(input_field) - 4)
            else
                ORB = substr(input_field, 13, 5)
            end
        end
    elseif SSC == "6" || ERSSLC == "SAR_IMS_1P"
        input_field = grep_field(argv[2], "input_file")
        ORB = substr(input_field, 50, 5)
    elseif SSC == "4"
        input_field = grep_field(argv[2], "input_file")
        ORB = substr(input_field, 17, 5)
    elseif SSC == "1" || SSC == "2"
        input_field = grep_field(argv[2], "input_file")
        ORB = substr(input_field, 1, 8)
    else
        input_field = grep_field(argv[2], "input_file")
        ORB = split(input_field, ".")[1]
    end
    #

    if length(argv) < 3
        println("$ORB $ST0 $YDAY $BPL $BPR $XS $YS")
    else
        println("$YDAY $BPR 8 0. 0 5 $ORB")
    end
    #
    # clean up
    #
    rm("temp"; force=true)
end

main(ARGS)
