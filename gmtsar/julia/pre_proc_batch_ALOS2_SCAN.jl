#!/usr/bin/env julia
#       $Id$
#
#  preprocess all the data based on data.in table file and generate:
#  1. SLC files
#  2. PRM files
#  3. LED files
#  4. time-baseline plot for user to create stacking pairs

#  format in data.in table file:
#  	line 1: master_name
# 	line 2 and below: aligned_name
# alias rm 'rm -f'
# unset noclobber
#
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
    println("Usage: pre_proc_batch_ALOS2_SCAN.csh data.in batch.config")
    println("       preprocess a set of images using a common radius")
    println("       preprocess all 5 subswaths ")
    println("")
    println("       format of data.in is:")
    println("         line 1: master_name ")
    println("         line 2 and below: aligned_name")
    println("")
    println("       example of data.in for ALOS2 SCANSAR is:")
    println("         IMG-HH-ALOS2047473650-150410-WBDR1.1__D")
    println("         IMG-HH-ALOS2101293650-160408-WBDR1.1__D")
    println("")
    println("Example: pre_proc_batch_ALOS2_SCAN.csh data.in batch.config")
    println("")
    exit(1)
  end

  datafile = argv[1]
  config = argv[2]

#
# read parameters from configuration file
#
  earth_radius = grep_field_opt(config, "earth_radius")
  SLC_factor = grep_field_opt(config, "SLC_factor")

  commandline = String[]
  if earth_radius != ""
    push!(commandline, "-radius", earth_radius)
  end
  if SLC_factor != ""
    push!(commandline, "-SLC_factor", SLC_factor)
  end

  println(join(commandline, " "))
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
# loop over 5 subswath
#
  for subswath in 1:5
#
# unpack the master if necessary
#
  if !isfile("IMG-HH-$master-F$subswath.SLC") || !isfile("IMG-HH-$master-F$subswath.PRM")
    println("ALOS_pre_process_SLC IMG-HH-$master-F$subswath LED-$master -ALOS2 $(join(commandline, " "))")
    run(`ALOS_pre_process_SLC IMG-HH-$master-F$subswath LED-$master -ALOS2 $commandline`)
  end

  RAD = grep_field("IMG-HH-$master-F$subswath.PRM", "earth_radius")
  rng_samp_rate_m = grep_field_int("IMG-HH-$master-F$subswath.PRM", "rng_samp_rate")

  run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$master-F$subswath.PRM`, stdout="baseline_table.dat"))
  run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$master-F$subswath.PRM GMT`, stdout="table.gmt"))
#
# loop and unpack the aligned image using the same earth radius as the master image
#
  aligned_lines = readlines(datafile)[2:end]
  for line2 in aligned_lines
    w2 = split(line2)
    isempty(w2) && continue
    println("pre_proc_batch.csh")
    println("preprocess aligned images")

    aligned = substr(w2[1], 8, length(w2[1]) - 7)
    if !isfile("IMG-HH-$aligned-F$subswath.SLC") || !isfile("IMG-HH-$aligned-F$subswath.PRM")
      println("ALOS_pre_process_SLC IMG-HH-$aligned-F$subswath LED-$aligned -ALOS2 -radius $RAD -SLC_factor $SLC_factor")
      run(`ALOS_pre_process_SLC IMG-HH-$aligned-F$subswath LED-$aligned -ALOS2 -radius $RAD -SLC_factor $SLC_factor`)
    end
#
# check the range sampling rate of the aligned images and do conversion if necessary
#
    rng_samp_rate_s = grep_field_int("IMG-HH-$aligned-F$subswath.PRM", "rng_samp_rate")
    t = @sprintf("%1.1f", rng_samp_rate_m / rng_samp_rate_s)
    if t == "1.0"
      println("The range sampling rate for master and aligned images are: $rng_samp_rate_m")
#
      open("baseline_table.dat", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$aligned-F$subswath.PRM`, stdout=io))
      end
      open("table.gmt", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$aligned-F$subswath.PRM GMT`, stdout=io))
      end
    elseif t == "2.0"
      println("Convert the aligned image from FBD to FBS mode")
      run(`ALOS_fbd2fbs_SLC IMG-HH-$aligned-F$subswath.PRM IMG-HH-$aligned-F$(subswath)_FBS.PRM`)
#
      open("baseline_table.dat", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$aligned-F$(subswath)_FBS.PRM`, stdout=io))
      end
      open("table.gmt", "a") do io
        run(pipeline(`baseline_table.csh IMG-HH-$master-F$subswath.PRM IMG-HH-$aligned-F$(subswath)_FBS.PRM GMT`, stdout=io))
      end
      println("Overwriting the old aligned image")
      mv("IMG-HH-$aligned-F$(subswath)_FBS.PRM", "IMG-HH-$aligned-F$subswath.PRM"; force=true)
      run(`update_PRM IMG-HH-$aligned-F$subswath.PRM input_file IMG-HH-$aligned-F$subswath.SLC`)
      mv("IMG-HH-$aligned-F$(subswath)_FBS.SLC", "IMG-HH-$aligned-F$subswath.SLC"; force=true)

    elseif t == "0.5"
      println("Use FBS mode image as master")
      exit(1)
    else
      println("The range sampling rate for master and aligned images are not convertable")
      exit(1)
    end

# end of the loop over aligned images
  end

# end of the loop over subswath
  end
#
# make baseline plots
#

  open("text", "w") do io
    for line in eachline("table.gmt")
      w = split(line)
      year = 2014.5 + (parse(Float64, w[1]) - 181) / 365.25
      println(io, "$(@sprintf("%.6g", year)) $(w[2]) $(w[7])")
    end
  end
#  awk '{print 2014.5+($1-181)/365.25,$2,9,$4,$5,$6,$7}' < table.gmt > text
  info = split(strip(read(`gmt gmtinfo text -C`, String)))
  region = [
    @sprintf("%.6g", parse(Float64, info[1]) - 0.5),
    @sprintf("%.6g", parse(Float64, info[2]) + 0.5),
    @sprintf("%.6g", parse(Float64, info[3]) - 500),
    @sprintf("%.6g", parse(Float64, info[4]) + 500),
  ]
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
