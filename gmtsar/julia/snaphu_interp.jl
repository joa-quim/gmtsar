#!/usr/bin/env julia
#       $Id$
#
#
# alias rm 'rm -f'
# unset noclobber
#
using Printf

"""cmd | cut -fN  -- Nth tab-separated field of a subprocess's captured stdout"""
function cut_field_cmd(cmd::Cmd, n::Int)
    out = strip(read(cmd, String))
    return split(out, '\t')[n]
end

function main(argv::Vector{String})
    if length(argv) < 2
        println("")
        println("snaphu_interp.csh [GMTSAR] - Unwrap the phase with nearest neighbor interpolating low coherence and blank pixels")
        println(" ")
        println("Usage: snaphu_interp.csh correlation_threshold maximum_discontinuity [<rng0>/<rngf>/<azi0>/<azif>]")
        println("")
        println("       correlation is reset to zero when < threshold")
        println("       maximum_discontinuity enables phase jumps for earthquake ruptures, etc.")
        println("       set maximum_discontinuity = 0 for continuous phase such as interseismic ")
        println("")
        println("Example: snaphu.csh .12 40 1000/3000/24000/27000")
        println("")
        println("Reference:")
        println("Chen C. W. and H. A. Zebker, Network approaches to two-dimensional phase unwrapping: intractability and two new algorithms, Journal of the Optical Society of America A, vol. 17, pp. 401-414 (2000).")
        println("Agram, P. S., & Zebker, H. A. (2009). Sparse two-dimensional phase unwrapping using regular-grid methods. IEEE Geoscience and Remote Sensing Letters, 6(2), 327-331.")
        exit(1)
    end
    #
    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end

    # prepare the files adding the correlation mask
    #
    if length(argv) == 3
        run(`gmt grdcut mask.grd -R$(argv[3]) -Gmask_patch.grd`)
        run(`gmt grdcut corr.grd -R$(argv[3]) -Gcorr_patch.grd`)
        run(`gmt grdcut phasefilt.grd -R$(argv[3]) -Gphase_patch.grd`)
    else
        symlink("mask.grd", "mask_patch.grd")
        symlink("corr.grd", "corr_patch.grd")
        symlink("phasefilt.grd", "phase_patch.grd")
    end
    #
    # create landmask
    #
    if isfile("landmask_ra.grd")
        if length(argv) == 3
            grdinfo_I = split(strip(read(`gmt grdinfo -I phase_patch.grd`, String)))
            run(`gmt grdsample landmask_ra.grd -R$(argv[3]) $grdinfo_I -Glandmask_ra_patch.grd`)
        else
            grdinfo_I = split(strip(read(`gmt grdinfo -I phase_patch.grd`, String)))
            run(`gmt grdsample landmask_ra.grd $grdinfo_I -Glandmask_ra_patch.grd`)
        end
        run(`gmt grdmath phase_patch.grd landmask_ra_patch.grd MUL = phase_patch.grd $V`)
    end
    #
    # user defined mask
    #
    if isfile("mask_def.grd")
        if length(argv) == 3
            run(`gmt grdcut mask_def.grd -R$(argv[3]) -Gmask_def_patch.grd`)
        else
            cp("mask_def.grd", "mask_def_patch.grd"; force=true)
        end
        run(`gmt grdmath corr_patch.grd mask_def_patch.grd MUL = corr_patch.grd $V`)
    end

    #
    # interpolate, in case there is a big vacant area, do not go too far
    #

    run(`gmt grdmath corr_patch.grd $(argv[1]) GE 0 NAN mask_patch.grd MUL = mask2_patch.grd`)
    run(`gmt grdmath corr_patch.grd 0. XOR 1. MIN = corr_patch.grd`)
    run(`gmt grdmath mask2_patch.grd corr_patch.grd MUL = corr_tmp.grd`)
    run(`gmt grdmath mask2_patch.grd phase_patch.grd MUL = phase_tmp.grd`)

    run(`nearest_grid phase_tmp.grd tmp.grd 300`)
    mv("tmp.grd", "phase_tmp.grd"; force=true)

    run(pipeline(`gmt grd2xyz phase_tmp.grd -ZTLf -do0`, stdout="phase.in"))
    run(pipeline(`gmt grd2xyz corr_tmp.grd -ZTLf -do0`, stdout="corr.in"))
    #
    # run snaphu
    #
    sharedir = strip(read(`gmtsar_sharedir.csh`, String))
    println("unwrapping phase with snaphu - higher threshold for faster unwrapping ")

    if argv[2] == "0"
        width = cut_field_cmd(`gmt grdinfo -C phase_patch.grd`, 10)
        run(`snaphu phase.in $width -f $sharedir/snaphu/config/snaphu.conf.brief -c corr.in -o unwrap.out -v -s -g conncomp.out`)
    else
        run(pipeline(`sed s/.\*DEFOMAX_CYCLE.\*/DEFOMAX_CYCLE\ \ $(argv[2])/g $sharedir/snaphu/config/snaphu.conf.brief`, stdout="snaphu.conf.brief"))
        width = cut_field_cmd(`gmt grdinfo -C phase_patch.grd`, 10)
        run(`snaphu phase.in $width -f snaphu.conf.brief -c corr.in -o unwrap.out -v -d -g conncomp.out`)
    end
    #
    # convert to grd
    #
    grdinfo_Ineg = split(strip(read(`gmt grdinfo -I- phase_patch.grd`, String)))
    grdinfo_I = split(strip(read(`gmt grdinfo -I phase_patch.grd`, String)))
    run(`gmt xyz2grd unwrap.out -ZTLf -r $grdinfo_Ineg $grdinfo_I -Gtmp.grd`)
    #Generate connected component
    run(`gmt xyz2grd conncomp.out -ZTLu -r $grdinfo_Ineg $grdinfo_I -Gconncomp.grd`)
    run(`gmt grdmath tmp.grd mask2_patch.grd MUL = tmp.grd`)
    #gmt grdmath tmp.grd mask_patch.grd MUL = tmp.grd
    #
    # detrend the unwrapped if DEFOMAX = 0 for interseismic
    #
    #if ($2 == 0) then
    #  gmt grdtrend tmp.grd -N3r -Dunwrap.grd
    #else
    mv("tmp.grd", "unwrap.grd"; force=true)
    #endif
    #
    # landmask
    if isfile("landmask_ra.grd")
        run(`gmt grdmath unwrap.grd landmask_ra_patch.grd MUL = tmp.grd $V`)
        mv("tmp.grd", "unwrap.grd"; force=true)
    end
    #
    # user defined mask
    #
    if isfile("mask_def.grd")
        run(`gmt grdmath unwrap.grd mask_def_patch.grd MUL = tmp.grd $V`)
        mv("tmp.grd", "unwrap.grd"; force=true)
    end
    #
    #  plot the unwrapped phase
    #
    run(`gmt grdgradient unwrap.grd -Nt.9 -A0. -Gunwrap_grad.grd`)
    tmp_tokens = split(strip(read(`gmt grdinfo -C -L2 unwrap.grd`, String)))
    limitU = @sprintf("%5.1f", parse(Float64, tmp_tokens[12]) + parse(Float64, tmp_tokens[13]) * 2)
    limitL = @sprintf("%5.1f", parse(Float64, tmp_tokens[12]) - parse(Float64, tmp_tokens[13]) * 2)
    std = @sprintf("%5.1f", parse(Float64, tmp_tokens[13]))
    Targ = "-T$(limitL)/$(limitU)/1"
    run(pipeline(`gmt makecpt -Cseis -I -Z $Targ -D`, stdout="unwrap.cpt"))
    c1 = split(strip(read(`gmt grdinfo unwrap.grd -C`, String)))
    boundR = @sprintf("%.6g", (parse(Float64, c1[3]) - parse(Float64, c1[2])) / 4)
    boundA = @sprintf("%.6g", (parse(Float64, c1[5]) - parse(Float64, c1[4])) / 4)
    run(pipeline(`gmt grdimage unwrap.grd -Iunwrap_grad.grd -Cunwrap.cpt -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K`, stdout="unwrap.ps"))
    open("unwrap.ps", "a") do io
        run(pipeline(`gmt psscale -Runwrap.grd -J -DJTC+w5/0.2+h+e -Cunwrap.cpt -Bxaf+lUnwrapped\ phase -By+lrad -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z unwrap.ps`)
    println("Unwrapped phase map: unwrap.pdf")
    #
    # clean up
    #
    rm("tmp.grd"; force=true)
    rm("corr_tmp.grd"; force=true)
    rm("unwrap.out"; force=true)
    rm("tmp2.grd"; force=true)
    rm("unwrap_grad.grd"; force=true)
    rm("phase_tmp.grd"; force=true)
    rm("conncomp.out"; force=true)
    rm("phase.in"; force=true)
    rm("corr.in"; force=true)
    mv("phase_patch.grd", "phasefilt_interp.grd"; force=true)
    #
    #   cleanup more
    #
    if length(argv) == 3
        mv("corr_patch.grd", "corr_cut.grd"; force=true)
    end
    rm("mask_patch.grd"; force=true)
    rm("mask3.grd"; force=true)
    rm("mask3.out"; force=true)
    rm("corr_patch.grd"; force=true)
    rm("corr_cut.grd"; force=true)
    #rm -f wrap.grd
    #
end

main(ARGS)
