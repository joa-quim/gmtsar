#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong, Mar 2 2010
#  modified by D. Sandwell MAR 11 2010
#
#  preprocess all the data based on data.in table file and generate:
#  1. SLC files
#  2. PRM files
#  3. time-baseline plot for user to create stacking pairs

#  format in data.in table file:
#  	line 1: master_name
# 	line 2 and below: aligned_name

# alias rm 'rm -f'
# unset noclobber

using Printf

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

"""grep PATTERN file | awk '{print \$3}'  -- same, but "" (not an error) when there is no match"""
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

function main(argv::Vector{String})
#
# check the number of arguments
#
  if length(argv) != 2
    println("")
    println("Usage: pre_proc_batch_ALOS_SLC.csh data.in batch.config")
    println("       preprocess a set of images using a common rear_range and radius")
    println("")
    println("       format of data.in is:")
    println("         line 1: master_name ")
    println("         line 2 and below: aligned_name")
    println("")
    println("       example of data.in for ALOS is:")
    println("         IMG-HH-ALPSRP096010650-H1.0__A")
    println("         IMG-HH-ALPSRP089300650-H1.0__A")
    println("         IMG-HH-ALPSRP236920650-H1.0__A")
    println("")
    println("Example: pre_proc_batch_ALOS_SLC.csh data.in batch.config")
    println("")
    exit(1)
  end

  datafile = argv[1]
  config = argv[2]

#
# read parameters from configuration file
#

  num_patches = grep_field_opt(config, "num_patches")
  earth_radius = grep_field_opt(config, "earth_radius")
  SLC_factor = grep_field_opt(config, "SLC_factor")

  commandline = ""
  if !(earth_radius == "")
    commandline = "$commandline -radius $earth_radius"
  end
  if !(num_patches == "")
    commandline = "$commandline -npatch $num_patches"
  end
  if !(SLC_factor == "")
    commandline = "$commandline -SLC_factor $SLC_factor"
  end

  println(commandline)

#
# open and read data.in table
#
  println("")
  println("START PREPROCESS A STACK OF IMAGES")
  println("")
  println("preprocess master image")
  line1 = split(readlines(datafile)[1])
  master = substr(line1[1], 8, length(line1[1]) - 7)
#
# unpack the master if necessary
#
  if !isfile("IMG-HH-$master.SLC") || !isfile("IMG-HH-$master.PRM")
    println("ALOS_pre_process_SLC IMG-HH-$master LED-$master -ALOS1 $commandline")
    run(`ALOS_pre_process_SLC IMG-HH-$master LED-$master -ALOS1 $commandline`)
  end

  RAD = grep_field("IMG-HH-$master.PRM", "earth_radius")
  SLC_factor = grep_field("IMG-HH-$master.PRM", "SLC_factor")
  rng_samp_rate_m = grep_field_int("IMG-HH-$master.PRM", "rng_samp_rate")
  npatch = grep_field("IMG-HH-$master.PRM", "num_patch")

  run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM`, stdout="baseline_table.dat"))
  run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$master.PRM GMT`, stdout="table.gmt"))
#
# loop and unpack the aligned image using the same earth radius and near range as the master image
#
  aligned_lines = readlines(datafile)[2:end]
  for line2 in aligned_lines
    w2 = split(line2)
    isempty(w2) && continue
    println("pre_proc_batch.csh")
    println("preprocess aligned images")

    aligned = substr(w2[1], 8, length(w2[1]) - 7)
    if !isfile("IMG-HH-$aligned.SLC") || !isfile("IMG-HH-$aligned.PRM")
      println("ALOS_pre_process_SLC IMG-HH-$aligned LED-$aligned -ALOS1 -radius $RAD ")
      run(`ALOS_pre_process_SLC IMG-HH-$aligned LED-$aligned -ALOS1 -radius $RAD`)
    end
#
# check the range sampling rate of the aligned images and do conversion if necessary
#
    rng_samp_rate_s = grep_field_int("IMG-HH-$aligned.PRM", "rng_samp_rate")
    t = @sprintf("%1.1f\n", rng_samp_rate_m / rng_samp_rate_s)
    t = strip(t)
    if t == "1.0"
      println("The range sampling rate for master and aligned images are: " * string(rng_samp_rate_m))
#
      open("baseline_table.dat", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$aligned.PRM`, stdout=io))
      end
      open("table.gmt", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$aligned.PRM GMT`, stdout=io))
      end
    elseif t == "2.0"
      println("Convert the aligned image from FBD to FBS mode")
      run(`ALOS_fbd2fbs_SLC IMG-HH-$aligned.PRM IMG-HH-$(aligned)_FBS.PRM`)
#
      open("baseline_table.dat", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$(aligned)_FBS.PRM`, stdout=io))
      end
      open("table.gmt", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master.PRM IMG-HH-$(aligned)_FBS.PRM GMT`, stdout=io))
      end
      println("Overwriting the old aligned image")
      mv("IMG-HH-$(aligned)_FBS.PRM", "IMG-HH-$aligned.PRM"; force=true)
      run(`update_PRM IMG-HH-$aligned.PRM input_file IMG-HH-$aligned.SLC`)
      mv("IMG-HH-$(aligned)_FBS.SLC", "IMG-HH-$aligned.SLC"; force=true)

    elseif t == "0.5"
      println("Use FBS mode image as master")
      exit(1)
    else
      println("The range sampling rate for master and aligned images are not convertable")
      exit(1)
    end

# end of the loop over aligned images
  end

#
# make baseline plots
#

  open("text", "w") do io
    for line in eachline("table.gmt")
      w = split(line)
      year = 2006.5 + (parse(Float64, w[1]) - 181) / 365.25
      println(io, "$(@sprintf("%.6g", year)) $(w[2]) $(w[7])")
    end
  end
#    awk '{print 2006.5+($1-181)/365.25,$2,9,$4,$5,$6,$7}' < table.gmt > text
  info = split(strip(read(`gmt gmtinfo text -C`, String)))
  region = [
    @sprintf("%.6g", parse(Float64, info[1]) - 0.5),
    @sprintf("%.6g", parse(Float64, info[2]) + 0.5),
    @sprintf("%.6g", parse(Float64, info[3]) - 500),
    @sprintf("%.6g", parse(Float64, info[4]) + 500),
  ]
# set region = `minmax text -C | awk '{print $1-0.5, $2+0.5, -1200, 1200}'`
  run(pipeline(`gmt pstext text -JX8.8i/6.8i -R$(region[1])/$(region[2])/$(region[3])/$(region[4]) -D0.2/0.2 -X1.5i -Y1i -K -N -F+f8,Helvetica+j5`, stdout="stacktable_all.ps"))
  open("text2", "w") do io
    for line in eachline("text")
      w = split(line)
      println(io, "$(w[1]) $(w[2])")
    end
  end
  open("stacktable_all.ps", "a") do io
    run(pipeline(`gmt psxy text2 -Sp0.2c -G0 -R -JX -Ba1:"year":/a200g00f100:"baseline (m)":WSen -O`, stdout=io))
  end


  println("")
  println("END PREPROCESS A STACK OF IMAGES")
  println("")

#
# clean up the mess
#
  rm("text"; force=true)
  rm("text2"; force=true)
end

main(ARGS)
