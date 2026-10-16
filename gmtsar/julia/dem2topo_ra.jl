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
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
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
        for line in eachline(f)
            if occursin(pattern, line)
                return trunc(Int, parse(Float64, split(line)[3]))
            end
        end
    end
    error("pattern not found: $pattern in *$suffix")
end

"""grep Hint tmp | head -1 | awk '{for(i=1;i<=NF;i++) print \$i}' | grep /  -- fields of the first Hint line that contain a slash"""
function grep_hint_slash(file::AbstractString)
    firstline = ""
    for line in eachline(file)
        if occursin("Hint", line)
            firstline = line
            break
        end
    end
    return [tok for tok in split(firstline) if occursin("/", tok)]
end

function main(argv::Vector{String})
    if length(argv) != 3 && length(argv) != 2
        println(" ")
        println("Usage: dem2topo_ra.csh master.PRM dem.grd [interpolation_approach]")
        println(" ")
        println("    Note: interpolation_approach default is 0:surface with tension")
        println("          set to 1 for gmt triangulate")
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
    # set tension
    #
    tension = 0.1
    #
    # set interpolation approach
    #
    mode = 0
    if length(argv) == 3
        mode = parse(Int, argv[3])
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
    region = "0/$XMAX/0/$YMAX"
    println("Working over $region ... ")
    #
    # look for range sampling rate
    #
    rng_samp_rate = grep_field_int(argv[1], "rng_samp_rate")
    #
    # set the range spacing of simulation in units of image range pixel size
    #
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

    if SC == "10" || SC == "11"
        run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $(argv[2]) -s`, `SAT_llt2rat $(argv[1]) 1 -bod`, stdout="trans.dat"))
    else
        run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $(argv[2]) -s`, `SAT_llt2rat $(argv[1]) 0 -bod`, stdout="trans.dat"))
    end
    #
    # use an azimuth spacing of 2 for low PRF data such as S1 TOPS
    #
    if PRF < 1000
        run(pipeline(`gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d`, `gmt blockmedian -R$region -I$rng/2 -bi3d -bo3d -r $V`, stdout="temp.rat"))
        if mode == 0
            open("tmp", "w") do io
                run(pipeline(`gmt surface temp.rat -R$region -I$rng/2 -bi3d -T$tension -N1000 -Gpixel.grd -r -Q`, stdout=io, stderr=io))
            end
            RR = grep_hint_slash("tmp")
            if isempty(RR)
                run(`gmt surface temp.rat -R$region -I$rng/2 -bi3d -T$tension -N1000 -Gpixel.grd -r $V`)
            else
                run(`gmt surface temp.rat $RR -I$rng/2 -bi3d -T$tension -N1000 -Gpixel.grd -r $V`)
                run(`gmt grdcut pixel.grd -R$region -Gtmp.grd`)
                mv("tmp.grd", "pixel.grd"; force=true)
            end
        elseif mode == 1
            rng2 = rng * 8
            run(`gmt triangulate temp.rat -R$region -I$rng/2 -bi3d -Gtopo_ra_tmp.grd -r $V`)
            run(pipeline(`gmt blockmean temp.rat -R$region -I$rng2/16 -bi3d -bo3d -r`, stdout="mean.rat"))
            run(`gmt surface mean.rat -R$region -I$rng2/16 -bi3d -T0.1 -N1000 -Gcoarse.grd -r`)
            run(`gmt grdfill topo_ra_tmp.grd -Agcoarse.grd -Gpixel.grd`)
            rm("topo_ra_tmp.grd"; force=true)
            rm("coarse.grd"; force=true)
            rm("mean.rat"; force=true)
        end
    else
        run(pipeline(`gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d`, `gmt blockmedian -R$region -I$rng/4 -bi3d -bo3d -r $V`, stdout="temp.rat"))
        if mode == 0
            open("tmp", "w") do io
                run(pipeline(`gmt surface temp.rat -R$region -I$rng/4 -bi3d -T$tension -N1000 -Gpixel.grd -r -Q`, stdout=io, stderr=io))
            end
            RR = grep_hint_slash("tmp")
            if isempty(RR)
                run(`gmt surface temp.rat -R$region -I$rng/4 -bi3d -T$tension -N1000 -Gpixel.grd -r $V`)
            else
                run(`gmt surface temp.rat $RR -I$rng/4 -bi3d -T$tension -N1000 -Gpixel.grd -r $V`)
                run(`gmt grdcut pixel.grd -R$region -Gtmp.grd`)
                mv("tmp.grd", "pixel.grd"; force=true)
            end
        elseif mode == 1
            rng2 = rng * 8
            run(`gmt triangulate temp.rat -R$region -I$rng/4 -bi3d -Gtopo_ra_tmp.grd -r $V`)
            run(pipeline(`gmt blockmean temp.rat -R$region -I$rng2/32 -bi3d -bo3d -r`, stdout="mean.rat"))
            run(`gmt surface mean.rat -R$region -I$rng2/32 -bi3d -T0.1 -N1000 -Gcoarse.grd -r`)
            run(`gmt grdfill topo_ra_tmp.grd -Agcoarse.grd -Gpixel.grd`)
            rm("topo_ra_tmp.grd"; force=true)
            rm("coarse.grd"; force=true)
            rm("mean.rat"; force=true)
        end
    end
    #
    # flip top to bottom for both ascending and descending passes
    #
    run(`gmt grdmath pixel.grd FLIPUD = topo_ra.grd`)

    #if ($#argv == 3) then
    #  set x0 = echo $region | awk -F'/' '{print $1}'
    #  set y0 = echo $region | awk -F'/' '{print $3}'
    #  set x1 = echo $region | awk -F'/' '{printf("%d",$1 - '$x0')}'
    #  set y1 = echo $region | awk -F'/' '{printf("%d",$3 - '$y0')}'
    #  gmt grdedit topo_ra.grd -R0/$x1/0/$y1
    #endif

    #
    # plotting
    #
    run(pipeline(`gmt grd2cpt topo_ra.grd -Cgray $V -Z`, stdout="topo_ra.cpt"))
    run(pipeline(`gmt grdimage topo_ra.grd $scale -P -Ctopo_ra.cpt -Bxaf+lRange -Byaf+lReversed\ Azimuth -BWSen $V -K`, stdout="topo_ra.ps"))
    open("topo_ra.ps", "a") do io
        run(pipeline(`gmt psscale -Rtopo_ra.grd -J -DJTC+w5i/0.2i+h -Ctopo_ra.cpt -Bxaf -By+lm -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z topo_ra.ps`)
    println("Topo range/azimuth map: topo_ra.pdf")
    #
    #  clean up
    #
    rm("pixel.grd"; force=true)
    rm("temp.rat"; force=true)
    rm("dem.xyz"; force=true)
    rm("tmp"; force=true)
    rm("topo_ra.cpt"; force=true)
end

main(ARGS)
