#!/usr/bin/env julia
#       $Id$

# generate interferograms for tops stacks
# used for time series analysis

# Xiaohua(Eric) Xu, Jan 20 2016
#

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field, "" if none"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    return ""
end

"""grep PATTERN file | awk '{printf("%d",int(\$3))}'  -- first matching line, 3rd field truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""mirrors awk's 1-indexed substr(\$1,start,len) / cut -cSTART-END"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    if length(argv) != 2
        println("")
        println("Usage: intf_tops.csh intf.in batch_tops.config")
        println("  generate interferograms for a set of tops images in intf.in, dem required in ./topo")
        println("  supermaster's name required in batch_tops.config")
        println("")
        println("  format of data.in:")
        println("    master_image_stem:aligned_image_stem")
        println("")
        println("  example of data.in")
        println("    S1_20150628_ALL_F1:S1_20150720_ALL_F1")
        println("    S1_20150720_ALL_F1:S1_20150809_ALL_F1")
        println("")
        println("  outputs:")
        println("    to ./intf_all")
        println("")
        println("  Note: remember to remove intf_all before running a new round of processing, otherwise")
        println("    the results may get placed into the subfolders")
        println("")
        exit(1)
    end

    #
    # make sure the files exist
    #
    if !isfile(argv[1])
        println("no input file: $(argv[2])")
        exit(0)
    end

    if !isfile(argv[2])
        println("no config file: $(argv[2])")
        exit(0)
    end
    #
    # read parameters from config file
    #

    stage = grep_field(argv[2], "proc_stage")
    master = grep_field(argv[2], "master_image")
    #
    # if filter wavelength is not set then use a default of 200m
    #
    filter = grep_field(argv[2], "filter_wavelength")
    if filter == ""
        filter = "200"
        println(" ")
        println("WARNING filter wavelength was not set in config.txt file")
        println("        please specify wavelength (e.g., filter_wavelength = 200)")
        println("        remove filter1 = gauss_alos_200m")
    end
    dec = grep_field(argv[2], "dec_factor")
    topo_phase = grep_field(argv[2], "topo_phase")
    shift_topo = grep_field(argv[2], "shift_topo")
    threshold_snaphu = grep_field(argv[2], "threshold_snaphu")
    threshold_geocode = grep_field(argv[2], "threshold_geocode")
    region_cut = grep_field(argv[2], "region_cut")
    switch_land = grep_field(argv[2], "switch_land")
    defomax = grep_field(argv[2], "defomax")
    range_dec = grep_field(argv[2], "range_dec")
    azimuth_dec = grep_field(argv[2], "azimuth_dec")
    near_interp = grep_field(argv[2], "near_interp")
    mask_water = grep_field(argv[2], "mask_water")

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
            cd("topo")
            cp(joinpath("..", "raw", "$master.PRM"), "master.PRM"; force=true)
            symlink(joinpath("..", "raw", "$master.LED"), "$master.LED")
            if isfile("dem.grd")
                if region_cut == ""
                    run(`$GMTSAR_JULIA $(gmtsar_script("dem2topo_ra")) master.PRM dem.grd`)
                else
                    run(`gmt cut_slc -Amaster.PRM -Bjunk -C$region_cut -P`)
                    mv("junk.PRM", "master.PRM"; force=true)
                    run(`$GMTSAR_JULIA $(gmtsar_script("dem2topo_ra")) master.PRM dem.grd`)
                end
            else
                println("no DEM file found: ", " dem.grd")
                exit(1)
            end
            cd("..")
            println("DEM2TOPOPHASE.CSH - END")

            #
            #  shift topo_ra
            #
            if shift_topo == "1"
                println(" ")
                println("OFFSET_TOPO - START")
                cd("topo")
                symlink(joinpath("..", "raw", "$master.SLC"), "$master.SLC")
                run(`$GMTSAR_JULIA $(gmtsar_script("slc2amp")) master.PRM 4 amp-$master.grd`)
                run(`gmt offset_topo -Aamp-$master.grd -Btopo_ra.grd -X0 -Y0 -S7 -Gtopo_shift.grd`)
                cd("..")
                println("OFFSET_TOPO - END")
            elseif shift_topo == "0"
                println("NO TOPOPHASE SHIFT ")
            else
                println("Wrong paramter: shift_topo " * shift_topo)
                exit(1)
            end
        elseif topo_phase == "0"
            println("NO TOPOPHASE IS SUBSTRACTED")
        else
            println("Wrong paramter: topo_phase " * topo_phase)
            exit(1)
        end
    end

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
        println("")
        mkpath("intf/")
        mkpath("intf_all/")
        #
        # loop over intf.in
        #
        tokens = String[]
        for l in readlines(argv[1])
            append!(tokens, split(l))
        end
        for line in tokens
            ref = split(line, ":")[1]
            rep = split(line, ":")[2]
            ref_id = grep_field_int(joinpath(".", "raw", "$ref.PRM"), "SC_clock_start")
            rep_id = grep_field_int(joinpath(".", "raw", "$rep.PRM"), "SC_clock_start")

            println("")
            println("INTF.CSH, FILTER.CSH - START")
            cd("intf")
            pairdir = "$(ref_id)_$(rep_id)"
            mkpath(pairdir)
            cd(pairdir)
            symlink(joinpath("..", "..", "raw", "$ref.LED"), "$ref.LED")
            symlink(joinpath("..", "..", "raw", "$rep.LED"), "$rep.LED")
            symlink(joinpath("..", "..", "raw", "$ref.SLC"), "$ref.SLC")
            symlink(joinpath("..", "..", "raw", "$rep.SLC"), "$rep.SLC")
            cp(joinpath("..", "..", "raw", "$ref.PRM"), "$ref.PRM"; force=true)
            cp(joinpath("..", "..", "raw", "$rep.PRM"), "$rep.PRM"; force=true)

            if region_cut != ""
                println("Cutting SLC image to $region_cut")
                run(`gmt cut_slc -A$ref.PRM -Bjunk1 -C$region_cut`)
                run(`gmt cut_slc -A$rep.PRM -Bjunk2 -C$region_cut`)
                mv("junk1.PRM", "$ref.PRM"; force=true)
                mv("junk2.PRM", "$rep.PRM"; force=true)
                mv("junk1.SLC", "$ref.SLC"; force=true)
                mv("junk2.SLC", "$rep.SLC"; force=true)
            end

            if topo_phase == "1"
                if shift_topo == "1"
                    symlink(joinpath("..", "..", "topo", "topo_shift.grd"), "topo_shift.grd")
                    run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM -topo topo_shift.grd`)
                else
                    symlink(joinpath("..", "..", "topo", "topo_ra.grd"), "topo_ra.grd")
                    run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM -topo topo_ra.grd`)
                end
            else
                run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM`)
            end
            run(`$GMTSAR_JULIA $(gmtsar_script("filter")) $ref.PRM $rep.PRM $filter $dec $range_dec $azimuth_dec`)
            println("INTF.CSH, FILTER.CSH - END")

            #
            # unwrapping
            #

            if parse(Float64, threshold_snaphu) != 0
                if mask_water == "1" || switch_land == "1"
                    #if ($region_cut == "") then
                    grdinfo_line = strip(read(pipeline(`gmt grdinfo phase.grd -I-`), String))
                    mask_region = substr(grdinfo_line, 3, 18)
                    #endif
                    cd(joinpath("..", "..", "topo"))
                    if !isfile("landmask_ra.grd")
                        run(`$GMTSAR_JULIA $(gmtsar_script("landmask")) $mask_region`)
                    end
                    cd(joinpath("..", "intf"))
                    cd(pairdir)
                    symlink(joinpath("..", "..", "topo", "landmask_ra.grd"), "landmask_ra.grd")
                end

                println("")
                println("SNAPHU.CSH - START")
                println("threshold_snaphu: $threshold_snaphu")
                if near_interp == "1"
                    #snaphu_interp.csh $threshold_snaphu $defomax $region_cut
                    run(`$GMTSAR_JULIA $(gmtsar_script("snaphu_interp")) $threshold_snaphu $defomax`)
                else
                    #snaphu.csh $threshold_snaphu $defomax $region_cut
                    run(`$GMTSAR_JULIA $(gmtsar_script("snaphu")) $threshold_snaphu $defomax`)
                end
                println("SNAPHU.CSH - END")
            else
                println("")
                println("SKIP UNWRAP PHASE")
            end
            #
            # geocoding
            #
            println("")
            println("GEOCODE.CSH - START")
            if topo_phase == "1" && parse(Float64, threshold_geocode) != 0
                if isfile("raln.grd")
                    rm("raln.grd"; force=true)
                end
                if isfile("ralt.grd")
                    rm("ralt.grd"; force=true)
                end
                rm("trans.dat"; force=true)
                symlink(joinpath("..", "..", "topo", "trans.dat"), "trans.dat")
                println("threshold_geocode: $threshold_geocode")
                run(`$GMTSAR_JULIA $(gmtsar_script("geocode")) $threshold_geocode`)
            elseif topo_phase == "1" && parse(Float64, threshold_geocode) == 0
                println("SKIP GEOCODING")
            else
                println("topo_ra is needed to geocode")
                exit(1)
            end

            cd(joinpath("..", ".."))
            if ispath(joinpath("intf_all", pairdir))
                rm(joinpath("intf_all", pairdir); force=true, recursive=true)
            end
            mv(joinpath("intf", pairdir), joinpath("intf_all", pairdir); force=true)

        end
    end

    println("")
    println("END STACK OF TOPS INTERFEROGRAMS")
    println("")
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
