#!/usr/bin/env julia
#
#  Xiaohua XU, Jan 10, 2019
#
# process ALOS2 ScanSAR data
# Automatically process a single frame of interferogram.
#

# alias rm 'rm -f'
# unset noclobber

"""awk substr(\$1,start,len)  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

"""cmd | awk '{print \$n}'  -- nth field of the first output line"""
function field_n(cmd::Cmd, n::Int)
    out = read(cmd, String)
    for line in split(out, '\n')
        w = split(line)
        if length(w) >= n
            return w[n]
        end
    end
    error("no output line with $n fields from $cmd")
end

"""translate a shell glob pattern (only '*' wildcards) to an anchored Regex"""
function glob_to_regex(pattern::AbstractString)
    escaped = replace(pattern, r"([\.\+\(\)\[\]\^\$\|\\])" => s"\\\1")
    return Regex("^" * replace(escaped, "*" => ".*") * "\$")
end

"""ls PATTERN  -- expand a shell glob (possibly with several path components each containing
   a '*') into a sorted list of matching relative paths"""
function glob_paths(pattern::AbstractString)
    parts = split(pattern, "/")
    results = [""]
    for part in parts
        newresults = String[]
        for base in results
            dir = isempty(base) ? "." : base
            if occursin("*", part)
                isdir(dir) || continue
                rx = glob_to_regex(part)
                for entry in sort(readdir(dir))
                    if occursin(rx, entry)
                        push!(newresults, isempty(base) ? entry : joinpath(base, entry))
                    end
                end
            else
                push!(newresults, isempty(base) ? part : joinpath(base, part))
            end
        end
        results = newresults
    end
    return sort(results)
end

"""cp srcdir/PATTERN .  -- copy every file in srcdir matching a glob pattern into destdir"""
function glob_cp(srcdir::AbstractString, pattern::AbstractString, destdir::AbstractString=".")
    for f in glob_paths(joinpath(srcdir, pattern))
        cp(f, joinpath(destdir, basename(f)); force=true)
    end
end

"""sed 's/.*PATTERN.*/REPLACEMENT/g'  -- replace whole line with REPLACEMENT if it contains
   PATTERN, else keep the line unchanged"""
function sed_replace_line(lines::Vector{String}, pattern::AbstractString, replacement::AbstractString)
    return [occursin(pattern, line) ? replacement : line for line in lines]
end

function write_lines(path::AbstractString, lines::Vector{String})
    open(path, "w") do io
        for line in lines
            println(io, line)
        end
    end
end

"""the standard 3-stage sed pipeline used repeatedly in this script:
   sed 's/.*threshold_geocode.*/threshold_geocode = 0/g' src |
   sed 's/.*threshold_snaphu.*/threshold_snaphu = 0/g'    |
   sed 's/.*iono_skip_est.*/iono_skip_est = 1/g'          > dst"""
function make_local_config(src::AbstractString, dst::AbstractString)
    lines = readlines(src)
    lines = sed_replace_line(lines, "threshold_geocode", "threshold_geocode = 0")
    lines = sed_replace_line(lines, "threshold_snaphu", "threshold_snaphu = 0")
    lines = sed_replace_line(lines, "iono_skip_est", "iono_skip_est = 1")
    write_lines(dst, lines)
end

function main(argv::Vector{String})
  if length(argv) != 4
    println("")
    println("Usage: p2p_ALOS2_Scan_Frame.csh Master_stem Aligned_stem config.alos2.txt parallel")
    println("")
    println("Example: p2p_ALOS2_Scan_Frame.csh IMG-HH-ALOS2234653650-180927-WBDR1.1__D IMG-HH-ALOS2236723650-181011-WBDR1.1__D config.alos2.txt 1")
    println("")
    println("\tPlace the IMG-files and LED-files in the raw folder, DEM in the topo folder.")
    println("\tDuring processing, F1 - F5 and merge folder will be generated.")
    println("  All SLCs will be upsampled to PRF 3350 and then processed.")
    println("\tFinal results will be placed in the merge folder, with phase")
    println("\tcorr [unwrapped phase].")
    println("\tparallel = 0-sequential  1-parallel ")
    println("")
    exit(1)
  end

# start
#
# set processing mode seq
#
  arg1 = argv[1]
  arg2 = argv[2]
  config = argv[3]
  seq = parse(Int, argv[4])
  println("Processing 0-sequential  1-parallel [$seq] ...")

  master = substr(arg1, 8, length(arg1) - 7)
  aligned = substr(arg2, 8, length(arg2) - 7)

  stage = parse(Int, grep_field(config, "proc_stage"))

  iono = parse(Int, grep_field(config, "correct_iono"))
  iono_filt_rng = grep_field(config, "iono_filt_rng")
  iono_filt_azi = grep_field(config, "iono_filt_azi")
  det_stitch = grep_field(config, "det_stitch")
  mask_water = parse(Int, grep_field(config, "mask_water"))

  println("Starting at Stage $stage")

if stage < 5

#
# determine file names
#
  pth = pwd()
  for swath in 1:5
    println("Linking files for Subswath $swath ...")
    mkpath("F$swath")
    cd("F$swath")
    mkpath("raw"); mkpath("topo")
    cd("topo")
    symlink("../../topo/dem.grd", "dem.grd")
    cd("../raw")
    symlink("../../raw/$arg1-F$swath", "$arg1-F$swath")
    symlink("../../raw/$arg2-F$swath", "$arg2-F$swath")
    symlink("../../raw/LED-$master", "LED-$master-F$swath")
    symlink("../../raw/LED-$aligned", "LED-$aligned-F$swath")
    cd("..")
    make_local_config(joinpath("..", config), config)
    cd("..")
  end

#
# process data
#
  if seq == 0
    for swath in 1:5
      if stage < 2
        cd("F$swath")
        write_lines("tmp_config", sed_replace_line(readlines(config), "skip_stage", "skip_stage = 2,3,4,5,6"))
        run(`p2p_processing.csh ALOS2_SCAN $arg1-F$swath $arg2-F$swath tmp_config`)
        cd("raw")
        run(`samp_slc.csh $arg1-F$swath 3350 0`)
        run(`samp_slc.csh $arg2-F$swath 3350 0`)
        cd("..")
      end
      write_lines("tmp_config", sed_replace_line(readlines(config), "skip_stage", "skip_stage = 1"))
      run(`p2p_processing.csh ALOS2_SCAN $arg1-F$swath $arg2-F$swath tmp_config`)
      rm("tmp_config"; force=true)
      cd("..")
    end
  elseif seq == 1
    if stage < 2
      jobs = []
      for swath in 1:5
        cd("F$swath")
        write_lines("tmp_config", sed_replace_line(readlines(config), "skip_stage", "skip_stage = 2,3,4,5,6"))
        push!(jobs, run(pipeline(`p2p_processing.csh ALOS2_SCAN $arg1-F$swath $arg2-F$swath tmp_config`, stdout="log", stderr="log"); wait=false))
        cd("..")
      end
      for j in jobs
        wait(j)
      end

      jobs2 = []
      for swath in 1:5
        cd("F$swath/raw")
        push!(jobs2, run(`samp_slc.csh $arg1-F$swath 3350 0`; wait=false))
        push!(jobs2, run(`samp_slc.csh $arg2-F$swath 3350 0`; wait=false))
        cd("../..")
      end
      for j in jobs2
        wait(j)
      end
    end

    jobs3 = []
    for swath in 1:5
      cd("F$swath")
      write_lines("tmp_config", sed_replace_line(readlines(config), "skip_stage", "skip_stage = 1"))
      push!(jobs3, run(pipeline(`p2p_processing.csh ALOS2_SCAN $arg1-F$swath $arg2-F$swath tmp_config`, stdout="log", stderr="log"); wait=false))
      cd("..")
    end
    for j in jobs3
      wait(j)
    end

  else
    println("Invalid parallel mode")
    exit(1)
  end

end


#
# merge_unwrap_geocode
#

  mkpath("merge")
  cd("merge")
  symlink("../topo/dem.grd", "dem.grd")
  for f in glob_paths("../F1/intf/*/gauss*")
    symlink(f, basename(f))
  end
  make_local_config(joinpath("..", config), config)
  recompute_LUT = 1

  m1 = glob_paths("../F1/intf/*/*PRM")
  pth1 = dirname(m1[1]) * "/"
  prm1m = basename(m1[1])
  prm1s = basename(m1[2])

  m2 = glob_paths("../F2/intf/*/*PRM")
  pth2 = dirname(m2[1]) * "/"
  prm2m = basename(m2[1])
  prm2s = basename(m2[2])

  m3 = glob_paths("../F3/intf/*/*PRM")
  pth3 = dirname(m3[1]) * "/"
  prm3m = basename(m3[1])
  prm3s = basename(m3[2])

  m4 = glob_paths("../F4/intf/*/*PRM")
  pth4 = dirname(m4[1]) * "/"
  prm4m = basename(m4[1])
  prm4s = basename(m4[2])

  m5 = glob_paths("../F5/intf/*/*PRM")
  pth5 = dirname(m5[1]) * "/"
  prm5m = basename(m5[1])
  prm5s = basename(m5[2])

  open("tmp.filelist", "w") do io
    println(io, "$pth1:$prm1m:$prm1s")
    println(io, "$pth2:$prm2m:$prm2s")
    println(io, "$pth3:$prm3m:$prm3s")
  end
  stem = split(split(readlines("tmp.filelist")[1], ":")[2], ".")[1]

  if !isfile("trans.dat")
    close(open("trans.dat", "w"))
  else
    recompute_LUT = 0
  end

  run(`merge_unwrap_geocode_tops.csh tmp.filelist $config $det_stitch`)
  mv("merge_log", "merge_log1"; force=true)
  mv("tmp_phaselist", "tmp_phaselist1"; force=true)
  mkpath("tmp_first")
  mv("phasefilt.grd", "tmp_first/phasefilt.grd"; force=true)
  mv("corr.grd", "tmp_first/corr.grd"; force=true)
  mv("mask.grd", "tmp_first/mask.grd"; force=true)
  cp("$stem.PRM", "tmp_first/$stem.PRM"; force=true)
  open("tmp2.filelist", "w") do io
    println(io, "./tmp_first/:$stem.PRM:$stem.PRM")
    println(io, "$pth4:$prm4m:$prm4s")
    println(io, "$pth5:$prm5m:$prm5s")
  end
  run(`merge_unwrap_geocode_tops.csh tmp2.filelist $config det_stitch`)
  mv("merge_log", "merge_log2"; force=true)
  mv("tmp_phaselist", "tmp_phaselist2"; force=true)
  #rm -rf tmp_first

  if recompute_LUT == 1
    rm("trans.dat"; force=true)
    if !isfile("dem.grd")
      println("ERROR: missing dem.grd ... (link from the topo folder)")
      exit(1)
    end
    led = grep_field("$stem.PRM", "led_file")
    cp("$pth1$led", led; force=true)
    println("Recomputing the projection LUT...")
    run(pipeline(`gmt grd2xyz --FORMAT_FLOAT_OUT=%lf dem.grd -s`, `SAT_llt2rat $stem.PRM 1 -bod`, stdout="trans.dat"))
  end
  cd("..")

#
# ionospheric correction
#

if iono == 1

  println("")
  println("ALOS2 Ionospheric phase estimates - START")
  println("")
  mkpath("iono")
  cd("iono")
  mkpath("intf_h"); mkpath("intf_l"); mkpath("intf_o"); mkpath("iono_correction")

  cd("intf_h")
  symlink("../../topo/dem.grd", "dem.grd")
  symlink("../../merge/trans.dat", "trans.dat")
  make_local_config(joinpath("..", "..", config), config)
  open("tmp.filelist", "w") do io
    println(io, "../../F1/iono_phase/intf_h/:$prm1m:$prm1s")
    println(io, "../../F2/iono_phase/intf_h/:$prm2m:$prm2s")
    println(io, "../../F3/iono_phase/intf_h/:$prm3m:$prm3s")
  end
  run(`merge_unwrap_geocode_tops.csh tmp.filelist $config det_stitch`)
  mv("merge_log", "merge_log1"; force=true)
  mv("tmp_phaselist", "tmp_phaselist1"; force=true)
  mkpath("tmp_first")
  mv("phasefilt.grd", "tmp_first/phasefilt.grd"; force=true)
  mv("corr.grd", "tmp_first/corr.grd"; force=true)
  mv("mask.grd", "tmp_first/mask.grd"; force=true)
  cp("$stem.PRM", "tmp_first/$stem.PRM"; force=true)
  open("tmp2.filelist", "w") do io
    println(io, "./tmp_first/:$stem.PRM:$stem.PRM")
    println(io, "../../F4/iono_phase/intf_h/:$prm4m:$prm4s")
    println(io, "../../F5/iono_phase/intf_h/:$prm5m:$prm5s")
  end
  write_lines(config, sed_replace_line(readlines(config), "threshold_snaphu", "threshold_snaphu = 0.1"))
  run(`merge_unwrap_geocode_tops.csh tmp2.filelist $config det_stitch`)
  mv("merge_log", "merge_log2"; force=true)
  mv("tmp_phaselist", "tmp_phaselist2"; force=true)
  run(`correct_merge_offset.csh tmp_phaselist1 merge_log1 unwrap.grd unwrap_corrected.grd`)
  run(`correct_merge_offset.csh tmp_phaselist2 merge_log2 unwrap_corrected.grd unwrap.grd`)
  rm("unwrap_corrected.grd"; force=true)
  glob_cp("../../F1/SLC", "params*")
  mv("$stem.PRM", prm1m; force=true)
  #rm -rf tmp_first
  cd("..")

  cd("intf_l")
  symlink("../../topo/dem.grd", "dem.grd")
  symlink("../../merge/trans.dat", "trans.dat")
  if mask_water == 1
    symlink("../intf_h/landmask_ra.grd", "landmask_ra.grd")
  end
  make_local_config(joinpath("..", "..", config), config)
  open("tmp.filelist", "w") do io
    println(io, "../../F1/iono_phase/intf_l/:$prm1m:$prm1s")
    println(io, "../../F2/iono_phase/intf_l/:$prm2m:$prm2s")
    println(io, "../../F3/iono_phase/intf_l/:$prm3m:$prm3s")
  end
  run(`merge_unwrap_geocode_tops.csh tmp.filelist $config det_stitch`)
  mv("merge_log", "merge_log1"; force=true)
  mv("tmp_phaselist", "tmp_phaselist1"; force=true)
  mkpath("tmp_first")
  mv("phasefilt.grd", "tmp_first/phasefilt.grd"; force=true)
  mv("corr.grd", "tmp_first/corr.grd"; force=true)
  mv("mask.grd", "tmp_first/mask.grd"; force=true)
  cp("$stem.PRM", "tmp_first/$stem.PRM"; force=true)
  open("tmp2.filelist", "w") do io
    println(io, "./tmp_first/:$stem.PRM:$stem.PRM")
    println(io, "../../F4/iono_phase/intf_l/:$prm4m:$prm4s")
    println(io, "../../F5/iono_phase/intf_l/:$prm5m:$prm5s")
  end
  write_lines(config, sed_replace_line(readlines(config), "threshold_snaphu", "threshold_snaphu = 0.1"))
  run(`merge_unwrap_geocode_tops.csh tmp2.filelist $config det_stitch`)
  mv("merge_log", "merge_log2"; force=true)
  mv("tmp_phaselist", "tmp_phaselist2"; force=true)
  run(`correct_merge_offset.csh tmp_phaselist1 merge_log1 unwrap.grd unwrap_corrected.grd`)
  run(`correct_merge_offset.csh tmp_phaselist2 merge_log2 unwrap_corrected.grd unwrap.grd`)
  rm("unwrap_corrected.grd"; force=true)
  glob_cp("../../F1/SLC", "params*")
  mv("$stem.PRM", prm1m; force=true)
  #rm -rf tmp_first
  cd("..")

  cd("intf_o")
  symlink("../../topo/dem.grd", "dem.grd")
  symlink("../../merge/trans.dat", "trans.dat")
  if mask_water == 1
    symlink("../intf_h/landmask_ra.grd", "landmask_ra.grd")
  end
  make_local_config(joinpath("..", "..", config), config)
  open("tmp.filelist", "w") do io
    println(io, "../../F1/iono_phase/intf_o/:$prm1m:$prm1s")
    println(io, "../../F2/iono_phase/intf_o/:$prm2m:$prm2s")
    println(io, "../../F3/iono_phase/intf_o/:$prm3m:$prm3s")
  end
  run(`merge_unwrap_geocode_tops.csh tmp.filelist $config det_stitch`)
  mv("merge_log", "merge_log1"; force=true)
  mv("tmp_phaselist", "tmp_phaselist1"; force=true)
  mkpath("tmp_first")
  mv("phasefilt.grd", "tmp_first/phasefilt.grd"; force=true)
  mv("corr.grd", "tmp_first/corr.grd"; force=true)
  mv("mask.grd", "tmp_first/mask.grd"; force=true)
  cp("$stem.PRM", "tmp_first/$stem.PRM"; force=true)
  open("tmp2.filelist", "w") do io
    println(io, "./tmp_first/:$stem.PRM:$stem.PRM")
    println(io, "../../F4/iono_phase/intf_o/:$prm4m:$prm4s")
    println(io, "../../F5/iono_phase/intf_o/:$prm5m:$prm5s")
  end
  write_lines(config, sed_replace_line(readlines(config), "threshold_snaphu", "threshold_snaphu = 0.1"))
  run(`merge_unwrap_geocode_tops.csh tmp2.filelist $config det_stitch`)
  mv("merge_log", "merge_log2"; force=true)
  mv("tmp_phaselist", "tmp_phaselist2"; force=true)
  run(`correct_merge_offset.csh tmp_phaselist1 merge_log1 unwrap.grd unwrap_corrected.grd`)
  run(`correct_merge_offset.csh tmp_phaselist2 merge_log2 unwrap_corrected.grd unwrap.grd`)
  rm("unwrap_corrected.grd"; force=true)
  glob_cp("../../F1/SLC", "params*")
  mv("$stem.PRM", prm1m; force=true)
  #rm -rf tmp_first
  cd("..")

  cd("iono_correction")
  run(`estimate_ionospheric_phase.csh ../intf_h ../intf_l ../intf_o ../../merge $iono_filt_rng $iono_filt_azi`)
  cd("../../")

  cd("merge")
  symlink("../iono/iono_correction/ph_iono_orig.grd", "ph_iono_orig.grd")

  println("Correcting ionosphere ...")
  run(`gmt grdsample ph_iono_orig.grd -Rphasefilt.grd -Gtmp.grd`)
  run(`gmt grdmath phasefilt.grd tmp.grd SUB PI ADD 2 PI MUL MOD PI SUB = tmp2.grd`)
  mv("phasefilt.grd", "phasefilt_orig.grd"; force=true)
  mv("tmp2.grd", "phasefilt.grd"; force=true)
  rm("tmp.grd"; force=true)
  cd("..")

  println("")
  println("ALOS2 Ionospheric phase estimates - END")
  println("")

end


  cd("merge")
  cp(joinpath("..", config), config; force=true)
  # Read in parameters
  threshold_snaphu = grep_field(config, "threshold_snaphu")
  threshold_geocode = grep_field(config, "threshold_geocode")
  region_cut = grep_field(config, "region_cut")
  defomax = grep_field(config, "defomax")
  near_interp = grep_field(config, "near_interp")

  # Unwrapping
  if region_cut == ""
    region_cut = substr(strip(read(`gmt grdinfo phasefilt.grd -I-`, String)), 3, 18)
  end
  if parse(Float64, threshold_snaphu) != 0
    if mask_water == 1
      if !isfile("landmask_ra.grd")
        run(`landmask.csh $region_cut`)
      end
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

  if parse(Float64, threshold_geocode) != 0
    println("")
    println("GEOCODE-START")
    run(`proj_ra2ll.csh trans.dat phasefilt.grd phasefilt_ll.grd`)
    run(`proj_ra2ll.csh trans.dat corr.grd corr_ll.grd`)
    run(pipeline(`gmt makecpt -Crainbow -T-3.15/3.15/0.05 -Z`, stdout="phase.cpt"))
    BT = field_n(`gmt grdinfo -C corr.grd`, 7)
    run(pipeline(`gmt makecpt -Cgray -T0/$BT/0.05 -Z -M --COLOR_NAN=red`, stdout="corr.cpt"))
    run(`grd2kml.csh phasefilt_ll phase.cpt`)
    run(`grd2kml.csh corr_ll corr.cpt`)

    if isfile("unwrap.grd")
      run(`gmt grdmath unwrap.grd mask.grd MUL = unwrap_mask.grd`)
      run(`proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd`)
      run(`proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd`)
      BT = field_n(`gmt grdinfo -C unwrap.grd`, 7)
      BL = field_n(`gmt grdinfo -C unwrap.grd`, 6)
      run(pipeline(`gmt makecpt -T$BL/$BT/0.5 -Z`, stdout="unwrap.cpt"))
      run(`grd2kml.csh unwrap_mask_ll unwrap.cpt`)
      run(`grd2kml.csh unwrap_ll unwrap.cpt`)
    end

    println("GEOCODE END")
  else
    println("SKIP GEOCODE")
  end
end

main(ARGS)
