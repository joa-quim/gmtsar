#!/usr/bin/env julia
#       $Id$
#
#  Xiaohua Xu, Jan, 2018
#
#  Preprocess the data to Raw or SLC or aligned SLC depending on which satellite to use
#

# alias rm 'rm -f'
# unset noclobber

using Printf

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""grep PATTERN file | awk 'NR == 1 {printf("%d", \$3)}'  -- first match, truncated to Int"""
function grep_field_int(file::AbstractString, pattern::AbstractString)
    return trunc(Int, parse(Float64, grep_field(file, pattern)))
end

"""grep PATTERN tmp -n | awk -F: '{print \$1}' ; awk 'NR=='\$a'+1{print \$1}' tmp
   -- first field of the line following the first line matching PATTERN in the
   per-word tmp file; csh's \$a is empty when PATTERN is not found, which makes
   NR=='\$a'+1 evaluate as NR==+1, i.e. NR==1, so the default is line 1's value"""
function grep_next_field(file::AbstractString, pattern::AbstractString)
    lines = readlines(file)
    a = 0
    for (i, line) in enumerate(lines)
        if occursin(pattern, line)
            a = i
            break
        end
    end
    idx = a + 1
    if idx >= 1 && idx <= length(lines)
        return split(lines[idx])[1]
    end
    return ""
end

"""grep fd1 f1 | awk '{printf("%f ",\$3)}' > temp ; grep fd1 f2 | awk '{printf("%f",\$3)}' >> temp
   set fda = `cat temp | awk '{print( (\$1 + \$2)/2.)}'` ; rm -r temp"""
function average_fd1(file1::AbstractString, file2::AbstractString)
    v1 = grep_field(file1, "fd1")
    v2 = grep_field(file2, "fd1")
    open("temp", "w") do io
        print(io, "$v1 ")
    end
    open("temp", "a") do io
        print(io, v2)
    end
    line = readline("temp")
    parts = split(line)
    fda = (parse(Float64, parts[1]) + parse(Float64, parts[2])) / 2.0
    rm("temp"; force=true)
    return fda
end

"""cat srcs... > dst"""
function cat_files(dst::AbstractString, srcs::Vector{String})
    open(dst, "w") do io
        for s in srcs
            write(io, read(s))
        end
    end
end

"""mirrors awk's 1-indexed substr(\$1,start,len)"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    #
    # check the number of arguments
    #
    nargv = length(argv)
    if !(nargv == 3 || nargv == 5 || nargv == 7 || nargv == 9 || nargv == 11 || nargv == 13)
        println("")
        println("Usage: pre_proc.csh SAT master_stem aligned_stem [-near near_range] [-radius RE] [-npatch num_patches] [-fd1 DOPP] [-ESD mode] [-skip_master 1]")
        println("")
        println("Example: pre_proc.csh ALOS IMG-HH-ALPSRP099496420-H1.0__A IMG-HH-ALPSRP220276420-H1.0__A")
        println("")
        exit(1)
    end
    #
    # parse the command line arguments
    #
    println("pre_proc.csh")
    SAT = argv[1]
    words = vcat(["0"], argv[4:end])
    open("tmp", "w") do io
        for i in 1:20
            println(io, i <= length(words) ? words[i] : "")
        end
    end
    NEAR = grep_next_field("tmp", "near")
    RAD = grep_next_field("tmp", "near")
    num_patches = grep_next_field("tmp", "npatch")
    FD1 = grep_next_field("tmp", "fd1")
    SLC_factor = grep_next_field("tmp", "SLC_factor")
    ESD_mode = grep_next_field("tmp", "ESD")
    skip_master = grep_next_field("tmp", "skip_master")

    commandline = ""
    if parse(Float64, NEAR) != 0
        commandline = "$commandline -near $NEAR"
    end
    if parse(Float64, RAD) != 0
        commandline = "$commandline -radius $RAD"
    end
    if parse(Float64, num_patches) != 0
        commandline = "$commandline -npatch $num_patches"
    end
    if parse(Float64, FD1) != 0
        commandline = "$commandline -fd1 $FD1"
    end
    if parse(Float64, SLC_factor) != 0
        commandline = "$commandline -SLC_factor $SLC_factor"
    end

    println(commandline)

    skip_master_n = parse(Int, skip_master)
    if skip_master_n != 0
        println("")
        println("skip_master set to $skip_master ")
        println("")
    end

    rm("tmp"; force=true)
    master = argv[2]
    aligned = argv[3]

    if SAT == "ALOS"
        println("")
        println("Pre-Process ALOS data - START")
        println("")

        master = substr(argv[2], 8, length(argv[2]) - 7)
        aligned = substr(argv[3], 8, length(argv[3]) - 7)
        if !isfile("IMG-HH-$master") || !isfile("IMG-HH-$aligned") || !isfile("LED-$master") || !isfile("LED-$aligned")
            println("")
            println("$master $aligned")
            println("Error : Can not find input file at current directory!")
            println("")
            exit(1)
        end
        #
        # unpack the master if necessary
        #
        if !isfile("IMG-HH-$master.raw") || !isfile("IMG-HH-$master.PRM")
            println("pre_process master image")
            if skip_master_n == 0 || skip_master_n == 2
                run(`ALOS_pre_process IMG-HH-$master LED-$master $(split(commandline)...)`)
            end
        end

        NEAR = grep_field("IMG-HH-$master.PRM", "near_range")
        RAD = grep_field("IMG-HH-$master.PRM", "earth_radius")
        FD1 = grep_field("IMG-HH-$master.PRM", "fd1")
        num_patches = grep_field("IMG-HH-$master.PRM", "num_patches")
        #
        # unpack the aligned image using the same earth radius and near range as the master image
        #
        println("pre_process aligned image")
        if skip_master_n == 0 || skip_master_n == 1
            run(`ALOS_pre_process IMG-HH-$aligned LED-$aligned -fd1 $FD1 -near $NEAR -radius $RAD -npatch $num_patches -fd1 $FD1`)
        end
        #
        # check the range sampling rate of the aligned images and do conversion if necessary
        #
        if skip_master_n == 0 || skip_master_n == 1
            rng_samp_rate_m = grep_field_int("IMG-HH-$master.PRM", "rng_samp_rate")
            rng_samp_rate_s = grep_field_int("IMG-HH-$aligned.PRM", "rng_samp_rate")
            t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)

            if t == "1.0"
                println("The range sampling rate for master and aligned images are: ", rng_samp_rate_m)
            elseif t == "2.0"
                println("Convert the aligned image from FBD to FBS mode")
                run(`ALOS_fbd2fbs IMG-HH-$aligned.PRM IMG-HH-$(aligned)_FBS.PRM`)
                println("Overwriting the old aligned image")
                mv("IMG-HH-$(aligned)_FBS.PRM", "IMG-HH-$aligned.PRM"; force=true)
                run(`update_PRM IMG-HH-$aligned.PRM input_file IMG-HH-$aligned.raw`)
                mv("IMG-HH-$(aligned)_FBS.raw", "IMG-HH-$aligned.raw"; force=true)
                open("ALOS_fbd2fbs_log_$aligned", "w") do io
                    println(io, "IMG-HH-$aligned is converted to FBS mode")
                end
            elseif t == "0.5"
                println("Use FBS mode image as master")
                run(`ALOS_fbd2fbs IMG-HH-$master.PRM IMG-HH-$(master)_FBS.PRM`)
                println("Overwriting the old master image")
                mv("IMG-HH-$(master)_FBS.PRM", "IMG-HH-$master.PRM"; force=true)
                run(`update_PRM IMG-HH-$master.PRM input_file IMG-HH-$master.raw`)
                mv("IMG-HH-$(master)_FBS.raw", "IMG-HH-$master.raw"; force=true)
                open("ALOS_fbd2fbs_log_$master", "w") do io
                    println(io, "IMG-HH-$master is converted to FBS mode")
                end
                exit(1)
            else
                println("The range sampling rate for master and aligned images are not convertable")
                exit(1)
            end
        end

        println("")
        println(" Pre-Process ALOS data - END")
        println("")

    elseif SAT == "ERS"
        println("")
        println(" Pre-Process ERS data - START")
        println("")

        # set 0 for master to use it's own value
        if skip_master_n == 0 || skip_master_n == 2
            run(`ERS_pre_process $master $NEAR $RAD $num_patches $FD1`)
        end
        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        FD1 = grep_field("$master.PRM", "fd1")
        num_patches = grep_field("$master.PRM", "num_patches")
        if skip_master_n == 0 || skip_master_n == 1
            run(`ERS_pre_process $aligned $NEAR $RAD $num_patches $FD1`)
        end
        #
        #   check patch number, if different, use the smaller one
        #
        if skip_master_n == 0
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
        elseif skip_master_n == 1
            pch1 = grep_field_int("$master.PRM", "patch")
            run(`update_PRM $aligned.PRM num_patches $pch1`)
            println("Number of patches is set to $pch1")
        end
        #
        #   set the Doppler to be the average of the two
        #
        if skip_master_n == 0
            fda = average_fd1("$master.PRM", "$aligned.PRM")
            println(" use average Doppler $fda ")
            run(`update_PRM $master.PRM fd1 $fda`)
            run(`update_PRM $aligned.PRM fd1 $fda`)
        elseif skip_master_n == 1
            fda = grep_field("$master.PRM", "fd1")
            run(`update_PRM $aligned.PRM fd1 $fda`)
        end

        println("")
        println(" Pre-Process ERS data - END")
        println("")

    elseif SAT == "ENVI"
        println("")
        println(" Pre-Process ENVISAT data - START")
        println("")
        if skip_master_n == 0 || skip_master_n == 2
            run(`ENVI_pre_process $master $NEAR $RAD $num_patches $FD1`)
        end
        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        if skip_master_n == 0 || skip_master_n == 1
            run(`ENVI_pre_process $aligned $NEAR $RAD $num_patches $FD1`)
        end
        #
        #   check patch number, if different, use the smaller one
        #
        if skip_master_n == 0
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
        elseif skip_master_n == 1
            pch1 = grep_field_int("$master.PRM", "patch")
            run(`update_PRM $aligned.PRM num_patches $pch1`)
            println("Number of patches is set to $pch1")
        end
        #
        #   set the Doppler to be the average of the two
        #
        if skip_master_n == 0
            fda = average_fd1("$master.PRM", "$aligned.PRM")
            println(" use average Doppler $fda ")
            run(`update_PRM $master.PRM fd1 $fda`)
            run(`update_PRM $aligned.PRM fd1 $fda`)
        elseif skip_master_n == 1
            fda = grep_field("$master.PRM", "fd1")
            run(`update_PRM $aligned.PRM fd1 $fda`)
        end

        println("")
        println(" Pre-Process ENVISAT data - END")
        println("")

    elseif SAT == "ENVI_SLC"
        println("")
        println(" Pre-Process ENVISAT SLC data - START")
        println("")

        if skip_master_n == 0 || skip_master_n == 2
            run(`ENVI_SLC_pre_process $master $RAD`)
        end
        NEAR = grep_field("$master.PRM", "near_range")
        RAD = grep_field("$master.PRM", "earth_radius")
        println("ENVI_SLC_pre_process $aligned $RAD ")
        if skip_master_n == 0 || skip_master_n == 1
            run(`ENVI_SLC_pre_process $aligned $RAD`)
        end

        println("")
        println(" Pre-Process ENVISAT SLC data - END")
        println("")

    elseif SAT == "ALOS_SLC" || SAT == "ALOS2" || SAT == "ALOS2_SCAN" || SAT == "ALOS4"
        println("")
        println(" Pre-Process ALOS SLC data - START")
        println("")

        master = substr(argv[2], 5, length(argv[2]) - 4)
        aligned = substr(argv[3], 5, length(argv[3]) - 4)
        master_led = substr(argv[2], 8, length(argv[2]) - 7)
        aligned_led = substr(argv[3], 8, length(argv[3]) - 7)

        #echo $master $aligned $master_led $aligned_led
        if !isfile("IMG-$master") || !isfile("IMG-$aligned") || !isfile("LED-$master_led") || !isfile("LED-$aligned_led")
            println("")
            println("Error : Can not find input file at current directory!")
            println("")
            exit(1)
        end

        if SAT == "ALOS_SLC"
            if skip_master_n == 0 || skip_master_n == 2
                run(`ALOS_pre_process_SLC IMG-$master LED-$master_led $(split(commandline)...) -ALOS1`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`ALOS_pre_process_SLC IMG-$aligned LED-$aligned_led $(split(commandline)...) -ALOS1`)
            end
        elseif SAT == "ALOS4"
            if skip_master_n == 0 || skip_master_n == 2
                run(`ALOS_pre_process_SLC IMG-$master LED-$master_led $(split(commandline)...) -ALOS4 -rbias 2.5`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`ALOS_pre_process_SLC IMG-$aligned LED-$aligned_led $(split(commandline)...) -ALOS4 -rbias 2.5`)
            end
        else
            if skip_master_n == 0 || skip_master_n == 2
                run(`ALOS_pre_process_SLC IMG-$master LED-$master_led $(split(commandline)...)`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`ALOS_pre_process_SLC IMG-$aligned LED-$aligned_led $(split(commandline)...)`)
            end
        end

        # make FBD FBS conversion
        if skip_master_n == 0 || skip_master_n == 1
            rng_samp_rate_m = grep_field_int("IMG-$master.PRM", "rng_samp_rate")
            rng_samp_rate_s = grep_field_int("IMG-$aligned.PRM", "rng_samp_rate")
            t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)
            if t == "1.0"
                println("The range sampling rate for master and aligned images are: ", rng_samp_rate_m)
            elseif t == "2.0"
                println("Convert the aligned image from FBD to FBS mode")
                run(`ALOS_fbd2fbs_SLC IMG-$aligned.PRM IMG-$(aligned)_FBS.PRM`)
                println("Overwriting the old aligned image")
                mv("IMG-$(aligned)_FBS.PRM", "IMG-$aligned.PRM"; force=true)
                run(`update_PRM IMG-$aligned.PRM input_file IMG-$aligned.SLC`)
                mv("IMG-$(aligned)_FBS.SLC", "IMG-$aligned.SLC"; force=true)
                open("ALOS2_fbd2fbs_log_$aligned", "w") do io
                    println(io, "IMG-HH-$aligned is converted to FBS mode")
                end
            elseif t == "0.5"
                println("Convert the master image from FBD to FBS mode")
                run(`ALOS_fbd2fbs_SLC IMG-$master.PRM IMG-$(master)_FBS.PRM`)
                println("Overwriting the old master image")
                mv("IMG-$(master)_FBS.PRM", "IMG-$master.PRM"; force=true)
                run(`update_PRM IMG-$master.PRM input_file IMG-$master.SLC`)
                mv("IMG-$(master)_FBS.SLC", "IMG-$master.SLC"; force=true)
                open("ALOS2_fbd2fbs_log_$master", "w") do io
                    println(io, "IMG-HH-$master is converted to FBS mode")
                end
            else
                println("The range sampling rate for master and aligned images are not convertable")
                exit(1)
            end
        end

        println("")
        println(" Pre-Process ALOS SLC data - END")
        println("")

    elseif SAT == "CSK_RAW"
        println("")
        println(" Pre-Process CSK Raw data - START")
        println("")
        if skip_master_n == 0 || skip_master_n == 2
            run(`make_raw_csk $master.h5 $master`)
            # calculate SC_vel and SC_height
            mv("$master.PRM", "$master.PRM0"; force=true)
            run(`calc_dop_orb $master.PRM0 $master.log $RAD $FD1`)
            cat_files("$master.PRM", ["$master.PRM0", "$master.log"])
            open("$master.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
        end
        if skip_master_n == 0 || skip_master_n == 1
            run(`make_raw_csk $aligned.h5 $aligned`)
            # calculate SC_vel and SC_height
            #mv $master.PRM $master.PRM0
            mv("$aligned.PRM", "$aligned.PRM0"; force=true)
            run(`calc_dop_orb $aligned.PRM0 $aligned.log $RAD $FD1`)
            cat_files("$aligned.PRM", ["$aligned.PRM0", "$aligned.log"])
            open("$aligned.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
            for f in readdir(".")
                if endswith(f, ".log")
                    rm(f; force=true)
                end
            end
            for f in readdir(".")
                if endswith(f, ".PRM0")
                    rm(f; force=true)
                end
            end
        end
        #
        #
        #   check patch number, if different, use the smaller one
        #
        if skip_master_n == 0
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
        elseif skip_master_n == 1
            pch1 = grep_field_int("$master.PRM", "patch")
            run(`update_PRM $aligned.PRM num_patches $pch1`)
            println("Number of patches is set to $pch1")
        end
        #
        #   set the Doppler to be the average of the two
        #
        if skip_master_n == 0
            fda = average_fd1("$master.PRM", "$aligned.PRM")
            println(" use average Doppler $fda ")
            run(`update_PRM $master.PRM fd1 $fda`)
            run(`update_PRM $aligned.PRM fd1 $fda`)
        elseif skip_master_n == 1
            fda = grep_field("$master.PRM", "fd1")
            run(`update_PRM $aligned.PRM fd1 $fda`)
        end

        println("")
        println(" Pre-Process CSK Raw data - END")
        println("")

    elseif SAT == "CSK_SLC" || SAT == "CSG" || SAT == "TSX" || SAT == "S1_STRIP" || SAT == "RS2" || SAT == "GF3" || SAT == "LT1"
        println("")
        println(" Pre-Process CSK/TSX/RS2/S1_STRIP/GF3/LT1 SLC data - START")
        println("")
        if SAT == "CSK_SLC"
            if skip_master_n == 0 || skip_master_n == 2
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_csk $master.h5 $master`)
                else
                    run(`make_slc_csk $master.h5 $master $SLC_factor`)
                end
            end
            if skip_master_n == 0 || skip_master_n == 1
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_csk $aligned.h5 $aligned`)
                else
                    run(`make_slc_csk $aligned.h5 $aligned $SLC_factor`)
                end
            end
        elseif SAT == "CSG"
            if skip_master_n == 0 || skip_master_n == 2
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_csk2 $master.h5 $master`)
                else
                    run(`make_slc_csk2 $master.h5 $master $SLC_factor`)
                end
            end
            if skip_master_n == 0 || skip_master_n == 1
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_csk2 $aligned.h5 $aligned`)
                else
                    run(`make_slc_csk2 $aligned.h5 $aligned $SLC_factor`)
                end
            end
        elseif SAT == "TSX"
            if skip_master_n == 0 || skip_master_n == 2
                run(`make_slc_tsx $master.xml $master.cos $master`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`make_slc_tsx $aligned.xml $aligned.cos $aligned`)
            end
        elseif SAT == "RS2"
            if skip_master_n == 0 || skip_master_n == 2
                run(`make_slc_rs2 $master.xml $master.tif $master`)
                mv("$master.LED", "save-$master.LED"; force=true)
                run(`extend_orbit save-$master.LED $master.LED 3`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`make_slc_rs2 $aligned.xml $aligned.tif $aligned`)
                mv("$aligned.LED", "save-$aligned.LED"; force=true)
                run(`extend_orbit save-$aligned.LED $aligned.LED 3`)
            end
        elseif SAT == "GF3"
            if skip_master_n == 0 || skip_master_n == 2
                run(`make_slc_gf3 $master.xml $master.tiff $master`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`make_slc_gf3 $aligned.xml $aligned.tiff $aligned`)
            end
        elseif SAT == "LT1"
            if skip_master_n == 0 || skip_master_n == 2
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_lt1 $master.xml $master.tiff $master`)
                else
                    run(`make_slc_lt1 $master.xml $master.tiff $master $SLC_factor`)
                end
            end
            if skip_master_n == 0 || skip_master_n == 1
                if parse(Float64, SLC_factor) == 0
                    run(`make_slc_lt1 $aligned.xml $aligned.tiff $aligned`)
                else
                    run(`make_slc_lt1 $aligned.xml $aligned.tiff $aligned $SLC_factor`)
                end
            end
        else
            if skip_master_n == 0 || skip_master_n == 2
                run(`make_slc_s1a $master.xml $master.tiff $master`)
                mv("$master.LED", "save-$master.LED"; force=true)
                run(`extend_orbit save-$master.LED $master.LED 3`)
            end
            if skip_master_n == 0 || skip_master_n == 1
                run(`make_slc_s1a $aligned.xml $aligned.tiff $aligned`)
                mv("$aligned.LED", "save-$aligned.LED"; force=true)
                run(`extend_orbit save-$aligned.LED $aligned.LED 3`)
            end
        end
        #
        # set the num_lines to be the min of the master and aligned
        #
        if skip_master_n == 0
            m_lines = grep_field_int("../raw/$master.PRM", "num_lines")
            s_lines = grep_field_int("../raw/$aligned.PRM", "num_lines")
            if s_lines < m_lines
                run(`update_PRM $master.PRM num_lines $s_lines`)
                run(`update_PRM $master.PRM num_valid_az $s_lines`)
                run(`update_PRM $master.PRM nrows $s_lines`)
            else
                run(`update_PRM $aligned.PRM num_lines $m_lines`)
                run(`update_PRM $aligned.PRM num_valid_az $m_lines`)
                run(`update_PRM $aligned.PRM nrows $m_lines`)
            end
        elseif skip_master_n == 1
            m_lines = grep_field_int("../raw/$master.PRM", "num_lines")
            run(`update_PRM $aligned.PRM num_lines $m_lines`)
            run(`update_PRM $aligned.PRM num_valid_az $m_lines`)
            run(`update_PRM $aligned.PRM nrows $m_lines`)
        end

        #
        #   calculate SC_vel and SC_height
        #   set the Doppler to be zero
        #
        if skip_master_n == 0 || skip_master_n == 2
            cp("$master.PRM", "$master.PRM0"; force=true)
            run(`calc_dop_orb $master.PRM0 $master.log $RAD 0`)
            cat_files("$master.PRM", ["$master.PRM0", "$master.log"])
            open("$master.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
        end
        #
        if skip_master_n == 0 || skip_master_n == 1
            cp("$aligned.PRM", "$aligned.PRM0"; force=true)
            run(`calc_dop_orb $aligned.PRM0 $aligned.log $RAD 0`)
            cat_files("$aligned.PRM", ["$aligned.PRM0", "$aligned.log"])
            open("$aligned.PRM", "a") do io
                println(io, "fdd1                    = 0")
                println(io, "fddd1                   = 0")
            end
            for f in readdir(".")
                if endswith(f, ".log")
                    rm(f; force=true)
                end
            end
            for f in readdir(".")
                if endswith(f, ".PRM0")
                    rm(f; force=true)
                end
            end
        end

        println("")
        println(" Pre-Process SLC data - END")
        println("")

    elseif SAT == "S1_TOPS"
        println("")
        println(" Pre-Process S1_TOPS data - START")
        println("")
        if !isfile("../topo/dem.grd")
            println("missing file ../topo/dem.grd")
            exit(1)
        end
        symlink("../topo/dem.grd", "dem.grd")

        if parse(Float64, ESD_mode) == 0
            if skip_master_n == 0
                run(`align_tops.csh $master $master.EOF $aligned $aligned.EOF dem.grd`)
            elseif skip_master_n == 1
                run(`align_tops.csh $master 0 $aligned $aligned.EOF dem.grd`)
            elseif skip_master_n == 2
                run(`align_tops.csh $master $master.EOF $aligned 0 dem.grd`)
            else
                println("[ERROR]: Wrong skip_master parameter used for TOPS data, please check")
                exit(1)
            end
        else
            if skip_master_n == 0
                run(`align_tops_esd.csh $master $master.EOF $aligned $aligned.EOF dem.grd $ESD_mode`)
            elseif skip_master_n == 1
                run(`align_tops_esd.csh $master 0 $aligned $aligned.EOF dem.grd $ESD_mode`)
            elseif skip_master_n == 2
                run(`align_tops_esd.csh $master $master.EOF $aligned 0 dem.grd $ESD_mode`)
            else
                println("[ERROR]: Wrong skip_master parameter used for TOPS data, please check")
                exit(1)
            end
        end

        println("")
        println(" Pre-Process S1_TOPS data - END")
        println("")
    end
    #
end

main(ARGS)
