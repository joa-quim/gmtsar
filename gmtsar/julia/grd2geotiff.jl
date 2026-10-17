#!/usr/bin/env julia
#
#  D. Sandwell FEB 18 2015
#
# unset noclobber
#
# script to convert a grd file to a geotiff file
#

"""cmd | cut -fN  -- Nth tab-separated field of a subprocess's captured stdout"""
function cut_field_cmd(cmd::Cmd, n::Int)
    out = strip(read(cmd, String))
    return split(out, '\t')[n]
end

function main(argv::Vector{String})
    if length(argv) < 2 || length(argv) > 3
        println(" ")
        println("Usage: grd2geotiff.csh grd_file_stem cptfile [-R<west>/<east>/<south>/<north>] ")
        println(" ")
        println("Example: grd2geotiff.csh phase phase.cpt ")
        println(" ")
        exit(1)
    end
    #
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

    DX = cut_field_cmd(`gmt grdinfo $(argv[1]).grd -C`, 8)
    DPI = strip(read(`gmt math -Q $DX INV RINT =`, String))
    println(DPI)
    run(`gmt set COLOR_MODEL = hsv`)
    run(`gmt set PAPER_MEDIA = tabloid`)
    #
    run(`gmt grdgradient $(argv[1]).grd -Ggrad.grd $V -Nt0.7 -A60`)
    if length(argv) == 3
        run(pipeline(`gmt grdimage $(argv[1]).grd -Igrad.grd -C$(argv[2]) $(argv[3]) -Jx1id -P -Y2i -X2i -Q $V`, stdout="$(argv[1]).ps"))
    elseif length(argv) == 2
        run(pipeline(`gmt grdimage $(argv[1]).grd -Igrad.grd -C$(argv[2]) -Jx1id -P -Y2i -X2i -Q $V`, stdout="$(argv[1]).ps"))
    end
    #
    #   now make the geotiff
    #
    println("Make $(argv[1]).tiff")
    run(`gmt psconvert $(argv[1]).ps -W+g+t$(argv[1]) -E$DPI -P $VS`)
    rm("$(argv[1]).ps"; force=true)
    rm("grad.grd"; force=true)
    #
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
