#!/usr/bin/env julia
#       $Id$

# Align a stack of SLC images
# can be used to do stacking and time-series analysis

# Xiaopeng Tong, Aug 27 2010
#

include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

"""awk 'substr(\$1,start,len)'  -- 1-indexed substring, same convention as awk"""
substr(s::AbstractString, start::Int, len::Int) = s[start:(start + len - 1)]

function main(argv::Vector{String})
    if length(argv) != 1
        println("")
        println("Usage: align_batch_ALOS2_SCAN.csh align.in ")
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
    # loop over 5 subswath
    #
    for subswath in 1:5
        mkpath("F$subswath")
        cd("F$subswath") do
            symlink(joinpath("..", argv[1]), basename(argv[1]))
            #
            # make working directories
            #
            mkpath("SLC/")
            #
            # clean up
            #
            run(`$GMTSAR_JULIA $(gmtsar_script("cleanup")) SLC`)
            println("")
            println("START ALIGN A STACK OF IMAGES")
            println("")
            #
            # loop start focus and align SLC images
            #
            for line in readlines(basename(argv[1]))
                parts = split(line, ':')
                master = length(parts) >= 1 ? parts[1] : ""
                aligned = length(parts) >= 2 ? parts[2] : ""
                supermaster = length(parts) >= 3 ? parts[3] : ""
                masterstem = master == "" ? "" : substr(master, 8, length(master) - 7)
                alignedstem = aligned == "" ? "" : substr(aligned, 8, length(aligned) - 7)
                supermasterstem = supermaster == "" ? "" : substr(supermaster, 8, length(supermaster) - 7)

                if master != "" && aligned != "" && supermaster != ""
                    println(" ")
                    println("subswath: $subswath")
                    println("Align $aligned to $master via $supermaster - START")
                    cd("SLC") do
                        cp("../../raw/IMG-HH-$masterstem-F$subswath.PRM", "IMG-HH-$masterstem-F$subswath.PRM"; force=true)
                        cp("../../raw/IMG-HH-$alignedstem-F$subswath.PRM", "IMG-HH-$alignedstem-F$subswath.PRM"; force=true)
                        cp("../../raw/IMG-HH-$supermasterstem-F$subswath.PRM", "IMG-HH-$supermasterstem-F$subswath.PRM"; force=true)
                        #
                        #  need to add the SLC_file name to the master PRM's
                        #
                        run(`update_PRM IMG-HH-$masterstem-F$subswath.PRM SLC_file IMG-HH-$masterstem-F$subswath.SLC`)
                        run(`update_PRM IMG-HH-$supermasterstem-F$subswath.PRM SLC_file IMG-HH-$supermasterstem-F$subswath.SLC`)
                        symlink("../../raw/IMG-HH-$masterstem-F$subswath.SLC", "IMG-HH-$masterstem-F$subswath.SLC")
                        symlink("../../raw/IMG-HH-$alignedstem-F$subswath.SLC", "IMG-HH-$alignedstem-F$subswath.SLC")
                        symlink("../../raw/LED-$masterstem", "LED-$masterstem")
                        symlink("../../raw/LED-$alignedstem", "LED-$alignedstem")
                        symlink("../../raw/LED-$supermasterstem", "LED-$supermasterstem")
                        run(`$GMTSAR_JULIA $(gmtsar_script("align_ALOS2_SCAN")) $master-F$subswath $aligned-F$subswath $supermaster-F$subswath`)
                    end
                    println("Align $aligned to $master via $supermaster - END")
                else
                    println("")
                    println("Wrong format in align.in")
                    exit(1)
                end
            end
        end
    end

    println("")
    println("END ALIGN A STACK OF IMAGES")
    println("")
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
