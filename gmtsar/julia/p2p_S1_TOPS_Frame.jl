#!/usr/bin/env julia
#
#  Xiaohua XU, Mar 10, 2017
#
# process Sentinel-1A TOPS data
# Automatically process a single frame of interferogram.
# see instruction.txt for details.
#

# alias rm 'rm -f'
# unset noclobber
#
include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

using Printf

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

"""awk '{ print "S1_"substr(\$1,16,8)"_"substr(\$1,25,6)"_F"substr(\$1,7,1)".PRM"}'"""
stem_prm_name(name::AbstractString) = "S1_" * substr(name, 16, 8) * "_" * substr(name, 25, 6) * "_F" * substr(name, 7, 1) * ".PRM"

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field, "" if none"""
function grep_field_opt(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    return ""
end

"""ls */*IW*POL*xml | awk '{print substr(\$1,12,length(\$1)-15)}'  -- stem of the one file matching */*IW*POL*xml under cwd"""
function find_iw_stem(iw::AbstractString, pol::AbstractString)
    matches = String[]
    for d in sort(filter(isdir, readdir(".")))
        for f in sort(readdir(d))
            if occursin(iw, f) && occursin(pol, f) && endswith(f, "xml")
                push!(matches, d * "/" * f)
            end
        end
    end
    isempty(matches) && error("no file matching */*$(iw)*$(pol)*xml")
    path = matches[1]
    return substr(path, 12, length(path) - 15)
end

"""ln -s dir/*/NAME .  -- symlink the single file matching dir/*/NAME into cwd under the same basename"""
function symlink_glob_one(dir::AbstractString, name::AbstractString)
    for d in sort(filter(x -> isdir(joinpath(dir, x)), readdir(dir)))
        candidate = joinpath(dir, d, name)
        if isfile(candidate)
            symlink(candidate, name)
            return
        end
    end
    error("no file matching $dir/*/$name")
end

"""sed "s/.*threshold_geocode.*/.../g" | sed "s/.*threshold_snaphu.*/.../g" | sed "s/.*iono_skip_est.*/.../g" > dst  -- rewrite the three config lines, leaving all others untouched"""
function sanitize_config(src::AbstractString, dst::AbstractString, snaphu_val::AbstractString)
    lines = readlines(src)
    lines = [occursin("threshold_geocode", l) ? "threshold_geocode = 0" : l for l in lines]
    lines = [occursin("threshold_snaphu", l) ? "threshold_snaphu = $snaphu_val" : l for l in lines]
    lines = [occursin("iono_skip_est", l) ? "iono_skip_est = 1" : l for l in lines]
    open(dst, "w") do io
        for l in lines
            println(io, l)
        end
    end
end

"""ls DIR/*/*SUFFIX | awk NR==1'{print \$1}' | awk -F"/" '{for (i=1;i<NF;i++) printf("%s/",\$i)}'  -- directory (with trailing slash) of the first glob-sorted match"""
function first_match_dirname_slash(parent::AbstractString, suffix::AbstractString)
    subdirs = sort(filter(d -> isdir(joinpath(parent, d)), readdir(parent)))
    for d in subdirs
        full = joinpath(parent, d)
        for f in sort(readdir(full))
            if endswith(f, suffix)
                return parent * "/" * d * "/"
            end
        end
    end
    error("no file matching $parent/*/*$suffix")
end

"""cp SRC_DIR/PREFIX* .  -- copy every file in SRC_DIR whose name starts with PREFIX into cwd"""
function cp_glob(srcdir::AbstractString, prefix::AbstractString)
    isdir(srcdir) || return
    for f in readdir(srcdir)
        if startswith(f, prefix)
            cp(joinpath(srcdir, f), f; force=true)
        end
    end
end

"""ln -s dir/*/gauss* .  -- symlink every file in the one subdir matching dir/* whose name starts with "gauss" into cwd"""
function symlink_glob_gauss(dir::AbstractString)
    for d in sort(filter(x -> isdir(joinpath(dir, x)), readdir(dir)))
        for f in readdir(joinpath(dir, d))
            if startswith(f, "gauss")
                symlink(joinpath(dir, d, f), f)
            end
        end
        return
    end
end

"""merge_unwrap_geocode_tops.csh tmp.filelist CONFIG DET_STITCH  -- DET_STITCH omitted entirely when empty (csh disappearing-empty-arg behavior)"""
function run_merge_unwrap(config::AbstractString, det_stitch::AbstractString)
    if det_stitch == ""
        run(`$GMTSAR_JULIA $(gmtsar_script("merge_unwrap_geocode_tops")) tmp.filelist $config`)
    else
        run(`$GMTSAR_JULIA $(gmtsar_script("merge_unwrap_geocode_tops")) tmp.filelist $config $det_stitch`)
    end
end

function main(argv::Vector{String})
    if length(argv) != 7
        println("")
        println("Usage: p2p_S1_TOPS_Frame.csh Master.SAFE Master.EOF Aligned.SAFE Aligned.EOF config.s1a.txt polarization parallel")
        println("")
        println("Example: p2p_S1_TOPS_Frame.csh S1A_IW_SLC__1SDV_20150607T014936_20150607T015003_006261_00832E_3626.SAFE S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF S1A_IW_SLC__1SSV_20150526T014935_20150526T015002_006086_007E23_679A.SAFE S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF config.s1a.txt vv 1")
        println("")
        println("    Place the .SAFE file in the raw folder, DEM in the topo folder")
        println("    During processing, F1, F2, F3 and merge folder will be generated")
        println("    Final results will be placed in the merge folder, with phase")
        println("    corr [unwrapped phase].")
        println("    polarization = vv vh hh or hv ")
        println("    parallel = 0-sequential  1-parallel ")
        println("")
        println("Reference: Xu, X., Sandwell, D.T., Tymofyeyeva, E., González-Ortega, A. and Tong, X., ")
        println("    2017. Tectonic and Anthropogenic Deformation at the Cerro Prieto Geothermal ")
        println("    Step-Over Revealed by Sentinel-1A InSAR. IEEE Transactions on Geoscience and Remote Sensing.")
        println("")
        exit(1)
    end
    # start
    #
    # set polarization
    #
    pol = argv[6]
    println(pol)
    #
    # set processing mode seq
    #
    seq = argv[7]
    println(seq)
    #:<<supercalifragilisticexpialidocious
    #
    # determine file names
    #
    pth = pwd()
    cd("raw/$(argv[1])")
    f1m = find_iw_stem("iw1", pol)
    f2m = find_iw_stem("iw2", pol)
    f3m = find_iw_stem("iw3", pol)
    cd("../$(argv[3])")
    f1s = find_iw_stem("iw1", pol)
    f2s = find_iw_stem("iw2", pol)
    f3s = find_iw_stem("iw3", pol)
    cd(pth)

    skip_master = grep_field_opt(argv[5], "skip_master")
    if skip_master == ""
        skip_master = "0"
    end

    #if (6 == 9) then
    #
    # organize files
    #
    mkdir("F1")
    mkdir("F1/raw")
    mkdir("F1/topo")
    cd("F1")
    sanitize_config("../$(argv[5])", argv[5], "0")
    println("Linking files for Subswath 1 ...")
    cd("topo")
    symlink("../../topo/dem.grd", "dem.grd")
    cd("../raw")
    symlink("../topo/dem.grd", "dem.grd")
    symlink_glob_one("../../raw/$(argv[1])", "$f1m.xml")
    symlink_glob_one("../../raw/$(argv[1])", "$f1m.tiff")
    symlink("../../raw/$(argv[2])", "$f1m.EOF")
    symlink_glob_one("../../raw/$(argv[3])", "$f1s.xml")
    symlink_glob_one("../../raw/$(argv[3])", "$f1s.tiff")
    symlink("../../raw/$(argv[4])", "$f1s.EOF")
    cd("../..")

    mkdir("F2")
    mkdir("F2/raw")
    mkdir("F2/topo")
    cd("F2")
    sanitize_config("../$(argv[5])", argv[5], "0")
    println("Linking files for Subswath 2 ...")
    cd("topo")
    symlink("../../topo/dem.grd", "dem.grd")
    cd("../raw")
    symlink("../topo/dem.grd", "dem.grd")
    symlink_glob_one("../../raw/$(argv[1])", "$f2m.xml")
    symlink_glob_one("../../raw/$(argv[1])", "$f2m.tiff")
    symlink("../../raw/$(argv[2])", "$f2m.EOF")
    symlink_glob_one("../../raw/$(argv[3])", "$f2s.xml")
    symlink_glob_one("../../raw/$(argv[3])", "$f2s.tiff")
    symlink("../../raw/$(argv[4])", "$f2s.EOF")
    cd("../..")

    mkdir("F3")
    mkdir("F3/raw")
    mkdir("F3/topo")
    cd("F3")
    println("Linking files for Subswath 3 ...")
    sanitize_config("../$(argv[5])", argv[5], "0")
    cd("topo")
    symlink("../../topo/dem.grd", "dem.grd")
    cd("../raw")
    symlink("../topo/dem.grd", "dem.grd")
    symlink_glob_one("../../raw/$(argv[1])", "$f3m.xml")
    symlink_glob_one("../../raw/$(argv[1])", "$f3m.tiff")
    symlink("../../raw/$(argv[2])", "$f3m.EOF")
    symlink_glob_one("../../raw/$(argv[3])", "$f3s.xml")
    symlink_glob_one("../../raw/$(argv[3])", "$f3s.tiff")
    symlink("../../raw/$(argv[4])", "$f3s.EOF")
    cd("../..")
    #
    # process data
    #
    if seq == "0"
        cd("F1")
        run(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f1m $f1s $(argv[5])`)
        cd("../F2")
        run(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f2m $f2s $(argv[5])`)
        cd("../F3")
        run(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f3m $f3s $(argv[5])`)
        cd("..")
    elseif seq == "1"
        cd("F1")
        log1 = open("log", "w")
        job1 = run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f1m $f1s $(argv[5])`, stdout=log1, stderr=log1); wait=false)
        cd("../F2")
        log2 = open("log", "w")
        job2 = run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f2m $f2s $(argv[5])`, stdout=log2, stderr=log2); wait=false)
        cd("../F3")
        log3 = open("log", "w")
        job3 = run(pipeline(`$GMTSAR_JULIA $(gmtsar_script("p2p_processing")) S1_TOPS $f3m $f3s $(argv[5])`, stdout=log3, stderr=log3); wait=false)
        cd("..")
        wait(job1)
        wait(job2)
        wait(job3)
        close(log1)
        close(log2)
        close(log3)
    else
        println("Invalid mode")
        exit(0)
    end
    #supercalifragilisticexpialidocious
    #
    # merge_unwrap_geocode
    #
    #endif
    if skip_master != "2"
        mkdir("merge")
        cd("merge")
        symlink("../topo/dem.grd", "dem.grd")
        symlink_glob_gauss("../F1/intf")
        isfile("tmp.filelist") && rm("tmp.filelist"; force=true)
        pth1 = first_match_dirname_slash("../F1/intf", "PRM")
        prm1m = stem_prm_name(f1m)
        prm1s = stem_prm_name(f1s)

        #set prm1m = `ls ../F1/intf/*/*PRM | awk NR==1'{print $1}' | awk -F"/" '{print $NF}'`
        #set prm1s = `ls ../F1/intf/*/*PRM | awk NR==2'{print $1}' | awk -F"/" '{print $NF}'`
        open("tmp.filelist", "w") do io
            println(io, "$pth1:$prm1m:$prm1s")
        end

        pth2 = first_match_dirname_slash("../F2/intf", "PRM")
        prm2m = stem_prm_name(f2m)
        prm2s = stem_prm_name(f2s)

        #set prm2m = `ls ../F2/intf/*/*PRM | awk NR==1'{print $1}' | awk -F"/" '{print $NF}'`
        #set prm2s = `ls ../F2/intf/*/*PRM | awk NR==2'{print $1}' | awk -F"/" '{print $NF}'`
        open("tmp.filelist", "a") do io
            println(io, "$pth2:$prm2m:$prm2s")
        end

        pth3 = first_match_dirname_slash("../F3/intf", "PRM")
        prm3m = stem_prm_name(f3m)
        prm3s = stem_prm_name(f3s)

        #set prm3m = `ls ../F3/intf/*/*PRM | awk NR==1'{print $1}' | awk -F"/" '{print $NF}'`
        #set prm3s = `ls ../F3/intf/*/*PRM | awk NR==2'{print $1}' | awk -F"/" '{print $NF}'`
        open("tmp.filelist", "a") do io
            println(io, "$pth3:$prm3m:$prm3s")
        end


        iono = grep_field_opt("../$(argv[5])", "correct_iono")
        iono_filt_rng = grep_field_opt("../$(argv[5])", "iono_filt_rng")
        iono_filt_azi = grep_field_opt("../$(argv[5])", "iono_filt_azi")
        det_stitch = grep_field_opt("../$(argv[5])", "det_stitch")
        if iono != "0"
            sanitize_config("../$(argv[5])", argv[5], "0")
            run_merge_unwrap(argv[5], det_stitch)

            cd("..")
            mkdir("iono")
            cd("iono")
            mkdir("intf_h")
            mkdir("intf_l")
            mkdir("intf_o")
            mkdir("iono_correction")
            cd("intf_h")
            open("tmp.filelist", "w") do io
                println(io, "../../F1/iono_phase/intf_h/:$prm1m:$prm1s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F2/iono_phase/intf_h/:$prm2m:$prm2s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F3/iono_phase/intf_h/:$prm3m:$prm3s")
            end
            sanitize_config("../../$(argv[5])", argv[5], "0.1")
            symlink("../../topo/dem.grd", "dem.grd")
            symlink("../../merge/trans.dat", "trans.dat")
            run_merge_unwrap(argv[5], det_stitch)
            cp_glob("../../F1/SLC", "params")
            cd("../intf_l")

            open("tmp.filelist", "w") do io
                println(io, "../../F1/iono_phase/intf_l/:$prm1m:$prm1s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F2/iono_phase/intf_l/:$prm2m:$prm2s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F3/iono_phase/intf_l/:$prm3m:$prm3s")
            end
            sanitize_config("../../$(argv[5])", argv[5], "0.1")
            symlink("../../topo/dem.grd", "dem.grd")
            symlink("../../merge/trans.dat", "trans.dat")
            run_merge_unwrap(argv[5], det_stitch)
            cp_glob("../../F1/SLC", "params")
            cd("../intf_o")

            open("tmp.filelist", "w") do io
                println(io, "../../F1/iono_phase/intf_o/:$prm1m:$prm1s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F2/iono_phase/intf_o/:$prm2m:$prm2s")
            end
            open("tmp.filelist", "a") do io
                println(io, "../../F3/iono_phase/intf_o/:$prm3m:$prm3s")
            end
            sanitize_config("../../$(argv[5])", argv[5], "0.1")
            symlink("../../topo/dem.grd", "dem.grd")
            symlink("../../merge/trans.dat", "trans.dat")
            run_merge_unwrap(argv[5], det_stitch)
            cp_glob("../../F1/SLC", "params")
            cd("../iono_correction")

            run(`$GMTSAR_JULIA $(gmtsar_script("estimate_ionospheric_phase")) ../intf_h ../intf_l ../intf_o ../../merge $iono_filt_rng $iono_filt_azi`)
            cd("../../merge")
            symlink("../iono/iono_correction/ph_iono_orig.grd", "ph_iono_orig.grd")
            cp("../$(argv[5])", argv[5]; force=true)

            run_merge_unwrap(argv[5], det_stitch)

        else
            cp("../$(argv[5])", argv[5]; force=true)
            run_merge_unwrap(argv[5], det_stitch)

        end
    else
        println("")
        println("No radar product are produced as only master image is processed.")
        println("")
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
