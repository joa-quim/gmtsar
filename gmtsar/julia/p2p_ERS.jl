#!/usr/bin/env julia
#       $Id$
#
#  Matt Wei, May 2010
#   based on Xiaopeng Tong, Feb 10, 2010
#
# Automatically process a single frame of interferogram.
# see instruction.txt for details.
#
# alias rm 'rm -f'
# unset noclobber
#

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    error("pattern not found: $pattern in $file")
end

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
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""s[start:(start+len-1)]"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start+len-1)]

function main(argv::Vector{String})
    if length(argv) < 3
        println()
        println("Usage: p2p_ERS.csh master_stem aligned_stem configuration_file")
        println()
        println("Example: p2p_ERS.csh ERS_127_2943_61103 ERS2_127_2943_65111 config.ers.txt")
        println()
        println("         Place the raw data in a directory called raw and a dem.grd file in ")
        println("         a parallel directory called topo.  The raw data should have 4 files ")
        println("         - two with a suffix of .dat and two with a suffix of .ldr. ")
        println("         Execute this command at the directory location above raw and topo. ")
        println("         The file dem.grd is a dem that completely covers the SAR frame - larger is OK.")
        println("         If the dem is omitted then an interferogram will still be created")
        println("         but there will not be geocoded output.")
        println("         A custom dem.grd can be made at the web site http://topex.ucsd.edu/gmtsar")
        println()
        exit(1)
    end

    # start

    #
    #   make sure the files exist
    #
    if !isfile(argv[3])
        println(" no configure file: ", argv[3])
        exit(0)
    end
    #
    # read parameters from configuration file
    #
    config = argv[3]
    stage = grep_field_opt(config, "proc_stage")
    near_range = grep_field_opt(config, "near_range")
    if near_range == ""
        near_range = "0"
    end
    earth_radius = grep_field_opt(config, "earth_radius")
    if earth_radius == ""
        earth_radius = "0"
    end
    npatch = grep_field_opt(config, "num_patches")
    if npatch == ""
        npatch = "0"
    end
    fd = grep_field_opt(config, "fd1")
    topo_phase = grep_field_opt(config, "topo_phase")
    shift_topo = grep_field_opt(config, "shift_topo")
    switch_master = grep_field_opt(config, "switch_master")
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
    println(filter)
    dec = grep_field_opt(config, "dec_factor")
    threshold_snaphu = grep_field_opt(config, "threshold_snaphu")
    threshold_geocode = grep_field_opt(config, "threshold_geocode")
    region_cut = grep_field_opt(config, "region_cut")
    switch_land = grep_field_opt(config, "switch_land")
    defomax = grep_field_opt(config, "defomax")
    near_interp = grep_field_opt(config, "near_interp")
    mask_water = grep_field_opt(config, "mask_water")

    #
    # read file names of raw data
    #
    master = argv[1]
    aligned = argv[2]

    local ref, rep
    if switch_master == "0"
        ref = master
        rep = aligned
    elseif switch_master == "1"
        ref = aligned
        rep = master
    else
        println("Wrong paramter: switch_master ", switch_master)
    end
    #
    # make working directories
    #
    mkpath("intf")
    mkpath("SLC")

    #############################
    # 1 - start from preprocess #
    #############################

    if stage == "1"
        #
        # first clean up
        #
        run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) raw`)
        #
        # preprocess the raw data
        #
        println("")
        println(" PREPROCESS ERS DATA  -- START")
        cd("raw") do
            run(`ERS_pre_process $master $near_range $earth_radius $npatch $fd`)
            NEAR = grep_field("$master.PRM", "near_range")
            RAD = grep_field("$master.PRM", "earth_radius")
            run(`ERS_pre_process $aligned $NEAR $RAD $npatch $fd`)
            #
            #   check patch number, if different, use the smaller one
            #
            pch1 = grep_field_int("$master.PRM", "patch")
            pch2 = grep_field_int("$aligned.PRM", "patch")
            println("Different number of patches: $pch1 $pch2")
            if pch1 != pch2
                if pch1 < pch2
                    run(`update_PRM $aligned.PRM num_patches $pch1`)
                    println("Number of patches is set to $pch1")
                else
                    run(`update_PRM $master.PRM num_patches $pch2`)
                    println("Number of patches is set to $pch2")
                end
            end
            #
            #   set the Doppler to be the average of the two
            #
            fd1_m = parse(Float64, grep_field("$master.PRM", "fd1"))
            fd1_a = parse(Float64, grep_field("$aligned.PRM", "fd1"))
            fda = (fd1_m + fd1_a) / 2.0
            println(" use average Doppler $fda ")
            run(`update_PRM $master.PRM fd1 $fda`)
            run(`update_PRM $aligned.PRM fd1 $fda`)
        end
        println(" PREPROCESS ERS DATA  -- END")
    end

    #############################################
    # 2 - start from focus and align SLC images #
    #############################################

    if parse(Int, stage) <= 2
        #
        # clean up
        #
        run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) SLC`)
        #
        # focus and align SLC files
        #
        println(" ")
        println("ALIGN.CSH - START")
        cd("SLC") do
            for f in readdir(joinpath("..", "raw"))
                if endswith(f, ".PRM")
                    cp(joinpath("..", "raw", f), f; force=true)
                end
            end
            symlink(joinpath("..", "raw", "$master.raw"), "$master.raw")
            symlink(joinpath("..", "raw", "$aligned.raw"), "$aligned.raw")
            symlink(joinpath("..", "raw", "$master.LED"), "$master.LED")
            symlink(joinpath("..", "raw", "$aligned.LED"), "$aligned.LED")
            run(`$GMTSAR_JULIA $(gmtsar_script("align")) SAT $master $aligned`)
        end
        println("ALIGN.CSH - END")
    end

    ##################################
    # 3 - start from make topo_ra  #
    ##################################

    if parse(Int, stage) <= 3
        #
        # clean up
        #
        run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) topo`)
        #
        # make topo_ra if there is a dem.grd
        #
        if topo_phase == "1"
            println(" ")
            println(" DEM2TOPOP_RA.CSH - START ")
            println(" USER SHOULD PROVIDE DEM FILE")
            cd("topo") do
                cp(joinpath("..", "SLC", "$master.PRM"), "master.PRM"; force=true)
                symlink(joinpath("..", "raw", "$master.LED"), "$master.LED")
                if isfile("dem.grd")
                    run(`$GMTSAR_JULIA $(gmtsar_script("dem2topo_ra")) master.PRM dem.grd`)
                else
                    println("no DEM file found: ", " dem.grd")
                    exit(1)
                end
            end
            println("DEM2TOPO_RA.CSH - END")
            #
            # shift topo_ra
            #
            if shift_topo == "1"
                println(" ")
                println("OFFSET_TOPO - START")
                cd("SLC") do
                    run(`$GMTSAR_JULIA $(gmtsar_script("slc2amp")) $master.PRM 1 amp-$master.grd`)
                end
                cd("topo") do
                    symlink(joinpath("..", "SLC", "amp-$master.grd"), "amp-$master.grd")
                    run(`offset_topo amp-$master.grd topo_ra.grd 0 0 11 topo_shift.grd`)
                end
                println("OFFSET_TOPO - END")
            elseif shift_topo == "0"
                println("NO TOPO_RA SHIFT ")
            else
                println("Wrong paramter: shift_topo ", shift_topo)
                exit(1)
            end

        elseif topo_phase == "0"
            println("NO TOPO_RA IS SUBSTRACTED")
        else
            println("Wrong paramter: topo_phase ", topo_phase)
            exit(1)
        end
    end

    ##################################################
    # 4 - start from make and filter interferograms  #
    ##################################################

    if parse(Int, stage) <= 4
        #
        # clean up
        #
        run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) intf`)
        #
        # make interferogram
        #
        println(" ")
        println("INTF.CSH, FILTER.CSH - START")
        cd("intf") do
            ref_id = grep_field_int(joinpath("..", "raw", "$master.PRM"), "SC_clock_start")
            rep_id = grep_field_int(joinpath("..", "raw", "$aligned.PRM"), "SC_clock_start")
            pairdir = "$(ref_id)_$(rep_id)"
            mkpath(pairdir)
            cd(pairdir) do
                symlink(joinpath("..", "..", "raw", "$ref.LED"), "$ref.LED")
                symlink(joinpath("..", "..", "raw", "$rep.LED"), "$rep.LED")
                symlink(joinpath("..", "..", "SLC", "$ref.SLC"), "$ref.SLC")
                symlink(joinpath("..", "..", "SLC", "$rep.SLC"), "$rep.SLC")
                cp(joinpath("..", "..", "SLC", "$ref.PRM"), "$ref.PRM"; force=true)
                cp(joinpath("..", "..", "SLC", "$rep.PRM"), "$rep.PRM"; force=true)

                if topo_phase == "1"
                    if shift_topo == "1"
                        symlink(joinpath("..", "..", "topo", "topo_shift.grd"), "topo_shift.grd")
                        run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM -topo topo_shift.grd`)
                        run(`$GMTSAR_JULIA $(gmtsar_script("filter")) $ref.PRM $rep.PRM $filter $dec`)
                    else
                        symlink(joinpath("..", "..", "topo", "topo_ra.grd"), "topo_ra.grd")
                        run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM -topo topo_ra.grd`)
                        run(`$GMTSAR_JULIA $(gmtsar_script("filter")) $ref.PRM $rep.PRM $filter $dec`)
                    end
                else
                    run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM`)
                    run(`$GMTSAR_JULIA $(gmtsar_script("filter")) $ref.PRM $rep.PRM $filter $dec`)
                end
            end
        end
        println("INTF.CSH, FILTER.CSH - END")
    end

    ################################
    # 5 - start from unwrap phase  #
    ################################

    if parse(Int, stage) <= 5
        if parse(Float64, threshold_snaphu) != 0
            cd("intf") do
                ref_id = grep_field_int(joinpath("..", "SLC", "$master.PRM"), "SC_clock_start")
                rep_id = grep_field_int(joinpath("..", "SLC", "$aligned.PRM"), "SC_clock_start")
                pairdir = "$(ref_id)_$(rep_id)"
                cd(pairdir) do
                    if region_cut == ""
                        info = chomp(read(`gmt grdinfo phase.grd -I-`, String))
                        region_cut = substr(info, 3, 18)
                    end

                    #
                    # landmask
                    #
                    if mask_water == "1" || switch_land == "1"
                        cd(joinpath("..", "..", "topo")) do
                            if !isfile("landmask_ra.grd")
                                run(`$GMTSAR_JULIA $(gmtsar_script("landmask")) $region_cut`)
                            end
                        end
                        symlink(joinpath("..", "..", "topo", "landmask_ra.grd"), "landmask_ra.grd")
                    end
                    println(" ")
                    println("SNAPHU.CSH - START")
                    println("threshold_snaphu: $threshold_snaphu")

                    if near_interp == "1"
                        run(`$GMTSAR_JULIA $(gmtsar_script("snaphu_interp")) $threshold_snaphu $defomax $region_cut`)
                    else
                        run(`$GMTSAR_JULIA $(gmtsar_script("snaphu")) $threshold_snaphu $defomax $region_cut`)
                    end

                    println("SNAPHU.CSH - END")
                end
            end
        else
            println("")
            println("SKIP UNWRAP PHASE")
        end
    end

    ###########################
    # 6 - start from geocode  #
    ###########################

    if parse(Int, stage) <= 6
        cd("intf") do
            ref_id = grep_field_int(joinpath("..", "SLC", "$master.PRM"), "SC_clock_start")
            rep_id = grep_field_int(joinpath("..", "SLC", "$aligned.PRM"), "SC_clock_start")
            pairdir = "$(ref_id)_$(rep_id)"
            cd(pairdir) do
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

    # end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
