#!/usr/bin/env julia
#       $Id$
#
#
#    Xiaohua(Eric) XU, July 7, 2016
#
# Script for merging 3 subswaths TOPS interferograms and then unwrap and geocode.
#

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field, "" if none"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    return ""
end

"""grep PATTERN file | tail -1 | awk '{print \$3}'  -- last matching line's 3rd whitespace field, "" if none"""
function grep_field_last(file::AbstractString, pattern::AbstractString)
    result = ""
    for line in eachline(file)
        if occursin(pattern, line)
            result = split(line)[3]
        end
    end
    return result
end

"""grep PATTERN *.suffix | awk '{print(\$3)}' | head -1  -- first match across glob-sorted files"""
function grep_glob_field_first(pattern::AbstractString, suffix::AbstractString)
    files = sort(filter(f -> endswith(f, suffix), readdir(".")))
    for f in files
        for line in eachline(f)
            if occursin(pattern, line)
                return split(line)[3]
            end
        end
    end
    return ""
end

"""run cmd, return the nth whitespace field of its stdout (first line)"""
function cmd_field(cmd::Cmd, n::Int)
    out = read(cmd, String)
    return split(out)[n]
end

"""cut -c first-last (1-indexed, clipped to available length, first line only)"""
function cut_c(s::AbstractString, first::Int, last::Int)
    line0 = split(s, '\n')[1]
    length(line0) < first && return ""
    return line0[first:min(last, length(line0))]
end

function main(argv::Vector{String})
    if length(argv) != 2 && length(argv) != 3
        println()
        println("Usage: merge_unwrap_geocode_tops.jl inputfile config_file [det_stitch]")
        println()
        println("Note: Inputfiles should be as following:")
        println()
        println("      Swath1_Path:Swath1_master.PRM:Swath1_repeat.PRM")
        println("      Swath2_Path:Swath2_master.PRM:Swath2_repeat.PRM")
        println("      Swath3_Path:Swath3_master.PRM:Swath3_repeat.PRM")
        println("      (Use the repeat PRM which contains the shift information.)")
        println("      e.g. ../F1/intf/2015016_2015030/:S1A20151012_134357_F1.PRM")
        println()
        println("      Make sure under each path, the processed phasefilt.grd, corr.grd and mask.grd exist.")
        println("      Also make sure the dem.grd is linked. ")
        println()
        println("      config_file is the same one used for processing.")
        println()
        println("      set det_stitch to 1 if you want to calculate stitching position based on the NaN area in the grids")
        println()
        println("Example: merge_unwrap_geocode_tops.jl filelist batch.config")
        println()
        exit(1)
    end

    inputfile = argv[1]
    configfile = argv[2]

    isfile("tmp_phaselist") && rm("tmp_phaselist"; force=true)
    isfile("tmp_corrlist") && rm("tmp_corrlist"; force=true)
    isfile("tmp_masklist") && rm("tmp_masklist"; force=true)

    if !isfile("dem.grd")
        println("Please link dem.grd to current folder")
        exit(1)
    end

    local det_stitch, n1, n2
    if length(argv) == 3
        det_stitch = argv[3]
        n1 = "0"
        n2 = "0"
    else
        det_stitch = "0"
        n1 = ""
        n2 = ""
    end

    region_cut = grep_field(configfile, "region_cut")

    # Creating inputfiles for merging
    tokens = split(read(inputfile, String))
    for line in tokens
        pth, prm, prm2 = split(line, ":")
        cd(pth) do
            rshift = grep_field_last(prm2, "rshift")
            fs1 = grep_field(prm, "first_sample")
            fs2 = grep_field(prm2, "first_sample")
            cp(prm, "tmp.PRM"; force=true)
            if parse(Float64, fs2) > parse(Float64, fs1)
                run(`update_PRM tmp.PRM first_sample $fs2`)
            end
            run(`update_PRM tmp.PRM rshift $rshift`)
        end

        open("tmp_phaselist", "a") do io
            println(io, "$(pth)tmp.PRM:$(pth)phasefilt.grd")
        end
        open("tmp_corrlist", "a") do io
            println(io, "$(pth)tmp.PRM:$(pth)corr.grd")
        end
        open("tmp_masklist", "a") do io
            println(io, "$(pth)tmp.PRM:$(pth)mask.grd")
        end
    end

    all_lines = readlines(inputfile)
    pth = split(all_lines[1], ":")[1]
    stem = split(split(all_lines[1], ":")[2], ".")[1]
    #echo $pth $stem

    println()
    println("Merging START")
    if det_stitch == "1"
        println("Calculating valid starting columns of data ...")
        nl = length(all_lines)
        if nl == 2
            pth2 = split(all_lines[1], ":")[1]
            near1 = grep_field("$(pth2)tmp.PRM", "near")
            rng1 = grep_field("$(pth2)tmp.PRM", "num_rng_bins")
            fs = grep_field_last("$(pth2)tmp.PRM", "rng_samp_rate")
            run(`gmt grdcut $(pth2)phasefilt.grd -Z+N -Gtmp.grd`)
            xm1 = cmd_field(`gmt grdinfo $(pth2)phasefilt.grd -C`, 3)
            xc1 = cmd_field(`gmt grdinfo tmp.grd -C`, 3)
            incx = cmd_field(`gmt grdinfo tmp.grd -C`, 8)
            n12 = string(trunc(Int, (parse(Float64, xm1) - parse(Float64, xc1)) / parse(Float64, incx)))

            pth2 = split(all_lines[end], ":")[1]
            near2 = grep_field("$(pth2)tmp.PRM", "near")
            run(`gmt grdcut $(pth2)phasefilt.grd -Z+N -Gtmp.grd`)
            x01 = cmd_field(`gmt grdinfo tmp.grd -C`, 2)
            incx = cmd_field(`gmt grdinfo tmp.grd -C`, 8)
            n21 = string(trunc(Int, parse(Float64, x01) / parse(Float64, incx)))
            ovl12 = string(trunc(Int, (parse(Float64, rng1) - (parse(Float64, near2) - parse(Float64, near1)) / (299792458.0 / parse(Float64, fs) / 2)) / parse(Float64, incx)))
            n1 = string(trunc(Int, (parse(Float64, ovl12) - parse(Float64, n12) - parse(Float64, n21)) / 2 + parse(Float64, n21)))
            n2 = "0"
            if parse(Int, n1) <= 0
                println("WARNING: Stitching position estimated to be zero")
                println("Check merged grids carefully")
                n1 = ""
                n2 = ""
            end
            rm("tmp.grd"; force=true)
        elseif nl == 3
            pth2 = split(all_lines[1], ":")[1]
            near1 = grep_field("$(pth2)tmp.PRM", "near")
            rng1 = grep_field("$(pth2)tmp.PRM", "num_rng_bins")
            fs = grep_field_last("$(pth2)tmp.PRM", "rng_samp_rate")
            run(`gmt grdcut $(pth2)phasefilt.grd -Z+N -Gtmp.grd`)
            xm1 = cmd_field(`gmt grdinfo $(pth2)/phasefilt.grd -C`, 3)
            xc1 = cmd_field(`gmt grdinfo tmp.grd -C`, 3)
            incx = cmd_field(`gmt grdinfo tmp.grd -C`, 8)
            n12 = string(trunc(Int, (parse(Float64, xm1) - parse(Float64, xc1)) / parse(Float64, incx)))

            pth2 = split(all_lines[2], ":")[1]
            near2 = grep_field("$(pth2)tmp.PRM", "near")
            rng2 = grep_field("$(pth2)tmp.PRM", "num_rng_bins")
            run(`gmt grdcut $(pth2)phasefilt.grd -Z+N -Gtmp.grd`)
            x02 = cmd_field(`gmt grdinfo tmp.grd -C`, 2)
            incx = cmd_field(`gmt grdinfo tmp.grd -C`, 8)
            n21 = string(trunc(Int, parse(Float64, x02) / parse(Float64, incx)))
            ovl12 = string(trunc(Int, (parse(Float64, rng1) - (parse(Float64, near2) - parse(Float64, near1)) / (299792458.0 / parse(Float64, fs) / 2)) / parse(Float64, incx)))
            n1 = string(trunc(Int, (parse(Float64, ovl12) - parse(Float64, n12) - parse(Float64, n21)) / 2 + parse(Float64, n21)))
            xm2 = cmd_field(`gmt grdinfo $(pth2)/phasefilt.grd -C`, 3)
            xc2 = cmd_field(`gmt grdinfo tmp.grd -C`, 3)
            n22 = string(trunc(Int, (parse(Float64, xm2) - parse(Float64, xc2)) / parse(Float64, incx)))

            pth2 = split(all_lines[3], ":")[1]
            near3 = grep_field("$(pth2)tmp.PRM", "near")
            run(`gmt grdcut $(pth2)phasefilt.grd -Z+N -Gtmp.grd`)
            x03 = cmd_field(`gmt grdinfo tmp.grd -C`, 2)
            incx = cmd_field(`gmt grdinfo tmp.grd -C`, 8)
            n31 = string(trunc(Int, parse(Float64, x03) / parse(Float64, incx)))
            ovl23 = string(trunc(Int, (parse(Float64, rng2) - (parse(Float64, near3) - parse(Float64, near2)) / (299792458.0 / parse(Float64, fs) / 2)) / parse(Float64, incx)))
            n2 = string(trunc(Int, (parse(Float64, ovl23) - parse(Float64, n22) - parse(Float64, n31)) / 2 + parse(Float64, n22)))
            if parse(Int, n2) == 0
                println("WARNING: Stitching positions estimated to be zero")
                println("Check merged grids carefully")
                n1 = ""
                n2 = ""
            end
            rm("tmp.grd"; force=true)
        else
            println("Incorrect number of records in input filelist ..")
            exit(1)
        end
        println("Stitching postitions set to $n1 $n2")
    end

    # for two subswath (n1 >5, n2 =0), for three subswath (n1>5, n2>5) subswath merge with pixel offset computed from det_stich flag
    if parse(Int, n1) > 5
        run(pipeline(`merge_swath tmp_phaselist phasefilt.grd $stem $n1 $n2`, stdout="merge_log"))
        run(pipeline(`merge_swath tmp_corrlist corr.grd $n1 $n2`, stdout="merge_log_corr"))
        run(pipeline(`merge_swath tmp_masklist mask.grd $n1 $n2`, stdout="merge_log_mask"))
    else
        run(pipeline(`merge_swath tmp_phaselist phasefilt.grd $stem`, stdout="merge_log"))
        run(pipeline(`merge_swath tmp_corrlist corr.grd`, stdout="merge_log_corr"))
        run(pipeline(`merge_swath tmp_masklist mask.grd`, stdout="merge_log_mask"))
    end

    println("Merging END")
    println()

    iono = grep_field(configfile, "correct_iono")
    skip_iono = grep_field(configfile, "iono_skip_est")
    if (parse(Int, iono) != 0) & (parse(Int, skip_iono) == 0)
        if !isfile("ph_iono_orig.grd")
            println("Need ph_iono_orig.grd to correct ionosphere ...")
        else
            println("Correcting ionosphere ...")
            run(`gmt grdsample ph_iono_orig.grd -Rphasefilt.grd -Gtmp.grd`)
            run(`gmt grdmath phasefilt.grd tmp.grd SUB PI ADD 2 PI MUL MOD PI SUB = tmp2.grd`)
            mv("phasefilt.grd", "phasefilt_orig.grd"; force=true)
            mv("tmp2.grd", "phasefilt.grd"; force=true)
            rm("tmp.grd"; force=true)
        end
    end


    # This step is essential, cut the DEM so it can run faster.
    if !isfile("trans.dat")
        led = grep_field("$(pth)$(stem).PRM", "led_file")
        cp("$(pth)$led", led; force=true)
        println("Recomputing the projection LUT...")
        # Need to compute the geocoding matrix with supermaster.PRM with rshift set to 0
        rshift = grep_field_last("$(stem).PRM", "rshift")
        run(`update_PRM $(stem).PRM rshift 0`)
        open("trans.dat", "w") do io
            run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf dem.grd -s`, `SAT_llt2rat $(stem).PRM 1 -bod`, stdout=io))
        end
        # Set rshift back for other usage
        run(`update_PRM $(stem).PRM rshift $rshift`)
    end

    # Read in parameters
    threshold_snaphu = grep_field(configfile, "threshold_snaphu")
    threshold_geocode = grep_field(configfile, "threshold_geocode")
    region_cut = grep_field(configfile, "region_cut")
    switch_land = grep_field(configfile, "switch_land")
    defomax = grep_field(configfile, "defomax")
    near_interp = grep_field(configfile, "near_interp")
    mask_water = grep_field(configfile, "mask_water")

    # Unwrapping
    if region_cut == ""
        gi_out = read(`gmt grdinfo phasefilt.grd -I-`, String)
        region_cut = cut_c(gi_out, 3, 20)
    end
    if parse(Float64, threshold_snaphu) != 0
        if parse(Int, mask_water) == 1 || parse(Int, switch_land) == 1
            if !isfile("landmask_ra.grd")
                run(`landmask.csh $region_cut`)
            end
        end

        println()
        println("SNAPHU.CSH - START")
        println("threshold_snaphu: $threshold_snaphu")
        if parse(Int, near_interp) == 1
            run(`snaphu_interp.csh $threshold_snaphu $defomax $region_cut`)
        else
            run(`snaphu.csh $threshold_snaphu $defomax $region_cut`)
        end
        println("SNAPHU.CSH - END")
    else
        println()
        println("SKIP UNWRAP PHASE")
    end

    # Geocoding
    #if (-f raln.grd) rm raln.grd
    #if (-f ralt.grd) rm ralt.grd

    if parse(Float64, threshold_geocode) != 0
        println()
        println("GEOCODE-START")
        run(`proj_ra2ll.csh trans.dat phasefilt.grd phasefilt_ll.grd`)
        run(`gmt grdmath corr.grd $threshold_geocode GE 0 NAN mask.grd MUL = mask2.grd`)
        run(`gmt grdmath phasefilt.grd mask2.grd MUL = phasefilt_mask.grd`)
        run(`proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd`)
        run(`proj_ra2ll.csh trans.dat corr.grd corr_ll.grd`)
        open("phase.cpt", "w") do io
            run(pipeline(`gmt makecpt -Crainbow -T-3.15/3.15/0.05 -Z`, stdout=io))
        end
        BT = cmd_field(`gmt grdinfo -C corr.grd`, 7)
        open("corr.cpt", "w") do io
            run(pipeline(`gmt makecpt -Cgray -T0/$BT/0.05 -Z -M --COLOR_NAN=red`, stdout=io))
        end
        run(`grd2kml.csh phasefilt_ll phase.cpt`)
        run(`grd2kml.csh phasefilt_mask_ll phase.cpt`)
        run(`grd2kml.csh corr_ll corr.cpt`)

        if isfile("unwrap.grd")
            run(`gmt grdmath unwrap.grd mask2.grd MUL = unwrap_mask.grd`)
            wavel = grep_glob_field_first("wavelength", ".PRM")
            run(`gmt grdmath unwrap_mask.grd $wavel MUL -79.58 MUL = los.grd`)
            run(`proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd`)
            run(`proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd`)
            run(`proj_ra2ll.csh trans.dat los.grd los_ll.grd`)
            BT = cmd_field(`gmt grdinfo -C unwrap.grd`, 7)
            BL = cmd_field(`gmt grdinfo -C unwrap.grd`, 6)
            open("unwrap.cpt", "w") do io
                run(pipeline(`gmt makecpt -T$BL/$BT/0.5 -Z`, stdout=io))
            end
            run(`grd2kml.csh unwrap_mask_ll unwrap.cpt`)
            run(`grd2kml.csh unwrap_ll unwrap.cpt`)
            BT = cmd_field(`gmt grdinfo -C los.grd`, 7)
            BL = cmd_field(`gmt grdinfo -C los.grd`, 6)
            open("los.cpt", "w") do io
                run(pipeline(`gmt makecpt -T$BL/$BT/2 -Z`, stdout=io))
            end
            run(`grd2kml.csh los_ll los.cpt`)
        end

        println("GEOCODE END")
    end

    rm("tmp_phaselist"; force=true)
    rm("tmp_corrlist"; force=true)
    rm("tmp_masklist"; force=true)
    for f in readdir(".")
        if endswith(f, ".eps") || endswith(f, ".bb")
            rm(f; force=true)
        end
    end
end

main(ARGS)
