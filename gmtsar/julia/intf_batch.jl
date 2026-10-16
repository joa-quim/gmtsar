#!/usr/bin/env julia
#       $Id$
#
# intf_batch.csh
# Loop through a list of interferometry pairs
# modified from process2pass.csh
# Xiaopeng Tong D.Sandwell Aug 27 2010
# added support for ENVI_SLC
# Anders Hogrelius May 22 2017

# alias rm 'rm -f'
# unset noclobber

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd field, or "" if no match (mirrors csh set-from-empty-backquote)"""
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
    v = grep_field_opt(file, pattern)
    v == "" && error("pattern not found: $pattern in $file")
    return trunc(Int, parse(Float64, v))
end

"""s[start:(start+len-1)]"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start+len-1)]

function main(argv::Vector{String})
    #
    if length(argv) != 3
        println()
        println("Usage: intf_batch.csh SAT intf.in batch.config")
        println("  make a stack of interferograms listed in intf.in")
        println()
        println(" SAT can be ALOS ENVI(ENVISAT) ENVI_SLC and  ERS ")
        println()
        println(" format for intf.in:")
        println("     reference1_name:repeat1_name")
        println("     reference2_name:repeat2_name")
        println("     reference3_name:repeat3_name")
        println("     ......")
        println()
        println(" Example of intf.in for ALOS:")
        println("    IMG-HH-ALPSRP096010650-H1.0__A:IMG-HH-ALPSRP236920650-H1.0__A")
        println("    IMG-HH-ALPSRP089300650-H1.0__A:IMG-HH-ALPSRP096010650-H1.0__A")
        println("    IMG-HH-ALPSRP089300650-H1.0__A:IMG-HH-ALPSRP236920650-H1.0__A")
        println()
        println(" Example of intf.in for ERS is:")
        println("    e1_05783:e1_07787")
        println("    e1_05783:e1_10292")
        println()
        println(" Example of intf.in for ENVISAT is:")
        println("    ENV1_2_127_2925_07195:ENV1_2_127_2925_12706")
        println("    ENV1_2_127_2925_07195:ENV1_2_127_2925_13207")
        println()
        println(" Example of intf.in for ENVI_SLC is:")
        println("    ASA_IMS_1PNESA20030908_175832_000000182019_00399_07968_0000:ASA_IMS_1PNESA20051121_175837_000000172042_00399_19491_0000")
        println("    ASA_IMS_1PNESA20040719_175832_000000182028_00399_12477_0000:ASA_IMS_1PNESA20051121_175837_000000172042_00399_19491_0000")
        println("    ASA_IMS_1PNESA20040719_175832_000000182028_00399_12477_0000:ASA_IMS_1PNESA20030908_175832_000000182019_00399_07968_0000")
        println("    ASA_IMS_1PNESA20051121_175837_000000172042_00399_19491_0000:ASA_IMS_1PNESA20040719_175832_000000182028_00399_12477_0000")
        println()
        println(" Example of intf.in for TSX is:")
        println("    20171231:20180111")
        println("    20171231:20180122")
        println()
        println(" batch.config is a config file for making interferograms")
        println(" See example.batch.config for an example")
        println()
        exit(1)
    end
    #
    SAT = argv[1]
    if SAT != "ALOS" && SAT != "ENVI" && SAT != "ERS" && SAT != "ENVI_SLC" && SAT != "TSX"
        println()
        println(" SAT can be ALOS ENVI(ENVISAT) ENVI_SLC TSX and  ERS")
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
    master = grep_field_opt(config, "master_image")
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
    region_cut = grep_field_opt(config, "region_cut")
    switch_land = grep_field_opt(config, "switch_land")
    defomax = grep_field_opt(config, "defomax")
    near_interp = grep_field_opt(config, "near_interp")
    mask_water = grep_field_opt(config, "mask_water")
    #
    ##################################
    # 1 - start from make topo_ra  #
    ##################################
    #
    if parse(Int, stage) <= 1
        #
        # clean up
        #
        run(`cleanup.csh topo`)
        #
        # make topo_ra
        #
        if parse(Int, topo_phase) == 1
            println(" ")
            println("DEM2TOPOPHASE.CSH - START")
            println("USER SHOULD PROVIDE DEM FILE")
            cd("topo") do
                cp(joinpath("..", "SLC", "$master.PRM"), "master.PRM"; force=true)
                symlink(joinpath("..", "raw", "$master.LED"), "$master.LED")
                if isfile("dem.grd")
                    run(`dem2topo_ra.csh master.PRM dem.grd`)
                else
                    println("no DEM file found: ", " dem.grd")
                    exit(1)
                end
            end
            println("DEM2TOPOPHASE.CSH - END")
            #
            # shift topo_ra
            #
            if parse(Int, shift_topo) == 1
                println(" ")
                println("OFFSET_TOPO - START")
                cd("SLC") do
                    if SAT == "ALOS" || SAT == "TSX"
                        rng_samp_rate_s = grep_field_opt("$master.PRM", "rng_samp_rate")
                        if rng_samp_rate_s != ""
                            rng_samp_rate = trunc(Int, parse(Float64, rng_samp_rate_s))
                            local rng
                            if rng_samp_rate > 25000000
                                println("processing ALOS FBS data")
                                rng = 2
                            else
                                println("processing ALOS FBD data")
                                rng = 1
                            end
                            run(`slc2amp.csh $master.PRM $rng amp-$master.grd`)
                        else
                            println("Undefined rng_samp_rate in the master PRM file")
                            exit(1)
                        end
                    elseif SAT == "ERS" || SAT == "ENVI" || SAT == "ENVI_SLC"
                        run(`slc2amp.csh $master.PRM 1 amp-$master.grd`)
                    end
                end
                cd("topo") do
                    symlink(joinpath("..", "SLC", "amp-$master.grd"), "amp-$master.grd")
                    run(`offset_topo amp-$master.grd topo_ra.grd 0 0 7 topo_shift.grd`)
                end
                println("OFFSET_TOPO - END")
            elseif parse(Int, shift_topo) == 0
                println("NO TOPOPHASE SHIFT ")
            else
                println("Wrong paramter: shift_topo ", shift_topo)
                exit(1)
            end
            #
        elseif parse(Int, topo_phase) == 0
            println("NO TOPOPHASE IS SUBSTRACTED")
        else
            println("Wrong paramter: topo_phase ", topo_phase)
            exit(1)
        end
    end
    #
    ##################################################
    # 2 - start from make and filter interferograms  #
    #                unwrap phase and geocode        #
    ##################################################
    #
    if parse(Int, stage) <= 2
        #
        # make working directories
        #
        println("")
        println("START FORM A STACK OF INTERFEROGRAMS")
        println("")

        mkpath("intf")
        #
        # loop over intf.in
        #
        for line in readlines(argv[2])
            words = split(line)
            isempty(words) && continue
            fields = split(words[1], ":")
            ref = fields[1]
            rep = fields[2]
            ref_id = grep_field_int(joinpath(".", "SLC", "$ref.PRM"), "SC_clock_start")
            rep_id = grep_field_int(joinpath(".", "SLC", "$rep.PRM"), "SC_clock_start")
            #
            println("")
            println("INTF.CSH, FILTER.CSH - START")
            cd("intf") do
                pairdir = "$(ref_id)_$(rep_id)"
                mkpath(pairdir)
                cd(pairdir) do
                    symlink(joinpath("..", "..", "raw", "$ref.LED"), "$ref.LED")
                    symlink(joinpath("..", "..", "raw", "$rep.LED"), "$rep.LED")
                    symlink(joinpath("..", "..", "SLC", "$ref.SLC"), "$ref.SLC")
                    symlink(joinpath("..", "..", "SLC", "$rep.SLC"), "$rep.SLC")
                    cp(joinpath("..", "..", "SLC", "$ref.PRM"), "$ref.PRM"; force=true)
                    cp(joinpath("..", "..", "SLC", "$rep.PRM"), "$rep.PRM"; force=true)
                    #
                    if parse(Int, topo_phase) == 1
                        if parse(Int, shift_topo) == 1
                            symlink(joinpath("..", "..", "topo", "topo_shift.grd"), "topo_shift.grd")
                            run(`intf.csh $ref.PRM $rep.PRM -topo topo_shift.grd`)
                            run(`filter.csh $ref.PRM $rep.PRM $filter $dec`)
                        else
                            symlink(joinpath("..", "..", "topo", "topo_ra.grd"), "topo_ra.grd")
                            run(`intf.csh $ref.PRM $rep.PRM -topo topo_ra.grd`)
                            run(`filter.csh $ref.PRM $rep.PRM $filter $dec`)
                        end
                    else
                        run(`intf.csh $ref.PRM $rep.PRM`)
                        run(`filter.csh $ref.PRM $rep.PRM $filter $dec`)
                    end
                    println("INTF.CSH, FILTER.CSH - END")
                    #
                    if region_cut == ""
                        info = chomp(read(`gmt grdinfo phase.grd -I-`, String))
                        region_cut = substr(info, 3, 18)
                    end
                    if parse(Float64, threshold_snaphu) != 0
                        if parse(Int, mask_water) == 1 || parse(Int, switch_land) == 1
                            cd(joinpath("..", "..", "topo")) do
                                if !isfile("landmask_ra.grd")
                                    run(`landmask.csh $region_cut`)
                                end
                            end
                            symlink(joinpath("..", "..", "topo", "landmask_ra.grd"), "landmask_ra.grd")
                        end
                        println("")
                        println("SNAPHU.CSH - START")
                        println("threshold_snaphu: $threshold_snaphu")
                        if parse(Int, near_interp) == 1
                            run(`snaphu_interp.csh $threshold_snaphu $defomax $region_cut`)
                        else
                            run(`snaphu.csh $threshold_snaphu $defomax $region_cut`)
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
                    if parse(Int, topo_phase) == 1
                        rm("trans.dat"; force=true)
                        symlink(joinpath("..", "..", "topo", "trans.dat"), "trans.dat")
                        println("threshold_geocode: $threshold_geocode")
                        run(`geocode.csh $threshold_geocode`)
                    else
                        println("topo_ra is needed to geocode")
                        exit(1)
                    end
                    println("GEOCODE.CSH - END")
                end
            end
        end # loop of foreach
    end # stage 2
    println("")
    println("END FORM A STACK OF INTERFEROGRAMS")
    println("")
end

main(ARGS)
