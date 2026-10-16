#!/usr/bin/env julia
#       $Id$
#
#  D. Sandwell FEB 10 2010
#
# unset noclobber
#
# script to convert a grd file to a kml file for Google Earth
#

"""cmd | cut -fN  -- Nth tab-separated field of a subprocess's captured stdout"""
function cut_field_cmd(cmd::Cmd, n::Int)
    out = strip(read(cmd, String))
    return split(out, '\t')[n]
end

function main(argv::Vector{String})
    if length(argv) < 2 || length(argv) > 3
        println(" ")
        println("Usage: grd2kml.csh grd_file_stem cptfile [-R<west>/<east>/<south>/<north>] ")
        println(" ")
        println("Example: grd2kml.csh phase phase.cpt ")
        println(" ")
        exit(1)
    end
    #
    local V::Vector{String}
    local VS::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
        VS = String[]
    else
        V = ["-V"]
        VS = ["-S", "-V"]
    end

    #
    DX = cut_field_cmd(`gmt grdinfo $(argv[1]).grd -C`, 8)
    DPI = strip(read(`gmt gmtmath -Q $DX INV RINT =`, String))
    #echo $DPI
    run(`gmt set COLOR_MODEL = hsv`)
    run(`gmt set PS_MEDIA = A2`)
    #
    if length(argv) == 3
        run(pipeline(`gmt grdimage $(argv[1]).grd -C$(argv[2]) $(argv[3]) -Jx1id -P -Y2i -X2i -Q $V`, stdout="$(argv[1]).ps"))
    elseif length(argv) == 2
        run(pipeline(`gmt grdimage $(argv[1]).grd -C$(argv[2]) -Jx1id -P -Y2i -X2i -Q $V`, stdout="$(argv[1]).ps"))
    end
    #
    #   now make the kml and png
    #
    println("Make $(argv[1]).kml and $(argv[1]).png")
    run(`gmt psconvert $(argv[1]).ps -W+k+t$(argv[1]) -E$DPI -TG -P $VS -F$(argv[1])`)
    rm("$(argv[1]).ps"; force=true)
    rm("grad.grd"; force=true)
    for f in readdir(".")
        if startswith(f, "ps2raster") || startswith(f, "psconvert")
            rm(f; force=true)
        end
    end
    #
end

main(ARGS)
