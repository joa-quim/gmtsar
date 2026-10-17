#!/usr/bin/env julia
#       $Id$
#
#  D. T. Sandwell AUG 30 2007
#
#  Script to replace a value in a PRM-file
#
#
# alias rm 'rm -f'
# unset noclobber
#
function main(argv::Vector{String})
    if length(argv) < 2
        println(" ")
        println("Usage: update_PRM file.PRM param value ")
        println(" ")
        println("Example: update_PRM IMG-HH-ALPSRP049040660-H1.0__A.PRM rshift 10")
        exit(1)
    end
    #
    #  copy the file to junk.PRM
    #
    cp(argv[1], "junk.PRM"; force=true)
    #
    #  remove the line with the matching parameter
    #
    if argv[2] != "clock_start" && argv[2] != "clock_stop"
        open("junk2.PRM", "w") do io
            for line in readlines("junk.PRM")
                if !occursin(argv[2], line)
                    println(io, line)
                end
            end
        end
    else
        if argv[2] == "clock_start"
            tmptime = nothing
            for line in readlines("junk.PRM")
                if occursin("SC_clock_start", line)
                    tmptime = get(split(line), 3, "")
                    break
                end
            end
            open("junk2.PRM", "w") do io
                for line in readlines("junk.PRM")
                    if !occursin(argv[2], line)
                        println(io, line)
                    end
                end
            end
            open("junk2.PRM", "a") do io
                println(io, "SC_clock_start", " = ", tmptime)
            end
        else
            tmptime = nothing
            for line in readlines("junk.PRM")
                if occursin("SC_clock_stop", line)
                    tmptime = get(split(line), 3, "")
                    break
                end
            end
            open("junk2.PRM", "w") do io
                for line in readlines("junk.PRM")
                    if !occursin(argv[2], line)
                        println(io, line)
                    end
                end
            end
            open("junk2.PRM", "a") do io
                println(io, "SC_clock_stop", " = ", tmptime)
            end
        end
    end
    #
    #  add a new line
    #
    open("junk2.PRM", "a") do io
        println(io, argv[2], " = ", argv[3])
    end
    #
    mv("junk2.PRM", argv[1]; force=true)
    rm("junk.PRM"; force=true)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
