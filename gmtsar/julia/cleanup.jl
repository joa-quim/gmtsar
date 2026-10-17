#!/usr/bin/env julia
#       $Id$
#
#  David T. Sandwell, MAR 11, 2010
#
# Clean the disk area in preparation for process2pass.csh
# This should be run in the top directory.  An ls will show
# raw SLC intf topo
#
# alias rm 'rm -f'
# unset noclobber
#
function main(argv::Vector{String})
    if length(argv) < 1
        println(" ")
        println("Usage: cleanup.csh directory ")
        println(" ")
        println(" directory could be: raw, SLC, topo, intf, or all ")
        println(" ")
        println("Example: cleanup.csh all")
        println(" ")
        exit(1)
    end
    #
    #
    if argv[1] == "all"
        println("")
        println("clean up all")
        rm("SLC"; force=true, recursive=true)
        rm("intf"; force=true, recursive=true)
        for f in readdir("raw")
            if occursin(".PRM", f)
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".raw")
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".LED")
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".SLC")
                rm(joinpath("raw", f); force=true)
            end
        end
        cd("topo") do
            for f in readdir(".")
                if !occursin("dem.grd", f)
                    try
                        rm(f; force=true)
                    catch e
                        println(stderr, "rm: $f: $e")
                    end
                end
            end
        end
        println("")
    end
    if argv[1] == "raw"
        println("")
        println("clean up raw/ folder")
        for f in readdir("raw")
            if occursin(".PRM", f)
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".raw")
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".LED")
                rm(joinpath("raw", f); force=true)
            end
        end
        println("")
    end
    if argv[1] == "SLC"
        println("")
        println("clean up SLC/ folder")
        for f in readdir("SLC")
            try
                rm(joinpath("SLC", f); force=true, recursive=true)
            catch e
                println(stderr, "rm: $f: $e")
            end
        end
        println("")
    end
    if argv[1] == "intf"
        println("")
        println("clean up intf/ folder")
        for f in readdir("intf")
            try
                rm(joinpath("intf", f); force=true, recursive=true)
            catch e
                println(stderr, "rm: $f: $e")
            end
        end
        println("")
    end
    if argv[1] == "topo"
        println("")
        println("clean up topo/ folder")
        cd("topo") do
            for f in readdir(".")
                if !occursin("dem.grd", f)
                    try
                        rm(f; force=true)
                    catch e
                        println(stderr, "rm: $f: $e")
                    end
                end
            end
        end
        println("")
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
