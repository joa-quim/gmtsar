#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong and David Sandwell
#  FEB 4 2010
#  Matt Wei May 4 2010, ENVISAT
#  DTS - May 26, 2010, added phase gadient
#  EF, DTS, XT - Jan 10 2014, TSX
#
# Convolve the real.grd and imag.grd with gaussian filters.
# Form amplitude, phase, phase gradient, and correlation images.
#
#
# alias rm 'rm -f'
include(joinpath(@__DIR__, "gmtsar_common.jl"))   # script-to-script calls

using Printf

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field, "" if none"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in readlines(file)
        if occursin(pattern, line)
            return get(split(line), 3, "")
        end
    end
    return ""
end

"""grep PATTERN *.SUFFIX | awk 'NR == 1 {printf("%d", \$3)}'  -- first matching line (sorted glob), 3rd field, as Int"""
function grep_field_glob_int(pattern::AbstractString, suffix::AbstractString)
    files = sort(filter(f -> endswith(f, suffix), readdir(".")))
    for f in files
        for line in readlines(f)
            if occursin(pattern, line)
                return trunc(Int, parse(Float64, get(split(line), 3, "")))
            end
        end
    end
    error("pattern not found: $pattern in *$suffix")
end

"""mimic awk's default numeric print (%d-like for integral values, %.6g otherwise)"""
function awk_num(x::Float64)
    return x == round(x) ? string(Int(round(x))) : @sprintf("%.6g", x)
end

function main(argv::Vector{String})
    #
    run(`gmt set IO_NC4_CHUNK_SIZE classic`)
    #
    #
    # set grdimage options
    #
    scale = "-JX6.5i"
    thresh = "5.e-21"
    run(`gmt set COLOR_MODEL = hsv`)
    run(`gmt set PROJ_LENGTH_UNIT = inch`)

    if length(argv) < 4 || length(argv) > 7
        # errormessage:
        println("")
        println("Usage: filter.csh master.PRM aligned.PRM filter decimation [rng_dec azi_dec] [compute_phase_gradient]")
        println("")
        println(" Apply gaussian filter to amplitude and phase images.")
        println(" ")
        println(" filter -  wavelength of the filter in meters (0.5 gain)")
        println(" decimation - (1) better resolution, (2) smaller files")
        println(" ")
        println("Example: filter.csh IMG-HH-ALPSRP055750660-H1.0__A.PRM IMG-HH-ALPSRP049040660-H1.0__A.PRM 300  2")
        println("")
        exit(1)
    end
    println("filter.csh")
    #
    # define filter and decimation variables
    #
    sharedir = strip(read(`$GMTSAR_JULIA $(gmtsar_script("gmtsar_sharedir"))`, String))
    filter3 = "$sharedir/filters/fill.3x3"
    filter4 = "$sharedir/filters/xdir"
    filter5 = "$sharedir/filters/ydir"
    dec = argv[4]
    az_lks = 4
    PRF = grep_field_glob_int("PRF", ".PRM")
    if PRF < 1000
        az_lks = 1
    end
    #
    # look for range sampling rate
    #
    rng_samp_rate_str = grep_field(argv[1], "rng_samp_rate")
    #
    # set the range spacing in units of image range pixel size
    #
    local dec_rng, filter1
    if rng_samp_rate_str != ""
        rng_samp_rate = trunc(Int, parse(Float64, rng_samp_rate_str))
        if rng_samp_rate > 110000000
            dec_rng = 4
            filter1 = "$sharedir/filters/gauss15x5"
        elseif rng_samp_rate < 110000000 && rng_samp_rate > 20000000
            dec_rng = 2
            filter1 = "$sharedir/filters/gauss15x5"
            #
            # special for TOPS mode
            #
            if az_lks == 1
                filter1 = "$sharedir/filters/gauss5x5"
            end
        else
            dec_rng = 1
            filter1 = "$sharedir/filters/gauss15x3"
        end
    else
        println("Undefined rng_samp_rate in the master PRM file")
        exit(1)
    end
    #
    # determine whether to run phase gradient
    #
    compute_phase_gradient = 0
    if length(argv) == 5
        compute_phase_gradient = parse(Int, argv[5])
    end
    if length(argv) == 7
        compute_phase_gradient = parse(Int, argv[7])
    end
    #
    # set az_lks and dec_rng to 1 for odd decimation
    #
    if length(argv) == 6 || length(argv) == 7
        jud = mod(parse(Int, argv[6]), 2) == 0 ? 1 : 0
        if jud == 0
            az_lks = 1
        end
        jud = mod(parse(Int, argv[5]), 2) == 0 ? 1 : 0
        if jud == 0
            dec_rng = 1
        end
    end

    #
    #  make the custom filter2 and set the decimation
    #
    for f in readdir(".")
        if startswith(f, "gauss_")
            rm(f; force=true, recursive=true)
        end
    end
    run(pipeline(`gmt make_gaussian_filter -A$(argv[1]) -X$dec_rng -Y$az_lks -W$(argv[3])`, stdout="ijdec"))
    filter2 = "gauss_$(argv[3])"
    decval = parse(Float64, dec)
    idec_words = String[]
    jdec_words = String[]
    for line in readlines("ijdec")
        w = split(line)
        push!(idec_words, awk_num(decval * parse(Float64, w[1])))
        push!(jdec_words, awk_num(decval * parse(Float64, w[2])))
    end
    idec = join(idec_words, " ")
    jdec = join(jdec_words, " ")
    if length(argv) == 6 || length(argv) == 7
        idec = string(trunc(Int, parse(Float64, argv[6]) / az_lks))
        jdec = string(trunc(Int, parse(Float64, argv[5]) / dec_rng))
        println("setting range_dec = $(argv[5]), azimuth_dec = $(argv[6])")
    end
    println("$filter2 $idec $jdec ($az_lks $dec_rng)")
    #
    # filter the two amplitude images
    #
    println("making amplitudes...")
    run(`gmt conv -X$az_lks -Y$dec_rng -C$filter1 -I$(argv[1]) -Gamp1_tmp.grd=bf`)
    run(`gmt conv -X$idec -Y$jdec -C$filter2 -Iamp1_tmp.grd=bf -Gamp1.grd`)
    rm("amp1_tmp.grd"; force=true)
    run(`gmt conv -X$az_lks -Y$dec_rng -C$filter1 -I$(argv[2]) -Gamp2_tmp.grd=bf`)
    run(`gmt conv -X$idec -Y$jdec -C$filter2 -Iamp2_tmp.grd=bf -Gamp2.grd`)
    rm("amp2_tmp.grd"; force=true)
    #
    # filter the real and imaginary parts of the interferogram
    #
    println("filtering interferogram...")
    run(`gmt conv -X$az_lks -Y$dec_rng -C$filter1 -Ireal.grd=bf -Greal_tmp.grd=bf`)
    run(`gmt conv -X$idec -Y$jdec -C$filter2 -Ireal_tmp.grd=bf -Grealfilt.grd`)
    run(`gmt conv -X$az_lks -Y$dec_rng -C$filter1 -Iimag.grd=bf -Gimag_tmp.grd=bf`)
    run(`gmt conv -X$idec -Y$jdec -C$filter2 -Iimag_tmp.grd=bf -Gimagfilt.grd`)
    #
    # also compute gradients and filter them the same way
    #
    if compute_phase_gradient != 0
        println("filtering for phase gradient . . ")
        run(`gmt conv -X1 -Y1 -C$filter4 -Ireal_tmp.grd -Gxt.grd=bf`)
        run(`gmt conv -X1 -Y1 -C$filter5 -Ireal_tmp.grd -Gyt.grd=bf`)
        run(`gmt conv -X$idec -Y$jdec -C$filter2 -Ixt.grd=bf -Gxreal.grd`)
        run(`gmt conv -X$idec -Y$jdec -C$filter2 -Iyt.grd=bf -Gyreal.grd`)
        rm("xt.grd"; force=true)
        rm("yt.grd"; force=true)
        run(`gmt conv -X1 -Y1 -C$filter4 -Iimag_tmp.grd -Gxt.grd=bf`)
        run(`gmt conv -X1 -Y1 -C$filter5 -Iimag_tmp.grd -Gyt.grd=bf`)
        run(`gmt conv -X$idec -Y$jdec -C$filter2 -Ixt.grd=bf -Gximag.grd`)
        run(`gmt conv -X$idec -Y$jdec -C$filter2 -Iyt.grd=bf -Gyimag.grd`)
        rm("xt.grd"; force=true)
        rm("yt.grd"; force=true)
    end

    rm("real_tmp.grd"; force=true)
    rm("imag_tmp.grd"; force=true)

    #
    # form amplitude image
    #
    println("making amplitude...")
    run(`gmt grdmath realfilt.grd imagfilt.grd HYPOT = amp.grd`)
    run(`gmt grdmath amp.grd 0.5 POW FLIPUD = display_amp.grd`)
    grdinfo_out = read(`gmt grdinfo -L2 display_amp.grd`, String)
    AMAX = ""
    for line in split(grdinfo_out, '\n')
        if occursin("stdev", line)
            AMAX = awk_num(3 * parse(Float64, get(split(line), 5, "")))
            break
        end
    end
    run(pipeline(`gmt grd2cpt display_amp.grd -Z -D -L0/$AMAX -Cgray`, stdout="display_amp.cpt"))
    open("display_amp.cpt", "a") do io
        println(io, "N  255   255   254")
    end
    run(pipeline(`gmt grdimage display_amp.grd -Cdisplay_amp.cpt $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K`, stdout="display_amp.ps"))
    open("display_amp.ps", "a") do io
        run(pipeline(`gmt psscale -Rdisplay_amp.grd -J -DJTC+w5i/0.2i+h+ef -Cdisplay_amp.cpt -Bx0+l"Amplitude (histogram equalized)" -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z display_amp.ps`)
    #echo "Amplitude map: display_amp.pdf"
    #
    # form the correlation
    #
    println("making correlation...")
    run(`gmt grdmath amp1.grd amp2.grd MUL = tmp.grd`)
    run(`gmt grdmath tmp.grd $thresh GE 0 NAN = mask.grd`)
    run(`gmt grdmath amp.grd tmp.grd SQRT DIV mask.grd MUL FLIPUD = tmp2.grd=bf`)
    run(`gmt conv -X1 -Y1 -C$filter3 -Itmp2.grd=bf -Gcorr.grd`)
    run(pipeline(`gmt makecpt -T0./.8/0.1 -Cgray -Z -N`, stdout="corr.cpt"))
    open("corr.cpt", "a") do io
        println(io, "N  255   255   254")
    end
    run(pipeline(`gmt grdimage corr.grd $scale -Ccorr.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K`, stdout="corr.ps"))
    open("corr.ps", "a") do io
        run(pipeline(`gmt psscale -Rcorr.grd -J -DJTC+w5i/0.2i+h+ef -Ccorr.cpt -Baf+lCorrelation -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z corr.ps`)
    #echo "Correlation map: corr.pdf"
    #
    # form the phase
    #
    println("making phase...")
    run(`gmt grdmath imagfilt.grd realfilt.grd ATAN2 mask.grd MUL FLIPUD = phase.grd`)
    run(pipeline(`gmt makecpt -Crainbow -T-3.15/3.15/0.1 -Z -N`, stdout="phase.cpt"))
    run(pipeline(`gmt grdimage phase.grd $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K`, stdout="phase.ps"))
    open("phase.ps", "a") do io
        run(pipeline(`gmt psscale -Rphase.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -B1.57+l"Phase" -By+lrad -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z phase.ps`)
    #echo "Phase map: phase.pdf"
    #
    # compute the solid earth tide
    # uncomment lines with ##
    #
    ##ln -s ../../topo/dem.grd .
    ##tide_correction.csh $1 $2 dem.grd
    ##mv tide.grd tmp.grd
    ##gmt grdsample tmp.grd -Rimagfilt.grd -Gtide.grd
    #
    #  make the Werner/Goldstein filtered phase
    #
    println("filtering phase...")
    run(`gmt phasefilt -Bimagfilt.grd -Arealfilt.grd -Camp1.grd -Eamp2.grd -N32 -Gfiltphase.grd`)
    grdinfo_arg = strip(read(`gmt grdinfo mask.grd -I- --FORMAT_FLOAT_OUT=%.12lg`, String))
    run(`gmt grdedit filtphase.grd $grdinfo_arg`)
    run(`gmt grdmath filtphase.grd mask.grd MUL FLIPUD = phasefilt.grd`)
    rm("filtphase.grd"; force=true)
    run(pipeline(`gmt grdimage phasefilt.grd $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K`, stdout="phasefilt.ps"))
    open("phasefilt.ps", "a") do io
        run(pipeline(`gmt psscale -Rphasefilt.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l"Phase" -By+lrad -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z phasefilt.ps`)
    #echo "Filtered phase map: phasefilt.pdf"
    #
    #  form the phase gradients
    #
    if compute_phase_gradient != 0
        println("making phase gradient...")
        run(`gmt grdmath amp.grd 2. POW = amp_pow.grd`)
        run(`gmt grdmath realfilt.grd ximag.grd MUL imagfilt.grd xreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = xphase.grd`)
        run(`gmt grdmath realfilt.grd yimag.grd MUL imagfilt.grd yreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = yphase.grd`)
    end
    mv("mask.grd", "tmp.grd"; force=true)
    run(`gmt grdmath tmp.grd FLIPUD = mask.grd`)
    #
    # delete files
    rm("real.grd"; force=true)
    rm("imag.grd"; force=true)
    rm("tmp.grd"; force=true)
    rm("tmp2.grd"; force=true)
    rm("real.grd"; force=true)
    rm("imag.grd"; force=true)
    rm("ximag.grd"; force=true)
    rm("yimag.grd"; force=true)
    rm("xreal.grd"; force=true)
    rm("yreal.grd"; force=true)
end

main(filter(!isempty, ARGS))   # csh drops empty (unset) arguments
