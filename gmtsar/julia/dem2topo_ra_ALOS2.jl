#!/usr/bin/env julia
#       $Id$
# Matt WEI Feb 1 2010
# modified by Xiaopeng Feb 9 2010
# modified by E. Fielding, DST, XT to add TSX data Jan 10 2014
# =======================================================================
#  script to make topography for interferograms
#  The USGS elevations are height above WGS84 so this is OK.
#
# alias rm 'rm -f'
# unset noclobber
#

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | awk 'NR==1{printf("%d",\$3)}'  -- first match only, parsed as Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""grep PATTERN *.PRM | awk 'NR == 1 {printf("%d", \$3)}'  -- first match across all glob-matched files"""
function grep_field_glob_int(pattern::AbstractString, suffix::AbstractString)
    files = sort(filter(f -> endswith(f, suffix), readdir(".")))
    for f in files
        for line in readlines(f)
            if occursin(pattern, line)
                return trunc(Int, parse(Float64, get(split(line), 3, "")))
            end
        end
    end
    error("pattern not found: $pattern in *$suffix")
end

"""grep PATTERN file | awk 'NR==1{print \$4}'  -- first match, 4th field"""
function grep_field4(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 4, "")
        end
    end
    error("pattern not found: $pattern in $file")
end

function main(argv::Vector{String})
    if length(argv) < 2
        println(" ")
        println("Usage: dem2topo_ra.csh master.PRM dem.grd")
        println(" ")
        println("        Note: Works for TSX,ALOS,ERS,ENVISAT")
        println(" ")
        exit(1)
    end

    #
    # local variables
    #
    scale = "-JX7i"
    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end
    #
    # ========================Mosaic topo data===============================

    #-----------------------------------------------------------------------
    #

    #------------------------Get bounds in radar coordinates----------------
    XMAX = grep_field(argv[1], "num_rng_bins")
    yvalid = grep_field(argv[1], "num_valid_az")
    num_patch = grep_field(argv[1], "num_patches")
    YMAX = string(parse(Int, yvalid) * parse(Int, num_patch))
    SC = grep_field(argv[1], "SC_identity")
    PRF = grep_field_glob_int("PRF", ".PRM")
    #
    # look for range sampling rate
    #
    rng_samp_rate = grep_field_int(argv[1], "rng_samp_rate")

    # set the range spacing of simulation in units of image range pixel size

    local rng
    if rng_samp_rate > 0 && rng_samp_rate < 25000000
        rng = 1
    elseif (rng_samp_rate >= 25000000 && rng_samp_rate < 72000000) || SC == "7"
        rng = 2
    elseif rng_samp_rate >= 72000000
        rng = 4
    else
        println("range sampling rate out of bounds")
        exit(0)
    end
    println(" range decimation is: ", " ", rng)

    #   use special SAT_llt2rat

    if SC == "5"
        println(" processing for ALOS data")
        run(pipeline(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $(argv[2]) -s`, `SAT_llt2rat $(argv[1]) 0 -bod`), stdout="trans.dat"))
    else
        println(" processing generic data")
        if SC == "10"
            run(pipeline(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $(argv[2]) -s`, `SAT_llt2rat $(argv[1]) 1 -bod`), stdout="trans.dat"))
        else
            run(pipeline(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $(argv[2]) -s`, `SAT_llt2rat $(argv[1]) 0 -bod`), stdout="trans.dat"))
        end
    end
    #
    # use an aximuth spacing of 2 for low PRF data such as S1 TOPS
    #
    if PRF < 1000
        run(pipeline(pipeline(`gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d`, `gmt blockmedian -R0/$XMAX/0/$YMAX -I2/32 -bi3d -bo3d -r $V`), stdout="temp.rat"))
        open("tmp.hint", "w") do io
            run(pipeline(`gmt surface temp.rat -Q -R0/$XMAX/0/$YMAX -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r $V`, stdout=io, stderr=io))
        end
        nregion = grep_field4("tmp.hint", "Hint")
        println("region=$nregion")
        run(`gmt surface temp.rat $nregion -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r $V`)
        run(`gmt grdsample pixel.grd -R0/$XMAX/0/$YMAX -I2/32 -r -Gpixel.grd`)
    else
        run(pipeline(pipeline(`gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d`, `gmt blockmedian -R0/$XMAX/0/$YMAX -I2/32 -bi3d -bo3d -r $V`), stdout="temp.rat"))
        open("tmp.hint", "w") do io
            run(pipeline(`gmt surface temp.rat -Q -R0/$XMAX/0/$YMAX -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r $V`, stdout=io, stderr=io))
        end
        nregion = grep_field4("tmp.hint", "Hint")
        println("region=$nregion")
        run(`gmt surface temp.rat $nregion -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r $V`)
        run(`gmt grdsample pixel.grd -R0/$XMAX/0/$YMAX -I2/32 -r -Gpixel.grd`)
    end
    #
    # flip top to bottom for both ascending and descending passes
    #
    run(`gmt grdmath pixel.grd FLIPUD = topo_ra.grd`)
    #
    # plotting
    #
    run(pipeline(`gmt grd2cpt topo_ra.grd -Cgray $V -Z`, stdout="topo_ra.cpt"))
    run(pipeline(`gmt grdimage topo_ra.grd $scale -P -Ctopo_ra.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen $V -K`, stdout="topo_ra.ps"))
    open("topo_ra.ps", "a") do io
        run(pipeline(`gmt psscale -Rtopo_ra.grd -J -DJTC+w5i/0.2i+h+e -Ctopo_ra.cpt -Bxaf -By+lm -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z topo_ra.ps`)
    println("Topo range/azimuth map: topo_ra.pdf")
    #
    #  clean up
    #
    rm("pixel.grd"; force=true)
    rm("temp.rat"; force=true)
    rm("dem.xyz"; force=true)
    rm("topo_ra.cpt"; force=true)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
