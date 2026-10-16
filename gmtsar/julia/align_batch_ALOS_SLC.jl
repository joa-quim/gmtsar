#!/usr/bin/env julia
#       $Id$

# Align a stack of SLC images
# can be used to do stacking and time-series analysis

# Xiaopeng Tong, Aug 27 2010
#

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    if length(argv) != 1
        println("")
        println("Usage: align_batch_ALOS_SLC.csh align.in ")
        println("  align a set of images listed in align.in file")
        println("")
        println("  format of align.in:")
        println("    master_name:aligned_name:supermaster_name")
        println("")
        println("  example of align.in for ALOS is:")
        println("   IMG-HH-ALPSRP096010650-H1.0__A:IMG-HH-ALPSRP089300650-H1.0__A:IMG-HH-ALPSRP096010650-H1.0__A")
        println("   IMG-HH-ALPSRP096010650-H1.0__A:IMG-HH-ALPSRP236920650-H1.0__A:IMG-HH-ALPSRP096010650-H1.0__A")
        println("  ")
        println("")
        exit(1)
    end

    #
    # make working directories
    #
    mkpath("SLC/")
    #
    # clean up
    #
    run(`cleanup.csh SLC`)
    println("")
    println("START ALIGN A STACK OF IMAGES")
    println("")
    #
    # loop start focus and align SLC images
    #
    for line in readlines(argv[1])
        parts = split(line, ':')
        master = length(parts) >= 1 ? parts[1] : ""
        aligned = length(parts) >= 2 ? parts[2] : ""
        supermaster = length(parts) >= 3 ? parts[3] : ""
        masterstem = master == "" ? "" : substr(master, 8, length(master) - 7)
        alignedstem = aligned == "" ? "" : substr(aligned, 8, length(aligned) - 7)
        supermasterstem = supermaster == "" ? "" : substr(supermaster, 8, length(supermaster) - 7)

        if master != "" && aligned != "" && supermaster != ""
            println(" ")
            println("Align $aligned to $master via $supermaster - START")
            cd("SLC") do
                cp("../raw/IMG-HH-$masterstem.PRM", "IMG-HH-$masterstem.PRM"; force=true)
                cp("../raw/IMG-HH-$alignedstem.PRM", "IMG-HH-$alignedstem.PRM"; force=true)
                cp("../raw/IMG-HH-$supermasterstem.PRM", "IMG-HH-$supermasterstem.PRM"; force=true)
                #
                #  need to add the SLC_file name to the master PRM's
                #
                run(`update_PRM IMG-HH-$masterstem.PRM SLC_file IMG-HH-$masterstem.SLC`)
                run(`update_PRM IMG-HH-$supermasterstem.PRM SLC_file IMG-HH-$supermasterstem.SLC`)
                symlink("../raw/IMG-HH-$masterstem.SLC", "IMG-HH-$masterstem.SLC")
                symlink("../raw/IMG-HH-$alignedstem.SLC", "IMG-HH-$alignedstem.SLC")
                symlink("../raw/IMG-HH-$masterstem.LED", "IMG-HH-$masterstem.LED")
                symlink("../raw/IMG-HH-$alignedstem.LED", "IMG-HH-$alignedstem.LED")
                symlink("../raw/IMG-HH-$supermasterstem.LED", "IMG-HH-$supermasterstem.LED")
                run(`align_ALOS_SLC.csh $master $aligned $supermaster`)
            end
            println("Align $aligned to $master via $supermaster - END")
        else
            println("")
            println("Wrong format in align.in")
            exit(1)
        end
    end

    println("")
    println("END ALIGN A STACK OF IMAGES")
    println("")
end

main(ARGS)
