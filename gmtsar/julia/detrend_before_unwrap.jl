#!/usr/bin/env julia
#
# Original version: Eric Lindsey, May 2015
include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

using Printf

"""find the single subdirectory matching parent/*  (like `cd parent/*/`)"""
function glob_only_dir(parent::AbstractString)
    entries = sort(filter(f -> isdir(joinpath(parent, f)), readdir(parent)))
    return joinpath(parent, entries[1])
end

"""grep PATTERN dir/*MASTER*PRM | head -n1 | awk '{print \$3}'  -- first match across glob-sorted PRM files in dir containing MASTER in the name"""
function grep_field_glob(dir::AbstractString, master::AbstractString, pattern::AbstractString)
    files = sort(filter(f -> occursin(master, f) && endswith(f, "PRM"), readdir(dir)))
    for f in files
        for line in readlines(joinpath(dir, f))
            if occursin(pattern, line)
                return get(split(line), 3, "")
            end
        end
    end
    error("pattern not found: $pattern in $dir/*$master*PRM")
end

"""gmt grdinfo -I- FILE | sed -e 's:R:/:' | awk -F/ '{print \$N}'  -- Nth field of the -R string with the leading R replaced by /"""
function grdinfo_Ineg_field(file::AbstractString, n::Int)
    out = strip(read(`gmt grdinfo -I- $file`, String))
    replaced = replace(out, "R" => "/"; count=1)
    return split(replaced, "/")[n]
end

function main(argv::Vector{String})
    if length(argv) != 3
        println("  usage: detrend_before_unwrap.csh master #  bounds")
        println("  master is the stem name for the master image, eg. ALOS2040533050-150222-WBDR1.1__D")
        println("  # is the frame number (1-5) to use for detrending")
        println("  bounds (eg. 0/1000/0/1000) is the GMT bounds in range/az coordinates to use")
        exit(1)
    end

    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end

    # correlation threshold for the detrending
    corr_threshold = 0.2

    master = argv[1]

    # go to the selected frame directory
    cd(glob_only_dir("F$(argv[2])/intf"))

    if isfile("phasefilt_nodetrend.grd")
        mv("phasefilt_nodetrend.grd", "phasefilt.grd"; force=true)
    end

    # unwrap a part of the selected frame for detrending
    mkdir("detrend_part")
    cd("detrend_part")
    symlink("../corr.grd", "corr.grd")
    symlink("../mask.grd", "mask.grd")
    symlink("../phasefilt.grd", "phasefilt.grd")

    #
    ## convert to range(meters) / azimuth (seconds) coordinates before fitting the trend
    #
    #speed of light
    cee = 299792458.0

    # convert coordinates for each frame to absolute range and azimuth (time)
    #compute far range in meters
    #range_meters = near_range + i * speed_of_light/(2*rng_samp_rate)
    near_range = parse(Float64, grep_field_glob("..", master, "near_range"))
    rng_samp_rate = parse(Float64, grep_field_glob("..", master, "rng_samp_rate"))
    numrng = parse(Float64, grep_field_glob("..", master, "num_rng_bins"))
    far_range = @sprintf("%.14f", near_range + numrng * cee / (2.0 * rng_samp_rate))
    drng = @sprintf("%.14f", (parse(Float64, far_range) - near_range) / numrng)

    #compute start time relative to the start time of the selected frame, in seconds
    #azi_time(n,j) = (SC_clock_start(1) - SC_clock_start(n)) + j / PRF(n)
    numaz = parse(Float64, grep_field_glob("..", master, "num_lines"))
    PRF = parse(Float64, grep_field_glob("..", master, "PRF"))
    azi_start = "0.0"
    azi_end = @sprintf("%.14f", numaz / PRF)
    daz = @sprintf("%.14f", (parse(Float64, azi_end) - parse(Float64, azi_start)) / numaz)

    # unwrap the patch
    println("unwrap the selected region")
    #snaphu_interp_lindsey.csh $corr_threshold 0 $3
    run(`$GMTSAR_JULIA $(gmtsar_script("snaphu")) $corr_threshold 1 $(argv[3])`)

    rng_actual_min = grdinfo_Ineg_field("unwrap.grd", 2)
    rng_actual_max = grdinfo_Ineg_field("unwrap.grd", 3)
    az_actual_min = grdinfo_Ineg_field("unwrap.grd", 4)
    az_actual_max = grdinfo_Ineg_field("unwrap.grd", 5)

    near_range_crop = @sprintf("%.6g", near_range + parse(Float64, rng_actual_min) * parse(Float64, drng))
    far_range_crop = @sprintf("%.6g", near_range + parse(Float64, rng_actual_max) * parse(Float64, drng))
    azi_start_crop = @sprintf("%.6g", parse(Float64, azi_start) + parse(Float64, az_actual_min) * parse(Float64, daz))
    azi_end_crop = @sprintf("%.6g", parse(Float64, azi_start) + parse(Float64, az_actual_max) * parse(Float64, daz))

    # edit the coordinates
    println("edit unwrap.grd coordinates to -R$near_range_crop/$far_range_crop/$azi_start_crop/$azi_end_crop")
    run(`gmt grdedit unwrap.grd -R$near_range_crop/$far_range_crop/$azi_start_crop/$azi_end_crop`)
    run(pipeline(`gmt grd2xyz unwrap.grd -S`, stdout="unwrap.dat"))

    # compute the trend
    println("find the trend from a simple 3-parameter inversion")
    params = split(strip(read(`fit_planar_trend.py unwrap.dat`, String)))
    mean = params[1]
    rslope = params[2]
    aslope = params[3]
    println("found trend parameters (mean, range, az) $mean, $rslope, $aslope")

    SC_clock_start0 = parse(Float64, grep_field_glob("..", master, "SC_clock_start"))

    #back to top directory
    cd("../../../../")

    for n in 1:5
        cd(glob_only_dir("F$n/intf"))
        println("detrending F$n")
        if isfile("phasefilt_nodetrend.grd")
            #don't detrend something that was already detrended
            mv("phasefilt_nodetrend.grd", "phasefilt.grd"; force=true)
        end
        mv("phasefilt.grd", "phasefilt_nodetrend.grd"; force=true)

        # convert coordinates for each frame to absolute range and azimuth (time)
        #compute far range in meters:  range_meters = near_range + i * (rng_samp_rate)/(2*C)
        near_range = parse(Float64, grep_field_glob(".", master, "near_range"))
        rng_samp_rate = parse(Float64, grep_field_glob(".", master, "rng_samp_rate"))
        numrng = parse(Float64, grep_field_glob(".", master, "num_rng_bins"))
        far_range = @sprintf("%.14f", near_range + numrng * cee / (2.0 * rng_samp_rate))

        #compute start time relative to the start time of the selected frame, in seconds
        SC_clock_start = parse(Float64, grep_field_glob(".", master, "SC_clock_start"))
        numaz = parse(Float64, grep_field_glob(".", master, "num_lines"))
        PRF = parse(Float64, grep_field_glob(".", master, "PRF"))
        azi_start = @sprintf("%.14f", 86400.0 * (SC_clock_start - SC_clock_start0))
        azi_end = @sprintf("%.14f", 86400.0 * (SC_clock_start - SC_clock_start0) + numaz / PRF)

        # edit the coordinates
        println("edit coordinates to -R$near_range/$far_range/$azi_start/$azi_end")
        run(`gmt grdedit phasefilt_nodetrend.grd -R$near_range/$far_range/$azi_start/$azi_end`)

        # subtract the fitted trend
        run(`gmt grdmath $V phasefilt_nodetrend.grd X $rslope MUL SUB Y $aslope MUL SUB 2 PI MUL MOD PI SUB = phasefilt.grd`)

        # edit the coordinates back
        run(`gmt grdedit phasefilt.grd -Rcorr.grd`)
        run(`gmt grdedit phasefilt_nodetrend.grd -Rcorr.grd`)

        #geocode again if it was done before
        if isfile("phasefilt_mask_ll.grd")
            println("redoing geocoding of phasefilt")
            run(`gmt grdmath phasefilt.grd mask2.grd MUL = phasefilt_mask.grd`)
            run(`$GMTSAR_JULIA $(gmtsar_script("proj_ra2ll")) trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd`)
            run(`$GMTSAR_JULIA $(gmtsar_script("grd2kml")) phasefilt_mask_ll phase.cpt`)
        end

        cd("../../../")
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
