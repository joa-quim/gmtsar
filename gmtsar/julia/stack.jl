#!/usr/bin/env julia
#       $Id$

# compute the mean and standard deviations of grid files

# Creator: Xiaopeng Tong, David Sandwell
# Date:    July 6th 2013

# input: a list of the gird files
# output: the mean and standard deviations of the grids


# alias rm 'rm -f'
using Printf

function main(argv::Vector{String})
    if length(argv) != 4
        println("")
        println("Usage: stack.csh  grid.list scale mean.grd std.grd ")
        println("")
        println("  compute the mean and standard deviations of grid files ")
        println("")
        println("  grid.list   --  a list of grd file names")
        println("  scale       --  a scale factor put 1 if not scale")
        println("  mean.grd    --  output file name of the mean grid ")
        println("  std.grd     --  output file name of the standard deviation grid ")
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
    scale = argv[2]
    outmean = argv[3]
    outstd = argv[4]


    # compute the mean
    println("computing the mean of the grids ..")
    num = 1
    for name in readlines(list)
        if !isfile(name)
            println(" Error: file not found: $name ")
            println("")
            exit(1)
        end
        if num == 1
            run(`gmt grdmath $name = sum.grd`)
        else
            run(`gmt grdmath $name sum.grd ADD = sumtmp.grd`)
            mv("sumtmp.grd", "sum.grd"; force=true)
        end
        num += 1
    end
    num -= 1
    run(`gmt grdmath sum.grd $num DIV = $outmean`)


    # compute the standard deviation
    println("compute the standard deviation .. ")
    num = 1
    for name in readlines(list)
        if num == 1
            run(`gmt grdmath $name $outmean SUB SQR = sum2.grd`)
        else
            run(`gmt grdmath $name $outmean SUB SQR sum2.grd ADD = sum2tmp.grd`)
            mv("sum2tmp.grd", "sum2.grd"; force=true)
        end
        num += 1
    end
    num -= 1
    run(`gmt grdmath sum2.grd $num DIV SQRT = $outstd`)

    # scale them
    run(`gmt grdmath $outmean $scale MUL = tmp.grd`)
    mv("tmp.grd", outmean; force=true)
    run(`gmt grdmath $outstd $scale MUL = tmp.grd`)
    mv("tmp.grd", outstd; force=true)

    # clean up
    rm("sum.grd"; force=true)
    rm("sum2.grd"; force=true)

    #
    #  plot the results
    #
    for fname in (outmean, outstd)
        local label
        if fname == outmean
            label = "Mean of Image Stack"
        else
            label = "Std. Dev. of Image Stack"
        end
        name = basename(fname)
        if endswith(name, ".grd")
            name = name[1:end-4]
        end
        run(`gmt grdgradient $name.grd -Nt.9 -A0. -G$name.grad.grd`)
        tmp = split(strip(read(`gmt grdinfo -C -L2 $name.grd`, String)))
        limitU = strip(@sprintf("%5.1f", parse(Float64, tmp[7])))
        limitL = strip(@sprintf("%5.1f", parse(Float64, tmp[6])))
        std = strip(@sprintf("%5.1f", parse(Float64, tmp[13])))
        run(pipeline(`gmt makecpt -Cseis -I -Z -T$limitL/$limitU/0.1 -D`, stdout="$name.cpt"))
        boundinfo = split(strip(read(`gmt grdinfo $name.grd -C`, String)))
        boundR = @sprintf("%.6g", (parse(Float64, boundinfo[3]) - parse(Float64, boundinfo[2])) / 4)
        boundA = @sprintf("%.6g", (parse(Float64, boundinfo[5]) - parse(Float64, boundinfo[4])) / 4)
        run(pipeline(`gmt grdimage $name.grd -I$name.grad.grd -C$name.cpt -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K`, stdout="$name.ps"))
        open("$name.ps", "a") do io
            run(pipeline(`gmt psscale -R$name.grd -J -DJTC+w5/0.2+h+e -C$name.cpt -Bxaf+l$label -By -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z $name.ps`)
        println("Mean of stack map: $name.pdf")
        rm("$name.cpt"; force=true)
        rm("$name.grad.grd"; force=true)
    end
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
