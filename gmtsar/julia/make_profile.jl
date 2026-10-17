#!/usr/bin/env julia
#       $Id$
#
#  Kurt Feigl 20150807
#
# make profile across strike
#

"""cmd | awk 'NR==2{print \$1"/"\$2}'  -- 2nd line's first two fields joined by '/'"""
function line2_slash_cmd(cmd::Cmd)
    out = read(cmd, String)
    lines = split(out, '\n')
    fields = split(lines[2])
    return "$(fields[1])/$(fields[2])"
end

function main(argv::Vector{String})
    if length(argv) != 4
        println("make profile across strike")
        println("")
        println("")
        println("Usage: make_profile.csh longitude_in_degrees latitude_in_degrees strike_in_degrees_CW_fromN step_size_in_degrees")
        println("")
        println("")
        println("")
        exit(1)
    end

    # longitude of crossing point
    maxx = argv[1]

    # latitude of crossing point
    maxy = argv[2]

    # strike in degrees clockwise from north
    dir_strike = argv[3]
    dir_cross = strip(read(`gmt math -Q $dir_strike 90. ADD 360. MOD =`, String))

    # step size in latitude
    #set step = `gmt math -Q 1 360 DIV =`
    step = argv[4]

    # draw a line through the maximum (units will be km)
    #echo $maxx $maxy
    #gmt project -G0.1 -C$maxx/$maxy -A90. -Q -L-50/50  >! profile.rsp

    ##gmt project -G0.1 -C$maxx/$maxy -A$dir_cross -Q -L-50/50  >! profile.rsp

    # make 5 more lines
    #set newy = `gmt math -Q 1 360 DIV 2. MUL $maxy EXCH SUB =`
    newxy = "$maxx/$maxy"
    #echo newxy is $newxy

    rm("profile.rsp"; force=true)
    open("profile.rsp", "w") do io end
    for j in 1:50
        #set newy = `gmt math -Q 1 360 DIV $newy ADD =`
        # calculate coordinates of a point located 0.1 km along strike
        newxy = line2_slash_cmd(`gmt project -G0.1 -C$newxy -A$dir_strike -Q -L0/0.1`)
        #echo newxy is $newxy
        open("profile.rsp", "a") do io
            println(io, ">")
        end
        open("profile.rsp", "a") do io
            run(pipeline(`gmt project -G0.1 -C$newxy -A$dir_cross -Q -L-50/50`, stdout=io))
        end
        # calculate coordinates of a point located 1 km along strike
        newxy = line2_slash_cmd(`gmt project -G0.1 -C$newxy -A$dir_strike -Q -L-0.1/0.`)
        #echo newxy is $newxy
        open("profile.rsp", "a") do io
            println(io, ">")
        end
        open("profile.rsp", "a") do io
            run(pipeline(`gmt project -G0.1 -C$newxy -A$dir_cross -Q -L-50/50`, stdout=io))
        end
    end

    println("created:")
    run(`ls -l profile.rsp`)
    exit(0)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
