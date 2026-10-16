#!/usr/bin/env julia
#       $Id$
#
#  D. Sandwell FEB 7 2010
#
# unset noclobber
#
#  script to focus SAR data and deal with negative yshift
#

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    #
    # check for number of arguments
    #
    if length(argv) < 1
        println("")
        println("Usage: sarp.csh file.PRM ")
        println("")
        println("Example: sarp.csh IMG-HH-ALPSRP049040660-H1.0__A.PRM ")
        println("")
        exit(1)
    end
    #
    slcfile = substr(argv[1], 1, length(argv[1]) - 3) * "SLC"
    #
    run(pipeline(`esarp $(argv[1]) $slcfile`, stdout="tmp_sarp"))
    #
    #   update the PRM file
    #
    open("tmp.PRM", "w") do io
        for line in eachline(argv[1])
            if !occursin("SLC_file", line) && !occursin("dtype", line)
                println(io, line)
            end
        end
    end
    mv("tmp.PRM", argv[1]; force=true)
    open(argv[1], "a") do io
        println(io, "SLC_file  = " * slcfile)
    end
    if argv[3] == "R4"
        open(argv[1], "a") do io
            println(io, "dtype = c")
        end
    else
        open(argv[1], "a") do io
            println(io, "dtype = a")
        end
    end

    #
    #   put in dfact into PRM file
    #
    dfact = nothing
    for line in eachline("tmp_sarp")
        if occursin("I2SCALE", line)
            dfact = split(line)[2]
            break
        end
    end
    run(`update_PRM $(argv[1]) SLC_scale $dfact`)
    rm("tmp_sarp"; force=true)
end

main(ARGS)
