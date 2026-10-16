#!/usr/bin/env julia
#       $Id$
#
#
#    Xiaohua(Eric) XU, July 7, 2016
#
# Script for merging 3 subswaths TOPS interferograms and then unwrap and geocode for a stack of interferograms.
#
#

"""grep PATTERN file | tail -1 | awk '{print \$3}'  -- last matching line's 3rd whitespace field"""
function grep_field_last(file::AbstractString, pattern::AbstractString)
    result = nothing
    for line in eachline(file)
        if occursin(pattern, line)
            result = split(line)[3]
        end
    end
    result === nothing && error("pattern not found: $pattern in $file")
    return result
end

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

function main(argv::Vector{String})
    if length(argv) != 2 && length(argv) != 3
        println("")
        println("Usage: merge_batch.csh inputfile config_file [det_stitch]")
        println("")
        println("Note: Inputfiles should be as following:")
        println("")
        println("      IF1_Swath1_Path:master.PRM:repeat.PRM,IF1_Swath2_Path:master.PRM:repeat.PRM,IF1_Swath3_Path:master.PRM:repeat.PRM")
        println("      IF2_Swath1_Path:master.PRM:repeat.PRM,IF2_Swath2_Path:master.PRM:repeat.PRM,IF1_Swath3_Path:master.PRM:repeat.PRM")
        println("      (Use the repeat PRM which contains the shift information.)")
        println("      e.g. ../F1/intf_all/2015092_2015128/:S1A20150403_ALL_F1.PRM:S1A20150509_ALL_F1.PRM,../F2/intf_all/2015092_2015128/:S1A20150403_ALL_F2.PRM:S1A20150509_ALL_F2.PRM,../F3/intf_all/2015092_2015128/:S1A20150403_ALL_F3.PRM:S1A20150509_ALL_F3.PRM")
        println("")
        println("      Make sure under each path, the processed phasefilt.grd, corr.grd and mask.grd exist.")
        println("      Also make sure the dem.grd is linked. ")
        println("      If trans.dat exits, recomputation of projection matrix will not proceed.")
        println("      The master image of firet line should be the super_master.")
        println("")
        println("      config_file is the same one used for processing.")
        println("")
        println("      set det_stitch to 1 if you want to calculate stitching position based on the NaN area in the grids")
        println("")
        println("Example: merge_batch.csh filelist batch.config")
        println("")
        exit(1)
    end

    if !isfile("dem.grd")
        println("dem.grd is required ...")
        exit(1)
    end
    local det_stitch
    if length(argv) == 3
        det_stitch = "1"
    else
        det_stitch = ""
    end

    input_file = argv[1]
    config = argv[2]
    first_line = readlines(input_file)[1]
    open("tmpm.filelist", "w") do io
        for field in split(first_line, ",")
            parts = split(field, ":")
            println(io, "../" * parts[1] * parts[2])
        end
    end

    now_dir = pwd()


    for line in readlines(input_file)
        fields = split(line, ",")
        dir_name = split(split(fields[1], ":")[1], "/")[end-1]
        mkdir(dir_name)
        cd(dir_name) do
            open("tmp.filelist", "w") do io
                for field in fields
                    println(io, "../" * field)
                end
            end
            tmpm_lines = readlines(joinpath("..", "tmpm.filelist"))
            tmp_lines = readlines("tmp.filelist")
            open("tmp", "w") do io
                for (a, b) in zip(tmpm_lines, tmp_lines)
                    println(io, "$a,$b")
                end
            end
            rm("tmp.filelist"; force=true)

            for f_name in readlines("tmp")
                comma_parts = split(f_name, ",")
                mm = comma_parts[1]
                colon_parts = split(comma_parts[2], ":")
                pth = colon_parts[1]
                f1 = colon_parts[2]
                f2 = colon_parts[3]
                cp(mm, "supermaster.PRM"; force=true)
                rshift = grep_field_last("$pth$f1", "rshift")
                run(`update_PRM supermaster.PRM rshift $rshift`)
                fs1 = grep_field("supermaster.PRM", "first_sample")
                fs2 = grep_field("$pth$f1", "first_sample")
                if parse(Float64, fs2) > parse(Float64, fs1)
                    run(`update_PRM supermaster.PRM first_sample $fs2`)
                end
                cp("supermaster.PRM", joinpath(pth, "supermaster.PRM"); force=true)
                open("tmp.filelist", "a") do io
                    println(io, "$(pth):supermaster.PRM:$f2")
                end
            end

            if isfile(joinpath("..", "trans.dat"))
                symlink(joinpath("..", "trans.dat"), "trans.dat")
            end
            if isfile(joinpath("..", "raln.grd"))
                symlink(joinpath("..", "raln.grd"), "raln.grd")
            end
            if isfile(joinpath("..", "ralt.grd"))
                symlink(joinpath("..", "ralt.grd"), "ralt.grd")
            end
            if isfile(joinpath("..", "landmask_ra.grd"))
                symlink(joinpath("..", "landmask_ra.grd"), "landmask_ra.grd")
            end
            symlink(joinpath("..", "dem.grd"), "dem.grd")
            symlink(joinpath("..", config), basename(config))
            rm("tmp"; force=true)

            if length(argv) == 3
                run(`merge_unwrap_geocode_tops.csh tmp.filelist $config $det_stitch`)
            else
                run(`merge_unwrap_geocode_tops.csh tmp.filelist $config`)
            end

            if !isfile(joinpath("..", "trans.dat")) && isfile("trans.dat")
                mv("trans.dat", joinpath("..", "trans.dat"); force=true)
                symlink(joinpath("..", "trans.dat"), "trans.dat")
            end
            if !isfile(joinpath("..", "landmask_ra.grd")) && isfile("landmask_ra.grd")
                mv("landmask_ra.grd", joinpath("..", "landmask_ra.grd"); force=true)
                symlink(joinpath("..", "landmask_ra.grd"), "landmask_ra.grd")
            end
            if !isfile(joinpath("..", "raln.grd")) && isfile("raln.grd")
                mv("raln.grd", joinpath("..", "raln.grd"); force=true)
                symlink(joinpath("..", "raln.grd"), "raln.grd")
            end
            if !isfile(joinpath("..", "ralt.grd")) && isfile("raln.grd")
                mv("ralt.grd", joinpath("..", "ralt.grd"); force=true)
                symlink(joinpath("..", "ralt.grd"), "ralt.grd")
            end
        end

    end


end

main(ARGS)
