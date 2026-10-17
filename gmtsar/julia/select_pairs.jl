#!/usr/bin/env julia
#       $Id$

# Select pairs according to the given threshold in time and baseline
# used for time series analysis

# Xiaohua(Eric) Xu, Jan 21 2016
#

function main(argv::Vector{String})
    if length(argv) != 3
        println("")
        println("Usage: select_pairs.csh baseline_table.dat threshold_time threshold_baseline")
        println("  generate the input file for intf_tops.csh with given threshold of time and baseline")
        println("")
        println("  outputs:")
        println("    intf.in")
        println("")
        exit(1)
    end

    file = argv[1]
    dt = argv[2]
    db = argv[3]

    # loop over possible pairs
    rm("intf.in"; force=true)

    open("text", "w") do io
        for line in readlines(argv[1])
            w = split(line)
            v = 2014 + parse(Float64, w[3]) / 365.25
            println(io, "$v $(w[5]) $(w[1])")
        end
    end
    gmtinfo_out = read(`gmt gmtinfo text -C`, String)
    gi = split(strip(gmtinfo_out))
    region = [
        string(parse(Float64, gi[1]) - 0.5),
        string(parse(Float64, gi[2]) + 0.5),
        string(parse(Float64, gi[3]) - 50),
        string(parse(Float64, gi[4]) + 50),
    ]
    open("baseline.ps", "w") do io
        run(pipeline(`gmt pstext text -JX8.8i/6.8i -R$(region[1])/$(region[2])/$(region[3])/$(region[4]) -D0.2/0.2 -X1.5i -Y1i -K -N -F+f8,Helvetica+j5`, stdout=io))
    end

    pair_tokens = String[]
    for line in readlines(file)
        w = split(line)
        push!(pair_tokens, join(w[1:5], ":"))
    end

    for line1 in pair_tokens
        for line2 in pair_tokens
            parts1 = split(line1, ':')
            parts2 = split(line2, ':')
            t1 = parse(Float64, parts1[3])
            t2 = parse(Float64, parts2[3])
            b1 = parse(Float64, parts1[5])
            b2 = parse(Float64, parts2[5])
            n1 = parts1[1]
            n2 = parts2[1]
            #if ($t1 < $t2 && $t2 - $t1 < $dt && $db0 < $db) then
            if (t1 < t2) & (t2 - t1 < parse(Float64, dt))
                db0 = trunc(Int, sqrt((b1 - b2) * (b1 - b2)))
                if db0 < parse(Float64, db)
                    open("intf.in", "a") do io
                        println(io, "$n1:$n2")
                    end
                    open("tmp", "a") do io
                        println(io, "$(t1 / 365.25 + 2014) $b1")
                    end
                    open("tmp", "a") do io
                        println(io, "$(t2 / 365.25 + 2014) $b2")
                    end
                    open("baseline.ps", "a") do io
                        run(pipeline(`gmt psxy tmp -R -J -K -O`, stdout=io))
                    end
                    rm("tmp"; force=true)
                end
            end
        end
    end

    open("text2", "w") do io
        for line in readlines("text")
            w = split(line)
            println(io, "$(w[1]) $(w[2])")
        end
    end
    open("baseline.ps", "a") do io
        run(pipeline(`gmt psxy text2 -Sp0.2c -G0 -R -JX -Ba0.5:"year":/a50g00f25:"baseline (m)":WSen -O`, stdout=io))
    end
    run(`gmt psconvert baseline.ps -Tf -A`)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
