#!/usr/bin/env julia
#
#  D. Sandwell DEC 10 2007
#
#  compute 2-6 alignment parameters from xcorr.dat
#
# alias rm 'rm -f'
# unset noclobber
#
using Printf

function main(argv::Vector{String})
    #
    # check for number of arguments
    #
    if length(argv) == 0
        println("  ")
        println("Usage: fitoffset.csh npar_rng npar_azi xcorr.dat [SNR]")
        println("  ")
        println("        npar_rng    - number of parameters to fit in range ")
        println("        npar_aiz    - number of parameters to fit in azimuth ")
        println("        xcorr.dat   - files of range and azimuth offset estimates ")
        println("        SNR         - optional SNR cutoff (default 20)")
        println("  ")
        println("Example: fitoffset.csh 3 3 freq_xcorr.dat ")
        println("  ")
        exit(1)
    end
    #
    local SNR
    if length(argv) == 4
        SNR = argv[4]
    else
        SNR = "20."
    end
    snr_val = parse(Float64, SNR)

    #
    #  first extract the range and azimuth data
    #
    open("r.xyz", "w") do io
        for line in readlines(argv[3])
            w = split(line)
            if length(w) >= 5 && parse(Float64, w[5]) > snr_val
                @printf(io, "%f %f %f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[2]))
            end
        end
    end
    open("a.xyz", "w") do io
        for line in readlines(argv[3])
            w = split(line)
            if length(w) >= 5 && parse(Float64, w[5]) > snr_val
                @printf(io, "%f %f %f \n", parse(Float64, w[1]), parse(Float64, w[3]), parse(Float64, w[4]))
            end
        end
    end
    #
    #  make sure there are enough points remaining, otherwise exit
    #
    NPTS0 = length(readlines(argv[3]))
    NPTS = length(readlines("r.xyz"))
    if NPTS < 8
        println("  ")
        println(" FAILED - not enough points to estimate parameters")
        println(" try lower SNR ")
        println(" NPTS0, NPTS  $NPTS0 $NPTS")
        println("  ")
        exit(1)
    end

    #
    # compute requested number of parameters
    #
    azi_p = argv[2]
    rng_p = argv[1]

    errbuf1 = IOBuffer()
    run(pipeline(`gmt trend2d r.xyz -Fxyz -N$(rng_p)r -V`, stdout=devnull, stderr=errbuf1))
    errtxt1 = String(take!(errbuf1))
    open("rm.coef", "w") do io
        for line in split(errtxt1, '\n')
            if occursin("oefficients", line)
                parts = split(line, ':')
                val = strip(parts[end])
                println(io, "$val 0 0 0")
            end
        end
    end

    errbuf2 = IOBuffer()
    run(pipeline(`gmt trend2d a.xyz -Fxyz -N$(azi_p)r -V`, stdout=devnull, stderr=errbuf2))
    errtxt2 = String(take!(errbuf2))
    open("am.coef", "w") do io
        for line in split(errtxt2, '\n')
            if occursin("oefficients", line)
                parts = split(line, ':')
                val = strip(parts[end])
                println(io, "$val 0 0 0")
            end
        end
    end

    open("tmp.coef", "w") do io
        for line in readlines("rm.coef")
            w = split(line)
            println(io, "$(w[1]) $(w[2]) $(w[3])")
        end
    end
    mv("tmp.coef", "rm.coef"; force=true)
    open("tmp.coef", "w") do io
        for line in readlines("am.coef")
            w = split(line)
            println(io, "$(w[1]) $(w[2]) $(w[3])")
        end
    end
    mv("tmp.coef", "am.coef"; force=true)
    rm("tmp.coef"; force=true)
    #
    #  get the data range and paste to the coeffifients
    #
    info = strip(read(`gmt gmtinfo r.xyz -C`, String))
    iw = split(info)
    open("range.coef", "w") do io
        println(io, "$(iw[1]) $(iw[2]) $(iw[3]) $(iw[4])")
    end
    rm_lines = readlines("rm.coef")
    am_lines = readlines("am.coef")
    range_lines = readlines("range.coef")
    open("rm.rng", "w") do io
        for (a, b) in zip(rm_lines, range_lines)
            println(io, "$a\t$b")
        end
    end
    open("am.rng", "w") do io
        for (a, b) in zip(am_lines, range_lines)
            println(io, "$a\t$b")
        end
    end
    rm("r.xyz"; force=true)
    rm("a.xyz"; force=true)
    rm("am.coef"; force=true)
    rm("rm.coef"; force=true)
    rm("range.coef"; force=true)
    #
    #   now convert to range coefficients
    #
    open("rshift", "w") do io
        for line in readlines("rm.rng")
            w = parse.(Float64, split(line))
            f1, f2, f3, f4, f5, f6, f7 = w[1], w[2], w[3], w[4], w[5], w[6], w[7]
            val = f1 - f2 * (f5 + f4) / (f5 - f4) - f3 * (f7 + f6) / (f7 - f6)
            println(io, val)
        end
    end
    for line in readlines("rshift")
        v = parse(Float64, line)
        if v >= 0
            @printf("%s %g \n", "rshift = ", trunc(v))
            @printf("%s %g \n", "sub_int_r = ", rem(v, 1))
        end
    end
    for line in readlines("rshift")
        v = parse(Float64, line)
        if v < 0
            @printf("%s %g \n", "rshift = ", trunc(v) - 1)
            @printf("%s %g \n", "sub_int_r = ", rem(v, 1) + 1)
        end
    end
    for line in readlines("rm.rng")
        w = parse.(Float64, split(line))
        @printf("%s %g \n", "stretch_r = ", w[2] * 2.0 / (w[5] - w[4]))
    end
    for line in readlines("rm.rng")
        w = parse.(Float64, split(line))
        @printf("%s %g \n", "a_stretch_r = ", w[3] * 2.0 / (w[7] - w[6]))
    end
    #
    #  now convert to azimuth coefficients
    #
    open("ashift", "w") do io
        for line in readlines("am.rng")
            w = parse.(Float64, split(line))
            f1, f2, f3, f4, f5, f6, f7 = w[1], w[2], w[3], w[4], w[5], w[6], w[7]
            val = f1 - f2 * (f5 + f4) / (f5 - f4) - f3 * (f7 + f6) / (f7 - f6)
            println(io, val)
        end
    end
    for line in readlines("ashift")
        v = parse(Float64, line)
        if v >= 0
            @printf("%s %g \n", "ashift = ", trunc(v))
            @printf("%s %g \n", "sub_int_a = ", rem(v, 1))
        end
    end
    for line in readlines("ashift")
        v = parse(Float64, line)
        if v < 0
            @printf("%s %g \n", "ashift = ", trunc(v) - 1)
            @printf("%s %g \n", "sub_int_a = ", rem(v, 1) + 1)
        end
    end
    for line in readlines("am.rng")
        w = parse.(Float64, split(line))
        @printf("%s %g \n", "stretch_a = ", w[2] * 2.0 / (w[5] - w[4]))
    end
    for line in readlines("am.rng")
        w = parse.(Float64, split(line))
        @printf("%s %g \n", "a_stretch_a = ", w[3] * 2.0 / (w[7] - w[6]))
    end
    #
    #  cleanup
    #
    rm("rshift"; force=true)
    rm("ashift"; force=true)
    rm("rm.rng"; force=true)
    rm("am.rng"; force=true)
    #
    #  OK we are done
    #
    #  echo " NPTS0, NPTS  " $NPTS0 $NPTS
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
