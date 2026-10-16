#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong, Feb 10, 2010
#
# Automatically process a single frame of interferogram.
# see instruction.txt for details.
#
# Modification History
#
# Xiaohua Xu, Oct 9, 2013
#
# Changed some code in Part 2 to make it work for one FBD and one FBS files.
#
# Xiaopeng Tong, Oct, 2016
#
# Add options to do subswaths
#

using Printf

# alias rm 'rm -f'
# unset noclobber

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd field, or "" if not found"""
function grep_field_opt(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    return ""
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""cp srcdir/*suffix .  (individual copy failures are reported, not fatal)"""
function glob_cp(srcdir::AbstractString, suffix::AbstractString)
    isdir(srcdir) || return
    for f in readdir(srcdir)
        if endswith(f, suffix)
            try
                cp(joinpath(srcdir, f), f; force=true)
            catch e
                println(stderr, "cp: $f: $e")
            end
        end
    end
end

"""awk-style substr(s,start,len), 1-indexed"""
function substr(s::AbstractString, start::Int, len::Int)
    return s[start:(start+len-1)]
end

function main(argv::Vector{String})
    if length(argv) != 4
        println("")
        println("Usage: p2p_ALOS2_SCAN_SLC.jl master_image aligned_image configuration_file subswatch")
        println("")
        println("Example: p2p_ALOS2_SCAN_SLC.jl IMG-HH-ALOS2047033500-150407-WBDR1.1__D IMG-HH-ALOS2100853500-160405-WBDR1.1__D config.alos2.slc.txt 1")
        println("")
        println("         Place the raw L1.1 data in a directory called raw and a dem.grd file in ")
        println("         a parallel directory called topo.  Execute this command at the directory")
        println("         location above raw and topo.  The file dem.grd")
        println("         is a dem that completely covers the SAR frame - larger is OK.")
        println("         If the dem is omitted then an interferogram will still be created")
        println("         but there will not be geocoded output.")
        println("         A custom dem.grd can be made at the web site http://topex.ucsd.edu/gmtsar")
        println("")
        println("")
        exit(1)
    end

    # start

    #
    #   make sure the files exist
    #
    if !isfile("raw/$(argv[1])-F$(argv[4])")
        println(" no file  raw/$(argv[1])-F$(argv[4])")
        exit(0)
    end
    if !isfile("raw/$(argv[2])-F$(argv[4])")
        println(" no file  raw/$(argv[2])-F$(argv[4])")
        exit(0)
    end
    if !isfile(argv[3])
        println(" no configure file: $(argv[3])")
        exit(0)
    end
    subswath = "F$(argv[4])"
    #
    # read parameters from configuration file
    #
    SAT = grep_field_opt(argv[3], "SAT")
    stage = grep_field_opt(argv[3], "proc_stage")
    num_patches = grep_field_opt(argv[3], "num_patches")
    SLC_factor = grep_field_opt(argv[3], "SLC_factor")
    earth_radius = grep_field_opt(argv[3], "earth_radius")
    topo_phase = grep_field_opt(argv[3], "topo_phase")
    shift_topo = grep_field_opt(argv[3], "shift_topo")
    switch_master = grep_field_opt(argv[3], "switch_master")
    #
    # if filter wavelength is not set then use a default of 300m
    #
    filter = grep_field_opt(argv[3], "filter_wavelength")
    if filter == ""
        filter = "300"
        println(" ")
        println("WARNING filter wavelength was not set in config.txt file")
        println("        please specify wavelength (e.g., filter_wavelength = 200)")
        println("        remove filter1 = gauss_alos_200m")
    end
    println(filter)
    dec = grep_field_opt(argv[3], "dec_factor")
    threshold_snaphu = grep_field_opt(argv[3], "threshold_snaphu")
    threshold_geocode = grep_field_opt(argv[3], "threshold_geocode")
    region_cut = grep_field_opt(argv[3], "region_cut")
    switch_land = grep_field_opt(argv[3], "switch_land")
    defomax = grep_field_opt(argv[3], "defomax")
    near_interp = grep_field_opt(argv[3], "near_interp")
    mask_water = grep_field_opt(argv[3], "mask_water")
    #
    # read file names of raw data
    #
    master = substr(argv[1], 5, length(argv[1]) - 4)
    aligned = substr(argv[2], 5, length(argv[2]) - 4)
    master_led = substr(argv[1], 8, length(argv[1]) - 7)
    aligned_led = substr(argv[2], 8, length(argv[2]) - 7)

    local ref, rep
    if parse(Int, switch_master) == 0
        ref = master
        rep = aligned
    elseif parse(Int, switch_master) == 1
        ref = aligned
        rep = master
    else
        println("Wrong paramter: switch_master $switch_master")
    end
    #
    # make working directories
    #
    mkpath(subswath)
    cd(subswath)
    mkpath("intf/")
    mkpath("SLC/")
    mkpath("topo/")
    cd("..")

    #############################
    # 1 - start from preprocess #
    #############################

    if parse(Int, stage) == 1
        #
        # first clean up
        #
        for f in readdir("raw")
            if occursin(".PRM", f)
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".SLC")
                rm(joinpath("raw", f); force=true)
            end
        end
        for f in readdir("raw")
            if endswith(f, ".LED")
                rm(joinpath("raw", f); force=true)
            end
        end
        #
        # preprocess the raw data
        #
        println(" ")
        println("PREPROCESS - START")
        cd("raw")
        commandline = ""
        if earth_radius != ""
            commandline = "$commandline -radius $earth_radius"
        end
        if num_patches != ""
            commandline = "$commandline -npatch $num_patches"
        end
        if SLC_factor != ""
            commandline = "$commandline -SLC_factor $SLC_factor"
        end

        println(commandline)
        #   ALOS_pre_process_SLC IMG-$master LED-$master_led $commandline -rbias -68.
        #   ALOS_pre_process_SLC IMG-$aligned LED-$aligned_led $commandline -rbias -68.
        run(`ALOS_pre_process_SLC IMG-$master-$subswath LED-$master_led $(split(commandline))`)
        run(`ALOS_pre_process_SLC IMG-$aligned-$subswath LED-$aligned_led $(split(commandline))`)

        #
        # special code to filter the SLC data in range does not seem to work
        #
        cd("..")
        println("PREPROCESS.CSH - END")
    end

    #############################################
    # 2 - start from focus and align SLC images #
    #############################################

    if parse(Int, stage) <= 2
        #
        # clean up
        #
        cd(subswath)
        run(`cleanup.csh SLC`)
        #
        # align SLC images
        #
        println(" ")
        println("ALIGN - START")
        cd("SLC")
        glob_cp("../../raw", ".PRM")
        symlink("../../raw/IMG-$master-$subswath.SLC", "IMG-$master-$subswath.SLC")
        symlink("../../raw/IMG-$aligned-$subswath.SLC", "IMG-$aligned-$subswath.SLC")
        symlink("../../raw/IMG-$master-$subswath.LED", "IMG-$master-$subswath.LED")
        symlink("../../raw/IMG-$aligned-$subswath.LED", "IMG-$aligned-$subswath.LED")


        # if images do not match, convert the FBD image to FBS
        rng_samp_rate_m = grep_field_int("IMG-$master-$subswath.PRM", "rng_samp_rate")
        rng_samp_rate_s = grep_field_int("IMG-$aligned-$subswath.PRM", "rng_samp_rate")
        t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)
        if t == "1.0"
            println("The range sampling rate for master and aligned images are: $rng_samp_rate_m")
        elseif t == "2.0"
            println("Convert the aligned image from FBD to FBS mode")
            run(`ALOS_fbd2fbs_SLC IMG-$aligned-$subswath.PRM IMG-$aligned-$(subswath)_FBS.PRM`)
            println("Overwriting the old aligned image")
            mv("IMG-$aligned-$(subswath)_FBS.PRM", "IMG-$aligned-$subswath.PRM"; force=true)
            run(`update_PRM IMG-$aligned-$subswath.PRM input_file IMG-$aligned-$subswath.SLC`)
            mv("IMG-$aligned-$(subswath)_FBS.SLC", "IMG-$aligned-$subswath.SLC"; force=true)
        elseif t == "0.5"
            println("Convert the master image from FBD to FBS mode")
            run(`ALOS_fbd2fbs_SLC IMG-$master-$subswath.PRM IMG-$master-$(subswath)_FBS.PRM`)
            println("Overwriting the old master image")
            mv("IMG-$master-$(subswath)_FBS.PRM", "IMG-$master-$subswath.PRM"; force=true)
            run(`update_PRM IMG-$master-$subswath.PRM input_file IMG-$master-$subswath.SLC`)
            mv("IMG-$master-$(subswath)_FBS.SLC", "IMG-$master-$subswath.SLC"; force=true)
        else
            println("The range sampling rate for master and aligned images are not convertable")
            exit(1)
        end

        cp("IMG-$aligned-$subswath.PRM", "IMG-$aligned-$subswath.PRM0"; force=true)
        open("IMG-$aligned-$subswath.PRM", "a") do io
            run(pipeline(`SAT_baseline IMG-$master-$subswath.PRM IMG-$aligned-$subswath.PRM0`, stdout=io))
        end
        #
        #  there is a bug in xcorr so xsearch and ysearch must be the same
        #
        #    xcorr IMG-$master.PRM IMG-$aligned.PRM -xsearch 128 -ysearch 128 -nx 64 -ny  256
        run(`xcorr IMG-$master-$subswath.PRM IMG-$aligned-$subswath.PRM -xsearch 32 -ysearch 256 -nx 32 -ny 128`)

        open("tmp.dat", "w") do io
            for line in eachline("freq_xcorr.dat")
                w = split(line)
                println(io, w[4])
            end
        end
        tmp_vals = Float64[]
        for line in eachline("tmp.dat")
            push!(tmp_vals, parse(Float64, strip(line)))
        end
        sorted_vals = sort(tmp_vals)
        n = length(sorted_vals)
        amedian = sorted_vals[fld(n, 2) + 1]
        amax = amedian + 3
        amin = amedian - 3
        open("tmp2.dat", "w") do io
            for line in eachline("freq_xcorr.dat")
                w = split(line)
                v4 = parse(Float64, w[4])
                if v4 > amin && v4 < amax
                    println(io, line)
                end
            end
        end

        open("IMG-$aligned-$subswath.PRM", "a") do io
            run(pipeline(`fitoffset.csh 2 3 tmp2.dat 10`, stdout=io))
        end
        run(`resamp IMG-$master-$subswath.PRM IMG-$aligned-$subswath.PRM IMG-$aligned-$subswath.PRMresamp IMG-$aligned-$subswath.SLCresamp 4`)
        rm("IMG-$aligned-$subswath.SLC"; force=true)
        mv("IMG-$aligned-$subswath.SLCresamp", "IMG-$aligned-$subswath.SLC"; force=true)
        cp("IMG-$aligned-$subswath.PRMresamp", "IMG-$aligned-$subswath.PRM"; force=true)

        cd("../..")
        println("ALIGN - END")
    end

    ##################################
    # 3 - start from make topo_ra    #
    ##################################

    if parse(Int, stage) <= 3
        #
        # clean up
        #
        cd(subswath)
        run(`cleanup.csh topo`)
        #
        # make topo_ra if there is dem.grd
        #
        if parse(Int, topo_phase) == 1
            println(" ")
            println("DEM2TOPO_RA.CSH - START")
            println("USER SHOULD PROVIDE DEM FILE")
            cd("topo")
            cp("../SLC/IMG-$master-$subswath.PRM", "master.PRM"; force=true)
            symlink("../../raw/IMG-$master-$subswath.LED", "IMG-$master-$subswath.LED")

            if isfile("../../topo/dem.grd")
                symlink("../../topo/dem.grd", "dem.grd")
                run(`dem2topo_ra.csh master.PRM dem.grd`)
            else
                println("no DEM file found:  dem.grd")
                exit(1)
            end
            cd("..")
            println("DEM2TOPO_RA.CSH - END")
            #
            # shift topo_ra
            #
            if parse(Int, shift_topo) == 1
                println(" ")
                println("OFFSET_TOPO - START")
                cd("SLC")
                run(`slc2amp.csh IMG-$master-$subswath.PRM 2 amp-$master.grd`)
                cd("..")
                cd("topo")
                symlink("../SLC/amp-$master.grd", "amp-$master.grd")
                run(`offset_topo amp-$master.grd topo_ra.grd 0 0 7 topo_shift.grd`)
                cd("..")
                println("OFFSET_TOPO - END")
            elseif parse(Int, shift_topo) == 0
                println("NO TOPO_RA SHIFT ")
            else
                println("Wrong paramter: shift_topo $shift_topo")
                exit(1)
            end

        elseif parse(Int, topo_phase) == 0
            println("NO TOPO_RA IS SUBSTRACTED")
        else
            println("Wrong paramter: topo_phase $topo_phase")
            exit(1)
        end
        cd("..")
    end

    ##################################################
    # 4 - start from make and filter interferograms  #
    ##################################################

    if parse(Int, stage) <= 4
        #
        # clean up
        #
        cd(subswath)
        run(`cleanup.csh intf`)
        #
        # make and filter interferograms
        #
        println(" ")
        println("INTF.CSH, FILTER.CSH - START")
        cd("intf/")
        ref_id = grep_field_int("../SLC/IMG-$ref-$subswath.PRM", "SC_clock_start")
        rep_id = grep_field_int("../SLC/IMG-$rep-$subswath.PRM", "SC_clock_start")
        mkpath("$(ref_id)_$(rep_id)")
        cd("$(ref_id)_$(rep_id)")
        symlink("../../../raw/IMG-$ref-$subswath.LED", "IMG-$ref-$subswath.LED")
        symlink("../../../raw/IMG-$rep-$subswath.LED", "IMG-$rep-$subswath.LED")
        symlink("../../SLC/IMG-$ref-$subswath.SLC", "IMG-$ref-$subswath.SLC")
        symlink("../../SLC/IMG-$rep-$subswath.SLC", "IMG-$rep-$subswath.SLC")
        cp("../../SLC/IMG-$ref-$subswath.PRM", "IMG-$ref-$subswath.PRM"; force=true)
        cp("../../SLC/IMG-$rep-$subswath.PRM", "IMG-$rep-$subswath.PRM"; force=true)
        if parse(Int, topo_phase) == 1
            if parse(Int, shift_topo) == 1
                symlink("../../topo/topo_shift.grd", "topo_shift.grd")
                run(`intf.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM -topo topo_shift.grd`)
                run(`filter.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM $filter $dec`)
            else
                symlink("../../topo/topo_ra.grd", "topo_ra.grd")
                run(`intf.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM -topo topo_ra.grd`)
                run(`filter.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM $filter $dec`)
            end
        else
            run(`intf.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM`)
            run(`filter.csh IMG-$ref-$subswath.PRM IMG-$rep-$subswath.PRM $filter $dec`)
        end
        cd("../..")
        println("INTF.CSH, FILTER.CSH - END")
        cd("..")
    end

    ################################
    # 5 - start from unwrap phase  #
    ################################

    if parse(Int, stage) <= 5
        if parse(Float64, threshold_snaphu) != 0
            cd(subswath)
            cd("intf")
            ref_id = grep_field_int("../SLC/IMG-$ref-$subswath.PRM", "SC_clock_start")
            rep_id = grep_field_int("../SLC/IMG-$rep-$subswath.PRM", "SC_clock_start")
            cd("$(ref_id)_$(rep_id)")
            if region_cut == ""
                out = read(`gmt grdinfo phase.grd -I-`, String)
                line1 = split(out, '\n')[1]
                region_cut = substr(line1, 3, 18)
            end

            #
            # landmask
            #
            if parse(Int, mask_water) == 1 || parse(Int, switch_land) == 1
                cd("../../topo")
                if !isfile("landmask_ra.grd")
                    run(`landmask.csh $region_cut`)
                end
                cd("../intf")
                cd("$(ref_id)_$(rep_id)")
                symlink("../../topo/landmask_ra.grd", "landmask_ra.grd")
            end

            println(" ")
            println("SNAPHU.CSH - START")
            println("threshold_snaphu: $threshold_snaphu")

            if parse(Int, near_interp) == 1
                run(`snaphu_interp.csh $threshold_snaphu $defomax $region_cut`)
            else
                run(`snaphu.csh $threshold_snaphu $defomax $region_cut`)
            end

            println("SNAPHU.CSH - END")
            cd("../../..")
        else
            println("")
            println("SKIP UNWRAP PHASE")
        end
    end

    ###########################
    # 6 - start from geocode  #
    ###########################

    if parse(Int, stage) <= 6
        cd(subswath)
        cd("intf")
        ref_id = grep_field_int("../SLC/IMG-$ref-$subswath.PRM", "SC_clock_start")
        rep_id = grep_field_int("../SLC/IMG-$rep-$subswath.PRM", "SC_clock_start")
        cd("$(ref_id)_$(rep_id)")
        println(" ")
        println("GEOCODE.CSH - START")
        rm("raln.grd"; force=true)
        rm("ralt.grd"; force=true)
        if parse(Int, topo_phase) == 1
            rm("trans.dat"; force=true)
            symlink("../../topo/trans.dat", "trans.dat")
            println("threshold_geocode: $threshold_geocode")
            run(`geocode.csh $threshold_geocode`)
        else
            println("topo_ra is needed to geocode")
            exit(1)
        end
        println("GEOCODE.CSH - END")
        cd("../../..")
    end

    # end
end

main(ARGS)
