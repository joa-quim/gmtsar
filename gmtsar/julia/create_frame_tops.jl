#!/usr/bin/env julia
#       $Id$
#
# Xiaohua(Eric) Xu, Mar 18, 2017

#
# used for creating a new frame based on two input frames.
#

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

using Printf

"""awk-style substr(s,start,len), 1-indexed"""
function substr(s::AbstractString, start::Int, len::Int)
    return s[start:(start+len-1)]
end

"""ls glob-pattern in dir (supports * wildcards), sorted like `ls`"""
function ls_glob(dir::AbstractString, globpat::AbstractString)
    parts = split(globpat, "*")
    escpart(s) = replace(s, r"([.^$|()\[\]{}+?\\])" => s"\\\1")
    pat = Regex("^" * join(escpart.(parts), ".*") * "\$")
    matches = [f for f in readdir(dir) if occursin(pat, f)]
    return sort(matches)
end

"""echo INPUT | cmd | awk '{print \$n}'"""
function pipe_in_field(cmd::Cmd, input::String, n::Int)
    out = read(pipeline(cmd, stdin=IOBuffer(input * "\n")), String)
    for line in split(out, '\n')
        if !isempty(strip(line))
            return split(line)[n]
        end
    end
    error("no output from $cmd")
end

"""grep TAG file | awk -F">" '{print \$2}' | awk -F"<" '{print \$1}'  -- text between the tag's opening and closing brackets"""
function xml_tag_text(file::AbstractString, tag::AbstractString)
    for line in readlines(file)
        if occursin(tag, line)
            after_gt = split(line, ">")[2]
            before_lt = split(after_gt, "<")[1]
            return before_lt
        end
    end
    error("$tag not found in $file")
end

"""vals... | gmt gmtinfo -C  -- pipe newline-joined values into gmt gmtinfo -C, return output fields"""
function gmtinfo_C(vals::Vector{<:AbstractString})
    input = join(vals, "\n") * "\n"
    out = read(pipeline(`gmt gmtinfo -C`, stdin=IOBuffer(input)), String)
    return split(strip(out))
end

function main(argv::Vector{String})
    if length(argv) != 3 && length(argv) != 4
        println("")
        println("Usage: create_frame_tops.jl SAFE_filelist ****.EOF two_pins.ll [observation_mode]")
        println("       create one frame based on the two input frames, precise/restituted orbit is required")
        println("")
        println("  format of two_pins.llt (lon2/lat2 comes later than lon1/lat1 in orbit time):")
        println("    lon11 lat11 [lon12 lat12] [lon13 lat13]")
        println("    lon21 lat21 [lon22 lat22] [lon23 lat23]")
        println("    (drop more columns if you want subsath 2 and 3 to have different boundaries)")
        println("")
        println("  outputs:")
        println("    new.SAFE --> datetime1-datetime2.SAFE")
        println("")
        println("  Note:")
        println("    The two input .SAFE file should be in time order, if the two_pin.llt is at wrong location, the program will output all the bursts.")
        println("    observation_mode could be vv, vh, hh, hv, default is vv")
        println("    Files listed in SAFE_filelist should be the absolute path")
        println("")
        exit(1)
    end

    mode = length(argv) == 3 ? "vv" : argv[4]

    first_line_tps = open(argv[3]) do io
        readline(io)
    end
    ncol = length(split(first_line_tps))

    println("Combining $mode data...")

    pth = pwd()
    filelist = argv[1]
    #set file1 = $1
    #set file2 = $2
    orb = argv[2]
    tps = argv[3]

    if isdir("new.SAFE")
        rm("new.SAFE"; force=true, recursive=true)
    end

    mkpath("new.SAFE")
    mkpath("new.SAFE/annotation")
    mkpath("new.SAFE/measurement")

    path_words = [strip(l) for l in readlines(filelist) if strip(l) != ""]
    a_line1 = path_words[1]

    # work on the first subswath
    println("")
    println("Working on subswath 1 ...")
    cd(joinpath(a_line1, "annotation"))
    matches0 = ls_glob(".", "*iw1*$mode*xml")
    f0 = substr(matches0[1], 1, length(matches0[1]) - 4)
    head1 = substr(f0, 1, 15)
    cd(pth)

    alist1 = String[]
    f1 = ""
    for line in path_words
        cd(joinpath(line, "annotation"))
        matches1 = ls_glob(".", "*iw1*$mode*xml")
        f1 = substr(matches1[1], 1, length(matches1[1]) - 4)
        cd(pth)

        push!(alist1, f1)

        cd("new.SAFE")
        symlink(joinpath(line, "annotation", "$f1.xml"), "$f1.xml")
        symlink(joinpath(line, "measurement", "$f1.tiff"), "$f1.tiff")
        cd("..")
    end

    cd("new.SAFE")
    run(`make_s1a_tops $f0.xml $f0.tiff tmp1 0`)
    run(`ext_orb_s1a tmp1.PRM ../$orb tmp1`)

    tps_lines = readlines(joinpath("..", tps))
    w1 = split(tps_lines[1])
    ll1 = "$(w1[1]) $(w1[2])"
    w2 = split(tps_lines[2])
    ll2 = "$(w2[1]) $(w2[2])"

    tmpazi = pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)
    run(`$GMTSAR_JULIA $(gmtsar_script("shift_atime_PRM")) tmp1.PRM $tmpazi`)
    azi1 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)) + 0.5 + parse(Float64, tmpazi))
    azi2 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll2 0", 2)) + 0.5 + parse(Float64, tmpazi))

    println("Working on bursts covering $azi1 ($ll1) - $azi2 ($ll2)...")

    run(`assemble_tops $azi1 $azi2 $(alist1) new`)

    tail1 = substr(f1, length(f1) - 16, 17)
    date_dt = xml_tag_text("new.xml", "startTime")
    date = substr(date_dt, 1, 4) * substr(date_dt, 6, 2) * substr(date_dt, 9, 2)
    t1_dt = xml_tag_text("new.xml", "startTime")
    t1 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t1_dt, 12, 2) * substr(t1_dt, 15, 2) * substr(t1_dt, 18, 9))))
    t2_dt = xml_tag_text("new.xml", "stopTime")
    t2 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t2_dt, 12, 2) * substr(t2_dt, 15, 2) * substr(t2_dt, 18, 9))))
    mv("new.xml", joinpath("annotation", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.xml"); force=true)
    mv("new.tiff", joinpath("measurement", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.tiff"); force=true)
    for f in readdir(".")
        if endswith(f, ".tiff") || endswith(f, ".xml") || startswith(f, "tmp1")
            rm(f; force=true)
        end
    end
    cd("..")

    # work on the second subswath
    println("")
    println("Working on subswath 2 ...")
    cd(joinpath(a_line1, "annotation"))
    matches0 = ls_glob(".", "*iw2*$mode*xml")
    f0 = substr(matches0[1], 1, length(matches0[1]) - 4)
    head1 = substr(f0, 1, 15)
    cd(pth)

    alist2 = String[]
    f1 = ""
    for line in path_words
        cd(joinpath(line, "annotation"))
        matches1 = ls_glob(".", "*iw2*$mode*xml")
        f1 = substr(matches1[1], 1, length(matches1[1]) - 4)
        cd(pth)

        push!(alist2, f1)

        cd("new.SAFE")
        symlink(joinpath(line, "annotation", "$f1.xml"), "$f1.xml")
        symlink(joinpath(line, "measurement", "$f1.tiff"), "$f1.tiff")
        cd("..")
    end

    cd("new.SAFE")
    run(`make_s1a_tops $f0.xml $f0.tiff tmp1 0`)
    run(`ext_orb_s1a tmp1.PRM ../$orb tmp1`)

    if ncol >= 4
        tps_lines = readlines(joinpath("..", tps))
        w1 = split(tps_lines[1])
        ll1 = "$(w1[3]) $(w1[4])"
        w2 = split(tps_lines[2])
        ll2 = "$(w2[3]) $(w2[4])"
    else
        tps_lines = readlines(joinpath("..", tps))
        w1 = split(tps_lines[1])
        ll1 = "$(w1[1]) $(w1[2])"
        w2 = split(tps_lines[2])
        ll2 = "$(w2[1]) $(w2[2])"
    end

    tmpazi = pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)
    run(`$GMTSAR_JULIA $(gmtsar_script("shift_atime_PRM")) tmp1.PRM $tmpazi`)
    azi1 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)) + 0.5 + parse(Float64, tmpazi))
    azi2 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll2 0", 2)) + 0.5 + parse(Float64, tmpazi))

    println("Working on bursts covering $azi1 ($ll1) - $azi2 ($ll2) ...")
    run(`assemble_tops $azi1 $azi2 $(alist2) new`)

    tail1 = substr(f1, length(f1) - 16, 17)
    date_dt = xml_tag_text("new.xml", "startTime")
    date = substr(date_dt, 1, 4) * substr(date_dt, 6, 2) * substr(date_dt, 9, 2)
    t1_dt = xml_tag_text("new.xml", "startTime")
    t1 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t1_dt, 12, 2) * substr(t1_dt, 15, 2) * substr(t1_dt, 18, 9))))
    t2_dt = xml_tag_text("new.xml", "stopTime")
    t2 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t2_dt, 12, 2) * substr(t2_dt, 15, 2) * substr(t2_dt, 18, 9))))
    mv("new.xml", joinpath("annotation", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.xml"); force=true)
    mv("new.tiff", joinpath("measurement", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.tiff"); force=true)
    for f in readdir(".")
        if endswith(f, ".tiff") || endswith(f, ".xml") || startswith(f, "tmp1")
            rm(f; force=true)
        end
    end
    cd("..")

    # work on the third subswath
    println("")
    println("Working on subswath 3 ...")
    cd(joinpath(a_line1, "annotation"))
    matches0 = ls_glob(".", "*iw3*$mode*xml")
    f0 = substr(matches0[1], 1, length(matches0[1]) - 4)
    head1 = substr(f0, 1, 15)
    cd(pth)

    alist3 = String[]
    f1 = ""
    for line in path_words
        cd(joinpath(line, "annotation"))
        matches1 = ls_glob(".", "*iw3*$mode*xml")
        f1 = substr(matches1[1], 1, length(matches1[1]) - 4)
        cd(pth)

        push!(alist3, f1)

        cd("new.SAFE")
        symlink(joinpath(line, "annotation", "$f1.xml"), "$f1.xml")
        symlink(joinpath(line, "measurement", "$f1.tiff"), "$f1.tiff")
        cd("..")
    end

    cd("new.SAFE")
    run(`make_s1a_tops $f0.xml $f0.tiff tmp1 0`)
    run(`ext_orb_s1a tmp1.PRM ../$orb tmp1`)

    if ncol >= 6
        tps_lines = readlines(joinpath("..", tps))
        w1 = split(tps_lines[1])
        ll1 = "$(w1[5]) $(w1[6])"
        w2 = split(tps_lines[2])
        ll2 = "$(w2[5]) $(w2[6])"
    else
        tps_lines = readlines(joinpath("..", tps))
        w1 = split(tps_lines[1])
        ll1 = "$(w1[1]) $(w1[2])"
        w2 = split(tps_lines[2])
        ll2 = "$(w2[1]) $(w2[2])"
    end

    tmpazi = pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)
    run(`$GMTSAR_JULIA $(gmtsar_script("shift_atime_PRM")) tmp1.PRM $tmpazi`)
    azi1 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll1 0", 2)) + 0.5 + parse(Float64, tmpazi))
    azi2 = trunc(Int, parse(Float64, pipe_in_field(`SAT_llt2rat tmp1.PRM 1`, "$ll2 0", 2)) + 0.5 + parse(Float64, tmpazi))

    println("Working on bursts covering $azi1 ($ll1) - $azi2 ($ll2) ...")
    run(`assemble_tops $azi1 $azi2 $(alist3) new`)

    tail1 = substr(f1, length(f1) - 16, 17)
    date_dt = xml_tag_text("new.xml", "startTime")
    date = substr(date_dt, 1, 4) * substr(date_dt, 6, 2) * substr(date_dt, 9, 2)
    t1_dt = xml_tag_text("new.xml", "startTime")
    t1 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t1_dt, 12, 2) * substr(t1_dt, 15, 2) * substr(t1_dt, 18, 9))))
    t2_dt = xml_tag_text("new.xml", "stopTime")
    t2 = @sprintf("%.6d", trunc(Int, parse(Float64, substr(t2_dt, 12, 2) * substr(t2_dt, 15, 2) * substr(t2_dt, 18, 9))))
    mv("new.xml", joinpath("annotation", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.xml"); force=true)
    mv("new.tiff", joinpath("measurement", "$head1$(date)t$(t1)-$(date)t$(t2)-$tail1.tiff"); force=true)
    for f in readdir(".")
        if endswith(f, ".tiff") || endswith(f, ".xml") || startswith(f, "tmp1")
            rm(f; force=true)
        end
    end
    cd("..")

    cp(joinpath(a_line1, "manifest.safe"), joinpath("new.SAFE", "manifest.safe"); force=true)

    # edit the name of the new .SAFE file
    println("")
    println("Editing name of the new file...")
    tail2 = substr(a_line1, length(a_line1) - 22, 23)
    xmls = ls_glob("new.SAFE/annotation", "*.xml")
    vals_t1 = [substr(f, length(f) - 43, 6) for f in xmls]
    g1 = gmtinfo_C(vals_t1)
    t1 = @sprintf("%.6d", trunc(Int, parse(Float64, g1[1])))
    vals_t2 = [substr(f, length(f) - 27, 6) for f in xmls]
    g2 = gmtinfo_C(vals_t2)
    t2 = @sprintf("%.6d", trunc(Int, parse(Float64, g2[2])))
    vals_date1 = [substr(f, length(f) - 52, 8) for f in xmls]
    g3 = gmtinfo_C(vals_date1)
    date1 = g3[1]
    head2 = substr(a_line1, length(a_line1) - 71, 17)

    newname = "$head2$(date1)T$(t1)_$(date1)T$(t2)_$tail2"
    if isdir(newname)
        rm(newname; force=true, recursive=true)
    end
    mv("new.SAFE", newname; force=true)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
