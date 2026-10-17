#!/usr/bin/env julia
#       $Id$

# compute the mean correlation

# Creator: Xiaopeng Tong, David Sandwell
# Date:    July 6th 2013

# input: a list of the correlation gird files
# output: the mean correlation

# Reference: Synthetic Aperture Radar Interferometry, Rosen et al., 2000
function main(argv::Vector{String})
    if length(argv) != 2
        println("")
        println("Usage: stack_corr.csh list meancorr.grd")
        println("")
        println(" compute the mean correlation from a stack of correlation grid files ")
        println("")
        println("  list            --      a list of corr.grd file names")
        println("  meancorr.grd    --      output file name of the mean correlation grid ")
        println("")
        println("  note that the grid of the grd files must be consistent")
        println("")
        exit(1)
    end

    if !isfile(argv[1])
        println("")
        println("no input file found: $(argv[1])")
        println("")
        exit(1)
    end

    list = argv[1]
    out = argv[2]

    # compute the mean
    println("computing the mean correlation of the grids ..")

    num = 1
    for cor in readlines(list)
        if !isfile(cor)
            println(" Error: file not found: $cor ")
            println("")
            exit(1)
        end
        run(`gmt grdmath $cor SQR = tmp.grd`)
        if num == 1
            run(`gmt grdmath 1 tmp.grd SUB tmp.grd DIV = sum.grd`)
        else
            run(`gmt grdmath 1 tmp.grd SUB tmp.grd DIV sum.grd ADD = tmp2.grd`)
            mv("tmp2.grd", "sum.grd"; force=true)
        end
        num += 1
    end
    num -= 1
    run(`gmt grdmath 1 sum.grd $num DIV 1 ADD DIV SQRT = $out`)

    # clean up
    rm("tmp.grd"; force=true)
    rm("sum.grd"; force=true)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
