#!/usr/bin/env julia
#       $Id$
#
# Loop through a list of interferometry pairs
# modified from process2pass.csh
#

# alias rm 'rm -f'
# unset noclobber

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd field, or "" if no match (mirrors csh set-from-empty-backquote)"""
function grep_field_opt(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    return ""
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    v = grep_field_opt(file, pattern)
    v == "" && error("pattern not found: $pattern in $file")
    return trunc(Int, parse(Float64, v))
end

"""cmd | awk '{print \$n}'  -- nth whitespace field of cmd's first output line"""
function cmd_field(cmd::Cmd, n::Int)
    out = read(cmd, String)
    line = split(out, '\n')[1]
    return split(line)[n]
end

"""s[start:(start+len-1)]"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start+len-1)]

function main(argv::Vector{String})
    #
    if length(argv) != 3
        println()
        println("Usage: intf_batch_ALOS2_SCAN.csh SAT intf.in batch.config")
        println("  make a stack of interferograms listed in intf.in")
        println()
        println(" SAT can only be ALOS ")
        println()
        println(" format for intf.in:")
        println("     reference1_name:repeat1_name")
        println("     reference2_name:repeat2_name")
        println("     reference3_name:repeat3_name")
        println("     ......")
        println()
        println(" Example of intf.in for ALOS2 ScanSAR")
        println("    IMG-HH-ALOS2101532950-160409-WBDR1.1__D:IMG-HH-ALOS2149142950-170225-WBDR1.1__D")
        println("    IMG-HH-ALOS2101532950-160409-WBDR1.1__D:IMG-HH-ALOS2155352950-170408-WBDR1.1__D")
        println()
        println(" batch.alos2.config is a config file for making interferograms")
        println(" See example.batch.config for an example")
        println()
        exit(1)
    end

    SAT = argv[1]
    if SAT != "ALOS"
        println()
        println(" SAT can only be ALOS ")
        println()
        exit(1)
    end
    #
    # make sure the file exsit
    #
    if !isfile(argv[2])
        println("no input file:", " ", argv[2])
        exit(0)
    end
    if !isfile(argv[3])
        println("no config file:", " ", argv[3])
        exit(0)
    end
    #
    # read parameters from configuration file
    #
    config = argv[3]
    stage = grep_field_opt(config, "proc_stage")
    local master
    if SAT == "ALOS"
        master_raw = grep_field_opt(config, "master_image")
        master = master_raw == "" ? "" : substr(master_raw, 8, length(master_raw) - 7)
    end

    if master == ""
        println()
        println("master image not set.")
        println()
        exit(1)
    end
    #
    # if filter wavelength is not set then use a default of 200m
    #
    filter = grep_field_opt(config, "filter_wavelength")
    if filter == ""
        filter = "200"
        println(" ")
        println("WARNING filter wavelength was not set in config.txt file")
        println("        please specify wavelength (e.g., filter_wavelength = 200)")
        println("        remove filter1 = gauss_alos_200m")
    end
    dec = grep_field_opt(config, "dec_factor")
    topo_phase = grep_field_opt(config, "topo_phase")
    shift_topo = grep_field_opt(config, "shift_topo")
    threshold_snaphu = grep_field_opt(config, "threshold_snaphu")
    threshold_geocode = grep_field_opt(config, "threshold_geocode")
    switch_land = grep_field_opt(config, "switch_land")
    defomax = grep_field_opt(config, "defomax")
    range_dec = grep_field_opt(config, "range_dec")
    azimuth_dec = grep_field_opt(config, "azimuth_dec")
    near_interp = grep_field_opt(config, "near_interp")
    mask_water = grep_field_opt(config, "mask_water")
    #
    # loop over 5 subswath
    #
    for subswath in 1:5
        mkpath("F$subswath")
        region_cut = grep_field_opt(config, "region_cut")
        cd("F$subswath") do
            mkpath("topo")

            ##################################
            # 1 - start from make topo_ra  #
            ##################################

            if parse(Int, stage) <= 1
                #
                # clean up
                #
                run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) topo`)
                #
                # make topo_ra
                #
                if topo_phase == "1"
                    println(" ")
                    println("DEM2TOPOPHASE.CSH - START")
                    println("USER SHOULD PROVIDE DEM FILE")
                    cd("topo") do
                        if SAT == "ALOS"
                            cp(joinpath("..", "SLC", "IMG-HH-$master-F$subswath.PRM"), "master.PRM"; force=true)
                            symlink(joinpath("..", "SLC", "IMG-HH-$master-F$subswath.LED"), "IMG-HH-$master-F$subswath.LED")
                        end
                        if isfile(joinpath("..", "..", "topo", "dem.grd"))
                            symlink(joinpath("..", "..", "topo", "dem.grd"), "dem.grd")
                            run(`$GMTSAR_JULIA $(gmtsar_script("dem2topo_ra_ALOS2")) master.PRM dem.grd`)
                        else
                            println("no DEM file found: ", " dem.grd")
                            exit(1)
                        end
                    end
                    println("DEM2TOPOPHASE.CSH - END")
                    #
                    # shift topo_ra
                    #
                    if shift_topo == "1"
                        println(" ")
                        println("OFFSET_TOPO - START")
                        cd("SLC") do
                            if SAT == "ALOS"
                                rng_samp_rate_s = grep_field_opt("IMG-HH-$master-F$subswath.PRM", "rng_samp_rate")
                                local rng
                                if rng_samp_rate_s != ""
                                    rng_samp_rate = trunc(Int, parse(Float64, rng_samp_rate_s))
                                    if rng_samp_rate > 25000000
                                        println("processing ALOS FBS data")
                                        rng = 2
                                    else
                                        println("processing ALOS FBD data")
                                        rng = 1
                                    end
                                    run(`$GMTSAR_JULIA $(gmtsar_script("slc2amp")) IMG-HH-$master-F$subswath.PRM $rng amp-$master.grd`)
                                else
                                    println("Undefined rng_samp_rate in the master PRM file")
                                    exit(1)
                                end
                            elseif SAT == "ERS" || SAT == "ENVI"
                                run(`$GMTSAR_JULIA $(gmtsar_script("slc2amp")) $master.PRM 1 amp-$master.grd`)
                            end
                        end
                        cd("topo") do
                            symlink(joinpath("..", "SLC", "amp-$master.grd"), "amp-$master.grd")
                            run(`offset_topo amp-$master.grd topo_ra.grd 0 0 7 topo_shift.grd`)
                        end
                        println("OFFSET_TOPO - END")
                    elseif shift_topo == "0"
                        println("NO TOPOPHASE SHIFT ")
                    else
                        println("Wrong paramter: shift_topo ", shift_topo)
                        exit(1)
                    end

                elseif topo_phase == "0"
                    println("NO TOPOPHASE IS SUBSTRACTED")
                else
                    println("Wrong paramter: topo_phase ", topo_phase)
                    exit(1)
                end
            end # stage 1

            ##################################################
            # 2 - start from make and filter interferograms  #
            #                unwrap phase and geocode        #
            ##################################################

            if parse(Int, stage) <= 2
                #
                # make working directories
                #
                println("")
                println("START FORM A STACK OF INTERFEROGRAMS")

                mkpath("intf")
                symlink(joinpath("..", argv[2]), argv[2])
                #
                # loop over intf.in
                #
                for line in readlines(argv[2])
                    words = split(line)
                    isempty(words) && continue
                    lineval = words[1]

                    if SAT == "ALOS"
                        parts = split(lineval, ":")
                        ref = substr(parts[1], 8, length(parts[1]) - 7)
                        rep = substr(parts[2], 8, length(parts[2]) - 7)

                        ref_id = grep_field_int(joinpath(".", "SLC", "IMG-HH-$ref-F$subswath.PRM"), "SC_clock_start")
                        rep_id = grep_field_int(joinpath(".", "SLC", "IMG-HH-$rep-F$subswath.PRM"), "SC_clock_start")

                        println("")
                        println("INTF.CSH, FILTER.CSH - START")
                        cd("intf") do
                            pairdir = "$(ref_id)_$(rep_id)"
                            rm(pairdir; force=true, recursive=true)
                            mkpath(pairdir)
                            cd(pairdir) do
                                symlink(joinpath("..", "..", "SLC", "IMG-HH-$ref-F$subswath.LED"), "IMG-HH-$ref-F$subswath.LED")
                                symlink(joinpath("..", "..", "SLC", "IMG-HH-$rep-F$subswath.LED"), "IMG-HH-$rep-F$subswath.LED")
                                symlink(joinpath("..", "..", "SLC", "IMG-HH-$ref-F$subswath.SLC"), "IMG-HH-$ref-F$subswath.SLC")
                                symlink(joinpath("..", "..", "SLC", "IMG-HH-$rep-F$subswath.SLC"), "IMG-HH-$rep-F$subswath.SLC")
                                cp(joinpath("..", "..", "SLC", "IMG-HH-$ref-F$subswath.PRM"), "IMG-HH-$ref-F$subswath.PRM"; force=true)
                                cp(joinpath("..", "..", "SLC", "IMG-HH-$rep-F$subswath.PRM"), "IMG-HH-$rep-F$subswath.PRM"; force=true)

                                if SAT == "ALOS"
                                    if topo_phase == "1"
                                        if shift_topo == "1"
                                            symlink(joinpath("..", "..", "topo", "topo_shift.grd"), "topo_shift.grd")
                                            run(`$GMTSAR_JULIA $(gmtsar_script("intf")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM -topo topo_shift.grd`)
                                            run(`$GMTSAR_JULIA $(gmtsar_script("filter")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM $filter $dec $range_dec $azimuth_dec`)
                                        else
                                            symlink(joinpath("..", "..", "topo", "topo_ra.grd"), "topo_ra.grd")
                                            run(`$GMTSAR_JULIA $(gmtsar_script("intf")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM -topo topo_ra.grd`)
                                            run(`$GMTSAR_JULIA $(gmtsar_script("filter")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM $filter $dec $range_dec $azimuth_dec`)
                                        end
                                    else
                                        run(`$GMTSAR_JULIA $(gmtsar_script("intf")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM`)
                                        run(`$GMTSAR_JULIA $(gmtsar_script("filter")) IMG-HH-$ref-F$subswath.PRM IMG-HH-$rep-F$subswath.PRM $filter $dec $range_dec $azimuth_dec`)
                                    end
                                end
                                println("INTF.CSH, FILTER.CSH - END")

                                if region_cut == ""
                                    info = chomp(read(`gmt grdinfo phase.grd -I-`, String))
                                    region_cut = substr(info, 3, 18)
                                    rs = cmd_field(`gmt grdinfo phase.grd -C`, 2)
                                    re_field = cmd_field(`gmt grdinfo phase.grd -C`, 3)
                                    re_val = parse(Float64, re_field) - 16
                                    re = re_val == round(re_val) ? string(Int(round(re_val))) : string(re_val)
                                    as_ = cmd_field(`gmt grdinfo phase.grd -C`, 4)
                                    ae = cmd_field(`gmt grdinfo phase.grd -C`, 5)
                                    region_cut = "$rs/$re/$as_/$ae"
                                end

                                if parse(Float64, threshold_snaphu) != 0
                                    if mask_water == "1" || switch_land == "1"
                                        cd(joinpath("..", "..", "topo")) do
                                            if !isfile("landmask_ra.grd")
                                                run(`$GMTSAR_JULIA $(gmtsar_script("landmask_ALOS2")) $region_cut`)
                                            end
                                        end
                                        symlink(joinpath("..", "..", "topo", "landmask_ra.grd"), "landmask_ra.grd")
                                    end

                                    println("")
                                    println("SNAPHU.CSH - START")
                                    println("threshold_snaphu: $threshold_snaphu")
                                    if near_interp == "1"
                                        run(`$GMTSAR_JULIA $(gmtsar_script("snaphu_interp")) $threshold_snaphu $defomax $region_cut`)
                                    else
                                        run(`$GMTSAR_JULIA $(gmtsar_script("snaphu")) $threshold_snaphu $defomax $region_cut`)
                                    end
                                    println("SNAPHU.CSH - END")

                                else
                                    println("")
                                    println("SKIP UNWRAP PHASE")
                                end

                                println(" ")
                                println("GEOCODE.CSH - START")
                                rm("raln.grd"; force=true)
                                rm("ralt.grd"; force=true)
                                if topo_phase == "1"
                                    rm("trans.dat"; force=true)
                                    symlink(joinpath("..", "..", "topo", "trans.dat"), "trans.dat")
                                    println("threshold_geocode: $threshold_geocode")
                                    run(`$GMTSAR_JULIA $(gmtsar_script("geocode")) $threshold_geocode`)
                                else
                                    println("topo_ra is needed to geocode")
                                    exit(1)
                                end
                                println("GEOCODE.CSH - END")
                            end
                        end
                    end
                end # loop of foreach
            end # stage 2
        end
        # end of subswath loop
    end

    println("")
    println("END FORM A STACK OF INTERFEROGRAMS")
    println("")
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
