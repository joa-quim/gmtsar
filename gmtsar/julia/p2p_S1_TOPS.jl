#!/usr/bin/env julia
# ==============================================================================
# p2p_S1_TOPS.jl -- Julia port of gmtsar/csh/p2p_S1_TOPS.csh
#
# EXPERIMENT: drives the full GMTSAR Sentinel-1 TOPS interferogram pipeline
# through GMT's out-of-tree supplement mechanism instead of shelling out to
# standalone GMTSAR executables. Every GMTSAR command (SAT_baseline,
# SAT_llt2rat, phasediff, conv, make_gaussian_filter, offset_topo, phasefilt,
# nearest_grid, snaphu, update_PRM) is called as a genuine GMT module --
# `gmt("SAT_baseline ...")` -- resolved by GMT's module loader against
# gmtsar.dll via GMT_CUSTOM_LIBS, exactly like grdmath or blockmedian.
#
# PREREQUISITE (one-time, or per-session):
#   using GMT
#   gmt("gmtset GMT_CUSTOM_LIBS C:/progs_cygw/GMTdev/gmtsar/compileds/WIN64/bin/gmtsar.dll")
# or bake GMT_CUSTOM_LIBS into a gmt.conf so it's picked up automatically.
#
# *** IMPORTANT / LIVE-TESTED FINDING ***
# GMTSAR's legacy modules were written as one-shot CLI tools: on a bad or
# missing input they call the historical `die()` helper, which calls C's
# `exit()`. When the module runs standalone that just ends the process --
# fine. When the SAME code runs in-process inside gmt.dll, loaded into a
# *hosting* Julia (or MATLAB/Python) process, `exit()` kills the WHOLE HOST
# PROCESS, not just the failed module call. Confirmed live in this session:
#
#   gmt("SAT_baseline -Anonexistent1.PRM -Bnonexistent2.PRM")
#   => "Can't open prmfile  nonexistent1.PRM"
#   => Julia process dies. No exception to catch -- the process is just gone.
#
# Mitigation used throughout this script: validate every required input file
# with `isfile()` in Julia BEFORE calling into a module that would otherwise
# reach a `die()` path on a missing file. This is a real, current limitation
# of the GMT-module conversion (tracked project-side), not a Julia/GMT.jl bug
# -- there is no way to catch it from the Julia side once it happens.
# ==============================================================================

using GMT
using Printf

const GMTSAR_DLL = "C:/progs_cygw/GMTdev/gmtsar/compileds/WIN64/bin/gmtsar.dll"
gmt("gmtset GMT_CUSTOM_LIBS $GMTSAR_DLL")

# ------------------------------------------------------------------------
# small helpers translating shell/awk idioms used throughout the .csh tree
# ------------------------------------------------------------------------

"""grep KEY file | awk '{print \$3}'  (config file: `key = value` or `key value`)"""
function cfg_get(file::AbstractString, key::AbstractString)
    isfile(file) || error("no configure file: $file")
    for line in eachline(file)
        w = split(line)
        if !isempty(w) && w[1] == key
            return length(w) >= 3 ? w[3] : ""
        end
    end
    return ""
end
cfg_int(file, key, default::Int) = (v = cfg_get(file, key); isempty(v) ? default : parse(Int, v))
cfg_float(file, key, default::Float64) = (v = cfg_get(file, key); isempty(v) ? default : parse(Float64, v))
cfg_str(file, key, default::AbstractString="") = (v = cfg_get(file, key); isempty(v) ? default : v)

"""grep KEY prm_file | awk '{print \$3}'  (PRM file: `key = value` lines)"""
function prm_get(file::AbstractString, key::AbstractString)
    for line in eachline(file)
        w = split(line)
        if !isempty(w) && w[1] == key
            return w[3]
        end
    end
    error("key '$key' not found in $file")
end
prm_int(file, key) = parse(Int, prm_get(file, key))
prm_float(file, key) = round(Int, parse(Float64, prm_get(file, key)))  # `awk '{printf("%d",int($3))}'`

"""Require a file to exist before handing it to a module that would
otherwise die()/exit() the whole Julia process on a missing file."""
function require_file(f::AbstractString)
    isfile(f) || error("missing required file: $f")
    return f
end

"""gmt grdinfo -C equivalent: [w e s n z0 z1 dx dy ncols nrows]"""
function grd_C(file::AbstractString)
    require_file(file)
    d = gmt("grdinfo -C $file")
    return Vector(d.data[1, :])
end
grd_R(file) = (c = grd_C(file); @sprintf("%.12g/%.12g/%.12g/%.12g", c[1], c[2], c[3], c[4]))
grd_I(file) = (c = grd_C(file); @sprintf("%.12g/%.12g", c[7], c[8]))

"""update_PRM module: -A<file> -N<param> -C<value>"""
function update_prm!(file::AbstractString, key::AbstractString, value)
    require_file(file)
    gmt("update_PRM -A$file -N$key -C$value")
end

# ==========================================================================
# dem2topo_ra.csh -> dem2topo_ra(master_prm, dem_grd; mode=0)
#   Matt WEI Feb 1 2010
#   modified by Xiaopeng Feb 9 2010
#   modified by E. Fielding, DST, XT to add TSX data Jan 10 2014
#   =======================================================================
#   script to make topography for interferograms
#   The USGS elevations are height above WGS84 so this is OK.
#   Note: interpolation_approach (mode) default is 0:surface with tension,
#         set to 1 for gmt triangulate
# ==========================================================================
function dem2topo_ra(prm::AbstractString, dem::AbstractString; mode::Int=0, tension::Float64=0.1, verbose::Bool=true)
    require_file(prm); require_file(dem)
    V = verbose ? " -V" : ""

    # ========================Mosaic topo data===============================
    # ------------------------Get bounds in radar coordinates----------------
    XMAX = prm_int(prm, "num_rng_bins")
    yvalid = prm_int(prm, "num_valid_az")
    num_patch = prm_int(prm, "num_patches")
    YMAX = yvalid * num_patch
    SC = prm_int(prm, "SC_identity")
    PRF = prm_float(prm, "PRF")
    region = "0/$XMAX/0/$YMAX"
    println("Working over $region ... ")

    # look for range sampling rate
    # set the range spacing of simulation in units of image range pixel size
    rng_samp_rate = prm_float(prm, "rng_samp_rate")
    rng = if rng_samp_rate > 0 && rng_samp_rate < 25_000_000
        1
    elseif (rng_samp_rate >= 25_000_000 && rng_samp_rate < 72_000_000) || SC == 7
        2
    elseif rng_samp_rate >= 72_000_000
        4
    else
        error("range sampling rate out of bounds")
    end
    println(" range decimation is: $rng")

    # gmt grd2xyz dem.grd -s | SAT_llt2rat prm 0|1 -bod > trans.dat
    xyz = gmt("grd2xyz --FORMAT_FLOAT_OUT=%lf $dem -s")
    precise = (SC == 10 || SC == 11) ? 1 : 0
    gmt("write trans.dat", xyz)  # SAT_llt2rat has THIS_MODULE_KEYS="" (PRM/stdin-stdout tool) -- run via stdin/stdout redirection below
    run(pipeline(`cmd /c type trans.dat`, `gmt SAT_llt2rat -A$prm -P$precise -S -bod`, stdout="trans.dat.tmp"))
    mv("trans.dat.tmp", "trans.dat"; force=true)

    # use an azimuth spacing of 2 for low PRF data such as S1 TOPS
    incR = PRF < 1000 ? rng // 2 : rng // 4
    incR_s = string(numerator(incR)) * "/" * string(denominator(incR))

    tdat = gmt("gmtconvert trans.dat -o0,1,2 -bi5d -bo3d")
    temp = gmt("blockmedian -R$region -I$incR_s -bi3d -bo3d -r$V", tdat)

    pixel = if mode == 0
        surf = try
            gmt("surface -R$region -I$incR_s -bi3d -T$tension -N1000 -r -Q$V", temp)
        catch
            nothing
        end
        gmt("surface -R$region -I$incR_s -bi3d -T$tension -N1000 -r$V", temp)
    else
        rng2 = rng * 8
        incR2 = PRF < 1000 ? "$(rng2)/16" : "$(rng2)/32"
        tri = gmt("triangulate -R$region -I$incR_s -bi3d -r$V", temp)
        meanr = gmt("blockmean -R$region -I$incR2 -bi3d -bo3d -r", temp)
        coarse = gmt("surface -R$region -I$incR2 -bi3d -T0.1 -N1000 -r", meanr)
        gmt("grdfill", tri, coarse)  # -A<coarse> is applied via positional 2nd grid in GMT.jl calling convention
    end

    # flip top to bottom for both ascending and descending passes
    topo_ra = gmt("grdmath ? FLIPUD =", pixel)
    gmt("write topo_ra.grd", topo_ra)

    # plotting
    cpt = gmt("grd2cpt -Cgray$V -Z", topo_ra)
    gmt("grdimage -JX7i -P -C -Bxaf+lRange -Byaf+l\"Reversed Azimuth\" -BWSen$V -K", topo_ra, cpt; fname="topo_ra.ps")
    gmt("psscale -R -J -DJTC+w5i/0.2i+h -Bxaf -By+lm -O", topo_ra, cpt; fname="topo_ra.ps", append=true)
    gmt("psconvert -Tf -P -A -Z topo_ra.ps")
    println("Topo range/azimuth map: topo_ra.pdf")

    # clean up
    for f in ("temp.rat", "tmp", "topo_ra.cpt")
        isfile(f) && rm(f)
    end
    return "topo_ra.grd"
end

# ==========================================================================
# slc2amp.csh -> slc2amp(prm, rng_dec, outgrd)
#   Xiaopeng Tong Nov 23 2009
#   Converts a complex SLC file to a real amplitude grd
#   file using optional filter and a PRM file
#     rng_dec is range decimation, e.g. 1 for ERS ENVISAT ALOS FBD,
#     2 for ALOS FBS, 4 for TSX
# ==========================================================================
function slc2amp(prm::AbstractString, rng_dec::Int, outgrd::AbstractString)
    require_file(prm)
    # define the filters
    sharedir = "share/gmtsar"   # gmtsar_sharedir.csh always reports "/share/gmtsar"
    fil1 = joinpath(sharedir, "filters", "gauss5x3")
    # filter the amplitudes done in conv
    println(" range decimation is: $rng_dec")
    gmt("conv -X4 -Y$rng_dec -C$fil1 -I$prm -G$(outgrd)=bf")
    # get the zmin and zmax value
    g = gmt("read $(outgrd)=bf")
    g2 = gmt("grdmath ? 1 MUL =", g)
    gmt("write $outgrd", g2)
    return outgrd
end

# ==========================================================================
# intf.csh -> intf(ref_prm, rep_prm; topo=nothing, model=nothing)
#   Xiaopeng Tong FEB 4 2010
#   Make the interferogram.
#   Matt Wei May 4 2010, ENVISAT
#   add in TSX, Jan 10 2014
# ==========================================================================
function intf(refprm::AbstractString, repprm::AbstractString; topo::Union{Nothing,String}=nothing, model::Union{Nothing,String}=nothing)
    require_file(refprm); require_file(repprm)
    # which satellite
    SC = prm_int(refprm, "SC_identity")
    SC in (1, 2, 4, 5, 6) || SC > 6 || error("Incorrect satellite id in prm file")

    cp(repprm, repprm * "0"; force=true)
    cp(refprm, refprm * "0"; force=true)

    # SAT_baseline writes baseline parameters to stdout; append last 9 lines to
    # the aligned PRM, and append the "height" line to the reference PRM --
    # exactly what `SAT_baseline $1 $2 | tail -n9 >> $2` did.
    bl = read(`gmt SAT_baseline -A$refprm -B$repprm`, String)
    open(repprm, "a") do io
        for l in last(split(bl, '\n'), 9)
            println(io, l)
        end
    end
    blh = read(`gmt SAT_baseline -A$refprm -B$refprm`, String)
    open(refprm, "a") do io
        for l in split(blh, '\n')
            occursin("height", l) && println(io, l)
        end
    end

    # form the interferogram optionally using topo_ra and modelphase
    println("intf.csh")
    println("running phasediff...")
    extra = ""
    topo !== nothing && (require_file(topo); extra *= " -T$topo")
    model !== nothing && (require_file(model); extra *= " -M$model")
    gmt("phasediff -A$refprm -B$repprm$extra")

    mv(refprm * "0", refprm; force=true)
    mv(repprm * "0", repprm; force=true)
    return ("real.grd", "imag.grd")
end

# ==========================================================================
# filter.csh -> filter_step(ref_prm, rep_prm, filter_m, dec; ...)
#   Xiaopeng Tong and David Sandwell FEB 4 2010
#   Matt Wei May 4 2010, ENVISAT
#   DTS - May 26, 2010, added phase gadient
#   EF, DTS, XT - Jan 10 2014, TSX
#
#   Convolve the real.grd and imag.grd with gaussian filters.
#   Form amplitude, phase, phase gradient, and correlation images.
#     filter (filter_m) - wavelength of the filter in meters (0.5 gain)
#     decimation (dec)  - (1) better resolution, (2) smaller files
# ==========================================================================
function filter_step(refprm::AbstractString, repprm::AbstractString, filter_m::Real, dec::Int;
                      range_dec::Union{Nothing,Int}=nothing, azimuth_dec::Union{Nothing,Int}=nothing,
                      compute_phase_gradient::Bool=false)
    require_file(refprm); require_file(repprm)
    println("filter.csh")
    # define filter and decimation variables
    sharedir = "share/gmtsar"
    filter3 = joinpath(sharedir, "filters", "fill.3x3")
    filter4 = joinpath(sharedir, "filters", "xdir")
    filter5 = joinpath(sharedir, "filters", "ydir")

    PRF = prm_float(refprm, "PRF")
    az_lks = PRF < 1000 ? 1 : 4
    # look for range sampling rate
    rng_samp_rate = prm_float(refprm, "rng_samp_rate")

    # set the range spacing in units of image range pixel size
    dec_rng, filter1 = if rng_samp_rate > 110_000_000
        4, joinpath(sharedir, "filters", "gauss15x5")
    elseif rng_samp_rate < 110_000_000 && rng_samp_rate > 20_000_000
        # special for TOPS mode
        2, (az_lks == 1 ? joinpath(sharedir, "filters", "gauss5x5") : joinpath(sharedir, "filters", "gauss15x5"))
    else
        1, joinpath(sharedir, "filters", "gauss15x3")
    end

    # set az_lks and dec_rng to 1 for odd decimation
    if range_dec !== nothing
        iseven(range_dec) || (dec_rng = 1)
    end
    if azimuth_dec !== nothing
        iseven(azimuth_dec) || (az_lks = 1)
    end

    # make the custom filter2 and set the decimation
    for f in readdir()
        startswith(f, "gauss_") && rm(f)
    end

    ijdec = read(`gmt make_gaussian_filter -A$refprm -X$dec_rng -Y$az_lks -W$filter_m`, String)
    ij = parse.(Int, split(strip(ijdec)))
    filter2 = "gauss_$(Int(filter_m))"
    gmt("make_gaussian_filter -A$refprm -X$dec_rng -Y$az_lks -W$filter_m -G$filter2")

    idec, jdec = dec * ij[1], dec * ij[2]
    if range_dec !== nothing && azimuth_dec !== nothing
        idec = azimuth_dec ÷ az_lks
        jdec = range_dec ÷ dec_rng
        println("setting range_dec = $range_dec, azimuth_dec = $azimuth_dec")
    end
    println("$filter2 $idec $jdec ($az_lks $dec_rng)")

    # filter the two amplitude images
    println("making amplitudes...")
    gmt("conv -X$az_lks -Y$dec_rng -C$filter1 -I$refprm -Gamp1_tmp.grd=bf")
    gmt("conv -X$idec -Y$jdec -C$filter2 -Iamp1_tmp.grd=bf -Gamp1.grd"); rm("amp1_tmp.grd")
    gmt("conv -X$az_lks -Y$dec_rng -C$filter1 -I$repprm -Gamp2_tmp.grd=bf")
    gmt("conv -X$idec -Y$jdec -C$filter2 -Iamp2_tmp.grd=bf -Gamp2.grd"); rm("amp2_tmp.grd")

    # filter the real and imaginary parts of the interferogram
    println("filtering interferogram...")
    gmt("conv -X$az_lks -Y$dec_rng -C$filter1 -Ireal.grd=bf -Greal_tmp.grd=bf")
    gmt("conv -X$idec -Y$jdec -C$filter2 -Ireal_tmp.grd=bf -Grealfilt.grd")
    gmt("conv -X$az_lks -Y$dec_rng -C$filter1 -Iimag.grd=bf -Gimag_tmp.grd=bf")
    gmt("conv -X$idec -Y$jdec -C$filter2 -Iimag_tmp.grd=bf -Gimagfilt.grd")

    # also compute gradients and filter them the same way
    if compute_phase_gradient
        println("filtering for phase gradient . . ")
        gmt("conv -X1 -Y1 -C$filter4 -Ireal_tmp.grd -Gxt.grd=bf")
        gmt("conv -X1 -Y1 -C$filter5 -Ireal_tmp.grd -Gyt.grd=bf")
        gmt("conv -X$idec -Y$jdec -C$filter2 -Ixt.grd=bf -Gxreal.grd")
        gmt("conv -X$idec -Y$jdec -C$filter2 -Iyt.grd=bf -Gyreal.grd")
        rm("xt.grd"); rm("yt.grd")
        gmt("conv -X1 -Y1 -C$filter4 -Iimag_tmp.grd -Gxt.grd=bf")
        gmt("conv -X1 -Y1 -C$filter5 -Iimag_tmp.grd -Gyt.grd=bf")
        gmt("conv -X$idec -Y$jdec -C$filter2 -Ixt.grd=bf -Gximag.grd")
        gmt("conv -X$idec -Y$jdec -C$filter2 -Iyt.grd=bf -Gyimag.grd")
        rm("xt.grd"); rm("yt.grd")
    end
    rm("real_tmp.grd"); rm("imag_tmp.grd")

    # form amplitude image
    scale = "-JX6.5i"
    println("making amplitude...")
    amp = gmt("grdmath realfilt.grd imagfilt.grd HYPOT =")
    gmt("write amp.grd", amp)
    display_amp = gmt("grdmath amp.grd 0.5 POW FLIPUD =")
    gmt("write display_amp.grd", display_amp)
    stats = gmt("grdinfo -L2 display_amp.grd")
    AMAX = 3 * stats.data[1, 13]   # column layout: ... stdev at pos 13 for -L2
    cpt = gmt("grd2cpt -Z -D -L0/$AMAX -Cgray", display_amp)
    open("display_amp.cpt", "a") do io; println(io, "N  255   255   254"); end
    gmt("grdimage display_amp.grd -Cdisplay_amp.cpt $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K > display_amp.ps")
    gmt("psscale -Rdisplay_amp.grd -J -DJTC+w5i/0.2i+h+ef -Cdisplay_amp.cpt -Bx0+l\"Amplitude (histogram equalized)\" -O >> display_amp.ps")
    gmt("psconvert -Tf -P -A -Z display_amp.ps")

    # form the correlation
    println("making correlation...")
    gmt("grdmath amp1.grd amp2.grd MUL = tmp.grd")
    thresh = "5.e-21"
    gmt("grdmath tmp.grd $thresh GE 0 NAN = mask.grd")
    gmt("grdmath amp.grd tmp.grd SQRT DIV mask.grd MUL FLIPUD = tmp2.grd=bf")
    gmt("conv -X1 -Y1 -C$filter3 -Itmp2.grd=bf -Gcorr.grd")
    gmt("makecpt -T0./.8/0.1 -Cgray -Z -N > corr.cpt")
    open("corr.cpt", "a") do io; println(io, "N  255   255   254"); end
    gmt("grdimage corr.grd $scale -Ccorr.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K > corr.ps")
    gmt("psscale -Rcorr.grd -J -DJTC+w5i/0.2i+h+ef -Ccorr.cpt -Baf+lCorrelation -O >> corr.ps")
    gmt("psconvert -Tf -P -A -Z corr.ps")

    # form the phase
    println("making phase...")
    gmt("grdmath imagfilt.grd realfilt.grd ATAN2 mask.grd MUL FLIPUD = phase.grd")
    gmt("makecpt -Crainbow -T-3.15/3.15/0.1 -Z -N > phase.cpt")
    gmt("grdimage phase.grd $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K > phase.ps")
    gmt("psscale -Rphase.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -B1.57+l\"Phase\" -By+lrad -O >> phase.ps")
    gmt("psconvert -Tf -P -A -Z phase.ps")

    # compute the solid earth tide -- left disabled, matching the original
    # commented-out block in filter.csh (ln -s dem.grd; tide_correction.csh;
    # gmt grdsample tmp.grd -Rimagfilt.grd -Gtide.grd)

    # make the Werner/Goldstein filtered phase
    println("filtering phase...")
    gmt("phasefilt -Arealfilt.grd -Bimagfilt.grd -Camp1.grd -Eamp2.grd -N32 -Gfiltphase.grd")
    R = grd_R("mask.grd"); I = grd_I("mask.grd")
    gmt("grdedit filtphase.grd -R$R -I$I")
    gmt("grdmath filtphase.grd mask.grd MUL FLIPUD = phasefilt.grd")
    rm("filtphase.grd")
    gmt("grdimage phasefilt.grd $scale -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K > phasefilt.ps")
    gmt("psscale -Rphasefilt.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l\"Phase\" -By+lrad -O >> phasefilt.ps")
    gmt("psconvert -Tf -P -A -Z phasefilt.ps")

    # form the phase gradients
    if compute_phase_gradient
        println("making phase gradient...")
        gmt("grdmath amp.grd 2. POW = amp_pow.grd")
        gmt("grdmath realfilt.grd ximag.grd MUL imagfilt.grd xreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = xphase.grd")
        gmt("grdmath realfilt.grd yimag.grd MUL imagfilt.grd yreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = yphase.grd")
    end
    mv("mask.grd", "tmp.grd"; force=true)
    gmt("grdmath tmp.grd FLIPUD = mask.grd")

    # delete files
    for f in ("real.grd", "imag.grd", "tmp.grd", "tmp2.grd", "ximag.grd", "yimag.grd", "xreal.grd", "yreal.grd")
        isfile(f) && rm(f)
    end
    return "phasefilt.grd"
end

# ==========================================================================
# landmask.csh -> landmask(region_cut)
#   make a landmask in radar coordinates, needs to run with trans.dat
#   NOTE: The region_cut can be specified in batch.config file
# ==========================================================================
function landmask(region_cut::AbstractString; verbose::Bool=true)
    require_file("dem.grd")
    V = verbose ? " -V" : ""
    println("\nMAKE LANDMASK -- START\nREQUIRE FULL RESOLUTION COASTLINE FROM GMT\n")
    Rneg = grd_R("dem.grd"); Ipos = grd_I("dem.grd")
    gmt("grdlandmask -Glandmask.grd -R$Rneg -I$Ipos$V -NNaN/1 -Df")
    proj_ll2ra("trans.dat", "landmask.grd", "landmask_ra.grd")
    lr = gmt("grdsample -R$region_cut -I4/8 -nl+t0.1", gmt("read landmask_ra.grd"))
    gmt("write landmask_ra.grd", lr)
    # if the landmask region is smaller than the region_cut pad with NaN
    xyz = gmt("grd2xyz -bo", gmt("read landmask_ra.grd"))
    Ineg = grd_I("landmask_ra.grd")
    g = gmt("xyz2grd -bi -r -R$region_cut -I$Ineg", xyz)
    gmt("write landmask_ra.grd", g)
    # cleanup
    isfile("landmask.grd") && rm("landmask.grd")
    println("MAKE LANDMASK -- END")
    return "landmask_ra.grd"
end

# ==========================================================================
# proj_ra2ll.csh / proj_ll2ra.csh / m2s.csh / grd2kml.csh
#   D. Sandwell 1/12/07, M. Wei 1/31/08
#   project a grd file between range/azimuth and lon/lat coordinates
#   Input:  trans.dat - file generated by llt_grid2rat (r a topo lon lat)
# ==========================================================================

# m2s.csh: convert pixel dimension in meters to dx/dy in arc seconds at mean latitude
function m2s(pix_m::Real, llp)
    # 1. Get w e s n in array
    r = gmt("gmtinfo -C -bi3f", llp)
    w, e, s, n = r.data[1, 1:4]
    # 2. Get mean latitude
    mlat = (s + n) / 2
    # 3. Get nearest integer 1/2 arc second for latitude (at least 1")
    dy = max(round(pix_m / 111195.079734 * 3600 * 2), 1) / 2
    # 4. Get nearest integer 1/2 arc second for longitude at mean latitude (at least 1")
    dx = max(round(pix_m / 111195.079734 / cosd(mlat) * 3600 * 2), 1) / 2
    # Report two -Idx/dy settings: first for actual grid and 2nd for 10 times larger intervals
    inc1 = @sprintf("%gs/%gs", dx, dy)
    inc2 = @sprintf("%gs/%gs", dx * 10, dy * 10)
    return inc1, inc2
end

# proj_ra2ll.csh: project a grd file from range/azimuth coordinates into
# lon/lat coordinates. Output: phase_ll.grd - a GRD file of phase in
# longitude/latitude coordinates
function proj_ra2ll(trans::AbstractString, ingrd::AbstractString, outgrd::AbstractString; filter_wavelength::Union{Nothing,Real}=nothing, verbose::Bool=true)
    require_file(trans); require_file(ingrd)
    V = verbose ? " -V" : ""
    println("proj_ra2ll.csh")
    # extract the phase in the r a positions
    rap = gmt("grd2xyz -s -bo3f", gmt("read $ingrd"))
    # make grids of longitude and latitude versus range and azimuth unless they already exist
    if !isfile("raln.grd") || !isfile("ralt.grd")
        info = gmt("gmtinfo -I16/32 -bi3f", rap)
        w, e, s, n = info.data[1, 1:4]
        region = "$w/$e/$s/$n"
        raln = gmt("surface -i0,1,3 -bi5d -R$region -I16/32 -T.50$V", gmt("read $trans"))
        gmt("write raln.grd", raln)
        ralt = gmt("surface -i0,1,4 -bi5d -R$region -I16/32 -T.50$V", gmt("read $trans"))
        gmt("write ralt.grd", ralt)
    end
    # add lon and lat columns and then just keep lon, lat, phase
    tracked = gmt("grdtrack -nl -bi3f -bo5f -Graln.grd -Gralt.grd", rap)
    llp = gmt("gmtconvert -bi5f -bo3f -o3,4,2", tracked)

    # set the output grid spacing to be 1/4 the filter wavelength
    pix_m = if filter_wavelength !== nothing
        fw = filter_wavelength / 4
        println("Sampling in geocoordinates with $fw meter pixels ...")
        fw
    else
        gaussfiles = filter(f -> startswith(f, "gauss_"), readdir())
        if !isempty(gaussfiles)
            w = parse(Float64, split(gaussfiles[1], '_')[2]) / 4
            println("Sampling in geocoordinates with $w meter pixels ...")
            w
        else
            println("Sampling in geocoordinates with default (60 meter) pixel size ...")
            60.0
        end
    end
    inc1, inc2 = m2s(pix_m, llp)
    info2 = gmt("gmtinfo -I$inc2 -bi3f", llp)
    w, e, s, n = info2.data[1, 1:4]
    R = "$w/$e/$s/$n"
    llpb = gmt("blockmedian -R$R -bi3f -bo3f -I$inc1 -r -V", llp)
    g = gmt("xyz2grd -R$R -I$inc1 -r -fg -bi3f", llpb)
    gmt("write $outgrd", g)
    return outgrd
end

# proj_ll2ra.csh: project a grd file from lon/lat coordinates into
# range/azimuth coordinates. Output: phase_ra.grd - a GRD file of phase in
# radar coordinates. [-I32/64 - set the output sampling size, i.e.,
# range/azimuth pixel number]
function proj_ll2ra(trans::AbstractString, ingrd::AbstractString, outgrd::AbstractString; inc::AbstractString="32/64", verbose::Bool=true)
    require_file(trans); require_file(ingrd)
    V = verbose ? " -V" : ""
    # extract the phase in the r a positions
    gmt("gmtset FORMAT_GEO_OUT D")
    llp = gmt("grd2xyz -s -bo3f -fg", gmt("read $ingrd"))
    # make grids of longitude and latitude versus range and azimuth
    llr = gmt("gmtconvert -o3,4,0 -bi5d -bo3f", gmt("read $trans"))
    lla = gmt("gmtconvert -o3,4,1 -bi5d -bo3f", gmt("read $trans"))
    info = gmt("gmtinfo -I0.08333333333 -bi3f", llp)
    w, e, s, n = info.data[1, 1:4]; R = "$w/$e/$s/$n"
    llrg = gmt("surface -R$R -bi3f -I.00083333333333 -T.50$V", llr)
    llag = gmt("surface -R$R -bi3f -I.00083333333333 -T.50$V", lla)
    gmt("write llr.grd", llrg); gmt("write lla.grd", llag)
    llpr = gmt("grdtrack -nl -Gllr.grd -bi3f -bo4f", llp)
    llpra = gmt("grdtrack -nl -Glla.grd -bi4f -bo5f", llpr)
    # get the range, azimuth, phase columns and grid
    rap = gmt("gmtconvert -bi5f -bo3f -o3,4,2", llpra)
    info2 = gmt("gmtinfo -I32/64 -bi3f", rap)
    w, e, s, n = info2.data[1, 1:4]; R2 = "$w/$e/$s/$n"
    g = gmt("xyz2grd -R$R2 -I$inc -r -bi3f", rap)
    gmt("write $outgrd", g)
    # clean
    for f in ("llr.grd", "lla.grd")
        isfile(f) && rm(f)
    end
    return outgrd
end

# grd2kml.csh, D. Sandwell FEB 10 2010: script to convert a grd file to a
# kml file for Google Earth
function grd2kml(stem::AbstractString, cpt::AbstractString; region::Union{Nothing,String}=nothing, verbose::Bool=true)
    grdfile = "$stem.grd"
    require_file(grdfile); require_file(cpt)
    V = verbose ? " -V" : ""
    VS = verbose ? " -S -V" : ""
    c = grd_C(grdfile)
    DX = c[7]
    DPI = round(Int, 1 / DX)
    gmt("gmtset COLOR_MODEL = hsv")
    gmt("gmtset PS_MEDIA = A2")
    Ropt = region === nothing ? "" : " -R$region"
    run(`gmt grdimage $grdfile -C$cpt$Ropt -Jx1id -P -Y2i -X2i -Q$V \-\> $stem.ps`)
    # now make the kml and png
    println("Make $stem.kml and $stem.png")
    gmt("psconvert $stem.ps -W+k+t\"$stem\" -E$DPI -TG -P$VS -F$stem")
    isfile("$stem.ps") && rm("$stem.ps")
end

# ==========================================================================
# snaphu.csh / snaphu_interp.csh
#   [GMTSAR] - Unwrap the phase (snaphu_interp.csh additionally does nearest
#   neighbor interpolation of low coherence and blank pixels first)
#     correlation is reset to zero when < threshold
#     maximum_discontinuity enables phase jumps for earthquake ruptures,
#     etc.; set maximum_discontinuity = 0 for continuous phase such as
#     interseismic
#   Reference: Chen C. W. and H. A. Zebker, Network approaches to
#   two-dimensional phase unwrapping: intractability and two new
#   algorithms, JOSA A, vol. 17, pp. 401-414 (2000). Agram, P. S., & Zebker,
#   H. A. (2009). Sparse two-dimensional phase unwrapping using regular-grid
#   methods. IEEE GRSL, 6(2), 327-331.
# ==========================================================================

# prepare the files adding the correlation mask
function _snaphu_prep(threshold::Real, region::Union{Nothing,String})
    if region !== nothing
        gmt("grdcut mask.grd -R$region -Gmask_patch.grd")
        gmt("grdcut corr.grd -R$region -Gcorr_patch.grd")
        gmt("grdcut phasefilt.grd -R$region -Gphase_patch.grd")
    else
        for (a, b) in (("mask.grd", "mask_patch.grd"), ("corr.grd", "corr_patch.grd"), ("phasefilt.grd", "phase_patch.grd"))
            isfile(b) && rm(b)
            cp(a, b)
        end
    end
    # create landmask
    if isfile("landmask_ra.grd")
        Ipos = grd_I("phase_patch.grd")
        Ropt = region === nothing ? "-Rphase_patch.grd" : "-R$region"
        r = gmt("grdsample landmask_ra.grd $Ropt -I$Ipos")
        gmt("write landmask_ra_patch.grd", r)
        p = gmt("grdmath phase_patch.grd landmask_ra_patch.grd MUL =")
        gmt("write phase_patch.grd", p)
    end
    # user defined mask
    if isfile("mask_def.grd")
        if region !== nothing
            gmt("grdcut mask_def.grd -R$region -Gmask_def_patch.grd")
        else
            cp("mask_def.grd", "mask_def_patch.grd"; force=true)
        end
        c = gmt("grdmath corr_patch.grd mask_def_patch.grd MUL =")
        gmt("write corr_patch.grd", c)
    end
    m2 = gmt("grdmath corr_patch.grd $threshold GE 0 NAN mask_patch.grd MUL =")
    gmt("write mask2_patch.grd", m2)
    c2 = gmt("grdmath corr_patch.grd 0. XOR 1. MIN =")
    gmt("write corr_patch.grd", c2)
    ct = gmt("grdmath mask2_patch.grd corr_patch.grd MUL =")
    gmt("write corr_tmp.grd", ct)
end

# run snaphu
function _snaphu_run_and_finish(threshold_snaphu::Real, defomax::Real, region::Union{Nothing,String}; verbose::Bool=true)
    V = verbose ? " -V" : ""
    sharedir = "share/gmtsar"
    linelen = round(Int, grd_C("phase_patch.grd")[9])  # ncols
    if defomax == 0
        gmt("snaphu -Dphase.in -R$linelen -fshare/gmtsar/snaphu/config/snaphu.conf.brief -ccorr.in -ounwrap.out -v -s -gconncomp.out")
    else
        conf = read(joinpath(sharedir, "snaphu", "config", "snaphu.conf.brief"), String)
        conf = replace(conf, r".*DEFOMAX_CYCLE.*" => "DEFOMAX_CYCLE  $defomax")
        write("snaphu.conf.brief", conf)
        gmt("snaphu -Dphase.in -R$linelen -fsnaphu.conf.brief -ccorr.in -ounwrap.out -v -d -gconncomp.out")
    end

    # convert to grd
    Ineg = grd_I("phase_patch.grd") # dx/dy of phase_patch.grd
    R = grd_R("phase_patch.grd")
    uw = gmt("xyz2grd unwrap.out -ZTLf -r -R$R -I$Ineg")
    gmt("write tmp.grd", uw)
    # generate connected component
    cc = gmt("xyz2grd conncomp.out -ZTLu -r -R$R -I$Ineg")
    gmt("write conncomp.grd", cc)
    m = gmt("grdmath tmp.grd mask2_patch.grd MUL =")
    gmt("write tmp.grd", m)
    # detrend the unwrapped if DEFOMAX = 0 for interseismic -- left disabled,
    # matching the commented-out `gmt grdtrend` branch in the original .csh
    mv("tmp.grd", "unwrap.grd"; force=true)

    # landmask
    if isfile("landmask_ra.grd")
        m = gmt("grdmath unwrap.grd landmask_ra_patch.grd MUL =$V")
        gmt("write unwrap.grd", m)
    end
    # user defined mask
    if isfile("mask_def.grd")
        m = gmt("grdmath unwrap.grd mask_def_patch.grd MUL =$V")
        gmt("write unwrap.grd", m)
    end

    # plot the unwrapped phase
    grad = gmt("grdgradient unwrap.grd -Nt.9 -A0.")
    gmt("write unwrap_grad.grd", grad)
    st = gmt("grdinfo -C -L2 unwrap.grd")
    mean, sd = st.data[1, 12], st.data[1, 13]
    limitU, limitL = round(mean + 2sd, digits=1), round(mean - 2sd, digits=1)
    gmt("makecpt -Cseis -I -Z -T$limitL/$limitU/1 -D > unwrap.cpt")
    gmt("grdimage unwrap.grd -Iunwrap_grad.grd -Cunwrap.cpt -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K > unwrap.ps")
    gmt("psscale -Runwrap.grd -J -DJTC+w5/0.2+h+e -Cunwrap.cpt -Bxaf+l\"Unwrapped phase\" -By+lrad -O >> unwrap.ps")
    gmt("psconvert -Tf -P -A -Z unwrap.ps")
    println("Unwrapped phase map: unwrap.pdf")

    # clean up
    for f in ("tmp.grd", "corr_tmp.grd", "unwrap.out", "tmp2.grd", "unwrap_grad.grd", "conncomp.out", "phase.in", "corr.in", "mask_patch.grd", "mask3.grd", "mask3.out")
        isfile(f) && rm(f)
    end
    # cleanup more
    if region !== nothing
        isfile("corr_patch.grd") && mv("corr_patch.grd", "corr_cut.grd"; force=true)
    end
    isfile("corr_cut.grd") && rm("corr_cut.grd")
    isfile("corr_patch.grd") && rm("corr_patch.grd")
end

function snaphu_unwrap(threshold_snaphu::Real, defomax::Real; region::Union{Nothing,String}=nothing)
    require_file("mask.grd"); require_file("corr.grd"); require_file("phasefilt.grd")
    _snaphu_prep(threshold_snaphu, region)
    pin = gmt("grd2xyz -ZTLf -do0", gmt("read phase_patch.grd"))
    gmt("write phase.in", pin)
    cin = gmt("grd2xyz -ZTLf -do0", gmt("read corr_tmp.grd"))
    gmt("write corr.in", cin)
    println("unwrapping phase with snaphu - higher threshold for faster unwrapping ")
    _snaphu_run_and_finish(threshold_snaphu, defomax, region)
    return "unwrap.grd"
end

function snaphu_interp_unwrap(threshold_snaphu::Real, defomax::Real; region::Union{Nothing,String}=nothing)
    require_file("mask.grd"); require_file("corr.grd"); require_file("phasefilt.grd")
    _snaphu_prep(threshold_snaphu, region)
    # interpolate, in case there is a big vacant area, do not go too far
    pt = gmt("grdmath mask2_patch.grd phase_patch.grd MUL =")
    gmt("write phase_tmp.grd", pt)
    gmt("nearest_grid phase_tmp.grd -Gtmp.grd -S300")
    mv("tmp.grd", "phase_tmp.grd"; force=true)
    pin = gmt("grd2xyz -ZTLf -do0", gmt("read phase_tmp.grd"))
    gmt("write phase.in", pin)
    cin = gmt("grd2xyz -ZTLf -do0", gmt("read corr_tmp.grd"))
    gmt("write corr.in", cin)
    println("unwrapping phase with snaphu - higher threshold for faster unwrapping ")
    _snaphu_run_and_finish(threshold_snaphu, defomax, region)
    isfile("phase_tmp.grd") && rm("phase_tmp.grd")
    mv("phase_patch.grd", "phasefilt_interp.grd"; force=true)
    return "unwrap.grd"
end

# ==========================================================================
# geocode.csh -> geocode(threshold)
#   D. Sandwell FEB 10 2010
#   Kurt Feigl 20150811 add annotation to grd files
#   phase is masked when correlation is less than correlation_threshold
# ==========================================================================
function geocode(threshold::Real; verbose::Bool=true)
    require_file("corr.grd"); require_file("mask.grd"); require_file("phasefilt.grd"); require_file("trans.dat")
    V = verbose ? " -V" : ""
    # first mask the phase and phase gradient using the correlation
    m2 = gmt("grdmath corr.grd $threshold GE 0 NAN mask.grd MUL =$V")
    gmt("write mask2.grd", m2)
    pm = gmt("grdmath phasefilt.grd mask2.grd MUL =")
    gmt("write phase_mask.grd", pm)
    if isfile("xphase.grd")
        xm = gmt("grdmath xphase.grd mask2.grd MUL ="); gmt("write xphase_mask.grd", xm)
        ym = gmt("grdmath yphase.grd mask2.grd MUL ="); gmt("write yphase_mask.grd", ym)
    end
    if isfile("unwrap.grd")
        Rneg = grd_R("unwrap.grd"); Ipos = grd_I("unwrap.grd")
        m3 = gmt("grdsample mask2.grd -R$Rneg -I$Ipos")
        gmt("write mask3.grd", m3)
        um = gmt("grdmath unwrap.grd mask3.grd MUL ="); gmt("write unwrap_mask.grd", um)
    end
    if isfile("phasefilt.grd")
        pfm = gmt("grdmath phasefilt.grd mask2.grd MUL ="); gmt("write phasefilt_mask.grd", pfm)
    end

    # look at the masked phase
    gmt("grdimage phase_mask.grd -JX6.5i -Cphase.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K > phase_mask.ps")
    gmt("psscale -Rphase_mask.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l\"Phase\" -By+lrad -O >> phase_mask.ps")
    gmt("psconvert -Tf -P -A -Z phase_mask.ps")
    println("Masked phase map: phase_mask.pdf")

    if isfile("xphase_mask.grd")
        gmt("makecpt -Cgray -T-.3/.3/.1 -Z -M --COLOR_NAN=red > xphase.cpt")
        gmt("grdimage xphase_mask.grd -JX8i -Cxphase.cpt -Bxaf+lrange -Byaf+lazimuth -BWSen -X1.3i -Y3i -Q -P -K > xphase_mask.ps")
        gmt("psscale -Rxphase_mask.grd -J -DJTC+w5i/0.2i+h -Cxphase.cpt -Bxa0.1+l\"x-phase\" -By+lrad -O >> xphase_mask.ps")
        gmt("psconvert -Tf -P -A -Z xphase_mask.ps")
        gmt("makecpt -Cgray -T-.6/.6/.1 -Z -M --COLOR_NAN=red > yphase.cpt")
        gmt("grdimage yphase_mask.grd -JX8i -Cyphase.cpt -Bxaf+lrange -Byaf+lazimuth -BWSen -X1.3i -Y3i -Q -P -K > yphase_mask.ps")
        gmt("psscale -Ryphase_mask.grd -J -DJTC+w5i/0.2i+h -Cyphase.cpt -Bxa0.1+l\"y-phase\" -By+lrad -O >> yphase_mask.ps")
        gmt("psconvert -Tf -P -A -Z yphase_mask.ps")
    end
    if isfile("unwrap_mask.grd")
        gmt("grdimage unwrap_mask.grd -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cunwrap.cpt -X1.3i -Y3i -P -K > unwrap_mask.ps")
        gmt("psscale -Runwrap_mask.grd -J -DJTC+w5i/0.2i+h+e -Cunwrap.cpt -Bxaf+l\"Unwrapped phase\" -By+lrad -O >> unwrap_mask.ps")
        gmt("psconvert -Tf -P -A -Z unwrap_mask.ps")
    end
    if isfile("phasefilt_mask.grd")
        gmt("grdimage phasefilt_mask.grd -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K > phasefilt_mask.ps")
        gmt("psscale -Rphasefilt_mask.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l\"Phase\" -By+lrad -O >> phasefilt_mask.ps")
        gmt("psconvert -Tf -P -A -Z phasefilt_mask.ps")
    end

    # line-of-sight displacement
    # constant is negative to make LOS = -1 * range change
    # constant is (1000 mm) / (4 * pi)
    wavel = 0.0
    if isfile("unwrap_mask.grd")
        for f in readdir()
            if endswith(f, ".PRM")
                wavel = prm_get(f, "wavelength")
                wavel = parse(Float64, wavel)
                break
            end
        end
        los = gmt("grdmath unwrap_mask.grd $wavel MUL -79.58 MUL =")
        gmt("write los.grd", los)
        lg = gmt("grdgradient -Nt.9 -A0.", gmt("read los.grd"))
        gmt("write los_grad.grd", lg)
        st = gmt("grdinfo -C -L2 los.grd")
        mean, sd = st.data[1, 12], st.data[1, 13]
        limitU, limitL = round(mean + 2sd, digits=1), round(mean - 2sd, digits=1)
        gmt("makecpt -Cpolar -Z -T$limitL/$limitU/1 -D > los.cpt")
        gmt("grdimage los.grd -Ilos_grad.grd -Clos.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -JX6.5i -X1.3i -Y3i -P -K > los.ps")
        gmt("psscale -Rlos.grd -J -DJTC+w5i/0.2i+h+e -Clos.cpt -Bxaf+l\"LOS displacement\" -By+lmm -O >> los.ps")
        gmt("psconvert -Tf -P -A -Z los.ps")
    end

    # now reproject the phase to lon/lat space
    println("geocode.csh\nproject correlation, phase, unwrapped and amplitude back to lon lat coordinates")
    proj_ra2ll("trans.dat", "corr.grd", "corr_ll.grd")
    proj_ra2ll("trans.dat", "phasefilt.grd", "phasefilt_ll.grd")
    proj_ra2ll("trans.dat", "phase_mask.grd", "phase_mask_ll.grd")
    proj_ra2ll("trans.dat", "display_amp.grd", "display_amp_ll.grd")
    isfile("xphase_mask.grd") && proj_ra2ll("trans.dat", "xphase_mask.grd", "xphase_mask_ll.grd")
    isfile("yphase_mask.grd") && proj_ra2ll("trans.dat", "yphase_mask.grd", "yphase_mask_ll.grd")
    isfile("unwrap_mask.grd") && proj_ra2ll("trans.dat", "unwrap_mask.grd", "unwrap_mask_ll.grd")
    isfile("unwrap.grd") && proj_ra2ll("trans.dat", "unwrap.grd", "unwrap_ll.grd")
    isfile("phasefilt_mask.grd") && proj_ra2ll("trans.dat", "phasefilt_mask.grd", "phasefilt_mask_ll.grd")

    # now image for google earth
    println("geocode.csh\nmake the KML files for Google Earth")
    grd2kml("display_amp_ll", "display_amp.cpt")
    grd2kml("corr_ll", "corr.cpt")
    grd2kml("phase_mask_ll", "phase.cpt")
    grd2kml("phasefilt_mask_ll", "phase.cpt")
    isfile("xphase_mask_ll.grd") && grd2kml("xphase_mask_ll", "xphase.cpt")
    isfile("yphase_mask_ll.grd") && grd2kml("yphase_mask_ll", "yphase.cpt")
    isfile("unwrap_mask_ll.grd") && grd2kml("unwrap_mask_ll", "unwrap.cpt")
    if isfile("unwrap_mask_ll.grd")
        losll = gmt("grdmath unwrap_mask_ll.grd $wavel MUL -79.58 MUL =")
        gmt("write los_ll.grd", losll)
        grd2kml("los_ll", "los.cpt")
    end
end

# ==========================================================================
# p2p_S1_TOPS.csh -> the main driver
#   David Sandwell, December 29, 2015
#
#   process Sentinel-1A TOPS data
#   Automatically process a single frame of interferogram.
#   see instruction.txt for details.
#
#   Place the pre-processed data in a directory called raw and a dem.grd
#   file in a parallel directory called topo. Execute this command at the
#   directory location above raw and topo. The file dem.grd is a dem that
#   completely covers the SAR frame - larger is OK. If the dem is omitted
#   then an interferogram will still be created but there will not be
#   geocoded output. A custom dem.grd can be made at the web site
#   http://topex.ucsd.edu/gmtsar
#
#   Reference: Xu, X., Sandwell, D.T., Tymofyeyeva, E., Gonzalez-Ortega, A.
#   and Tong, X., 2017. Tectonic and Anthropogenic Deformation at the Cerro
#   Prieto Geothermal Step-Over Revealed by Sentinel-1A InSAR. IEEE
#   Transactions on Geoscience and Remote Sensing.
# ==========================================================================
function p2p_S1_TOPS(master::AbstractString, aligned::AbstractString, config_file::AbstractString)
    # make sure the files exist
    for f in (joinpath("raw", "$master.PRM"), joinpath("raw", "$master.LED"), joinpath("raw", "$master.SLC"))
        isfile(f) || error("missing input files  raw/$master")
    end
    for f in (joinpath("raw", "$aligned.PRM"), joinpath("raw", "$aligned.LED"), joinpath("raw", "$aligned.SLC"))
        isfile(f) || error("missing input files  raw/$aligned")
    end
    isfile(config_file) || error("no configure file: $config_file")

    # read parameters from configuration file
    stage = cfg_int(config_file, "proc_stage", 1)
    earth_radius = cfg_float(config_file, "earth_radius", 0.0)
    topo_phase = cfg_int(config_file, "topo_phase", 0)
    shift_topo = cfg_int(config_file, "shift_topo", 0)
    switch_master = cfg_int(config_file, "switch_master", 0)
    # if filter wavelength is not set then use a default of 200m
    filter_m = cfg_float(config_file, "filter_wavelength", 200.0)
    dec = cfg_int(config_file, "dec_factor", 1)
    threshold_snaphu = cfg_float(config_file, "threshold_snaphu", 0.0)
    threshold_geocode = cfg_float(config_file, "threshold_geocode", 0.0)
    region_cut = cfg_str(config_file, "region_cut")
    switch_land = cfg_int(config_file, "switch_land", 0)
    defomax = cfg_float(config_file, "defomax", 0.0)
    range_dec_s = cfg_str(config_file, "range_dec")
    azimuth_dec_s = cfg_str(config_file, "azimuth_dec")
    range_dec = isempty(range_dec_s) ? nothing : parse(Int, range_dec_s)
    azimuth_dec = isempty(azimuth_dec_s) ? nothing : parse(Int, azimuth_dec_s)
    near_interp = cfg_int(config_file, "near_interp", 0)
    mask_water = cfg_int(config_file, "mask_water", 0)

    # read file names of raw data
    ref, rep = switch_master == 0 ? (master, aligned) : (aligned, master)
    switch_master in (0, 1) || println("Wrong paramter: switch_master $switch_master")

    # make working directories
    mkpath("intf"); mkpath("SLC")

    #############################
    # 1 - start from preprocess #
    #############################
    if stage == 1
        # preprocess the raw data
        println("\nPREPROCESS - START")
        cd("raw") do
            # preprocess the raw data make the raw data and copy the PRM to
            # PRM00 in case the script is run a second time
            if isfile("$master.PRM00")
                cp("$master.PRM00", "$master.PRM"; force=true)
                cp("$aligned.PRM00", "$aligned.PRM"; force=true)
            else
                cp("$master.PRM", "$master.PRM00"; force=true)
                cp("$aligned.PRM", "$aligned.PRM00"; force=true)
            end
            # set the num_lines to be the min of the master and aligned
            m_lines = prm_int("$master.PRM", "num_lines")
            s_lines = prm_int("$aligned.PRM", "num_lines")
            if s_lines < m_lines
                for k in ("num_lines", "num_valid_az", "nrows")
                    update_prm!("$master.PRM", k, s_lines)
                end
            else
                for k in ("num_lines", "num_valid_az", "nrows")
                    update_prm!("$aligned.PRM", k, m_lines)
                end
            end
            # set the higher Doppler terms to zero to be zero
            update_prm!("$master.PRM", "fdd1", 0); update_prm!("$master.PRM", "fddd1", 0)
            update_prm!("$aligned.PRM", "fdd1", 0); update_prm!("$aligned.PRM", "fddd1", 0)
            for f in readdir()
                (endswith(f, ".log") || endswith(f, ".PRM0")) && rm(f)
            end
        end
        println("PREPROCESS.CSH - END")
    end

    #############################################
    # 2 - start from focus and align SLC images #
    #############################################
    if stage <= 2
        # clean up
        isdir("SLC") && (rm.(readdir("SLC"; join=true)))
        # align SLC images
        println("\nALIGN - START")
        cd("SLC") do
            for f in readdir(joinpath("..", "raw"))
                endswith(f, ".PRM") && cp(joinpath("..", "raw", f), f; force=true)
            end
            # `ln -s` -> `cp` (portable across Windows without symlink privilege)
            for ext in ("SLC", "LED")
                cp(joinpath("..", "raw", "$master.$ext"), "$master.$ext"; force=true)
                cp(joinpath("..", "raw", "$aligned.$ext"), "$aligned.$ext"; force=true)
            end
        end
        println("ALIGN - END")
    end

    ##################################
    # 3 - start from make topo_ra    #
    ##################################
    if stage <= 3
        mkpath("topo")
        # clean up (cleanup.csh topo: remove everything in topo/ except dem.grd)
        for f in readdir("topo")
            f != "dem.grd" && rm(joinpath("topo", f); force=true, recursive=true)
        end
        # make topo_ra if there is dem.grd
        if topo_phase == 1
            println("\nDEM2TOPO_RA.CSH - START\nUSER SHOULD PROVIDE DEM FILE")
            cd("topo") do
                cp(joinpath("..", "SLC", "$master.PRM"), "master.PRM"; force=true)
                cp(joinpath("..", "raw", "$master.LED"), "$master.LED"; force=true)
                isfile("dem.grd") || error("no DEM file found: dem.grd")
                dem2topo_ra("master.PRM", "dem.grd")
            end
            println("DEM2TOPO_RA.CSH - END")
            # shift topo_ra
            if shift_topo == 1
                println("\nOFFSET_TOPO - START")
                # make sure the range increment of the amplitude image matches the topo_ra.grd
                rng = grd_I("topo/topo_ra.grd")
                cd("SLC") do
                    println(" range decimation is:  $rng")
                    slc2amp("$master.PRM", round(Int, parse(Float64, split(rng, '/')[1])), "amp-$master.grd")
                end
                cd("topo") do
                    cp(joinpath("..", "SLC", "amp-$master.grd"), "amp-$master.grd"; force=true)
                    gmt("offset_topo -Aamp-$master.grd -Btopo_ra.grd -X0 -Y0 -S7 -Gtopo_shift.grd")
                end
                println("OFFSET_TOPO - END")
            elseif shift_topo == 0
                println("NO TOPO_RA SHIFT ")
            else
                println("Wrong paramter: shift_topo $shift_topo")
            end
        else
            println("NO TOPO_RA IS SUBSTRACTED")
        end
    end

    ##################################################
    # 4 - start from make and filter interferograms  #
    ##################################################
    if stage <= 4
        # clean up (cleanup.csh intf)
        for f in readdir("intf")
            rm(joinpath("intf", f); force=true, recursive=true)
        end
        # make and filter interferograms
        println("\nINTF.CSH, FILTER.CSH - START")
        cd("intf") do
            ref_id = prm_int(joinpath("..", "raw", "$master.PRM"), "SC_clock_start")
            rep_id = prm_int(joinpath("..", "raw", "$aligned.PRM"), "SC_clock_start")
            pairdir = "$(ref_id)_$(rep_id)"
            mkpath(pairdir)
            cd(pairdir) do
                for ext in ("LED",)
                    cp(joinpath("..", "..", "raw", "$ref.$ext"), "$ref.$ext"; force=true)
                    cp(joinpath("..", "..", "raw", "$rep.$ext"), "$rep.$ext"; force=true)
                end
                for ext in ("SLC",)
                    cp(joinpath("..", "..", "SLC", "$ref.$ext"), "$ref.$ext"; force=true)
                    cp(joinpath("..", "..", "SLC", "$rep.$ext"), "$rep.$ext"; force=true)
                end
                cp(joinpath("..", "..", "SLC", "$ref.PRM"), "$ref.PRM"; force=true)
                cp(joinpath("..", "..", "SLC", "$rep.PRM"), "$rep.PRM"; force=true)

                if topo_phase == 1
                    topo_file = shift_topo == 1 ? joinpath("..", "..", "topo", "topo_shift.grd") : joinpath("..", "..", "topo", "topo_ra.grd")
                    cp(topo_file, basename(topo_file); force=true)
                    intf("$ref.PRM", "$rep.PRM"; topo=basename(topo_file))
                else
                    intf("$ref.PRM", "$rep.PRM")
                end
                filter_step("$ref.PRM", "$rep.PRM", filter_m, dec; range_dec=range_dec, azimuth_dec=azimuth_dec)
            end
        end
        println("INTF.CSH, FILTER.CSH - END")
    end

    ################################
    # 5 - start from unwrap phase  #
    ################################
    if stage <= 5
        if threshold_snaphu != 0
            cd("intf") do
                ref_id = prm_int(joinpath("..", "SLC", "$master.PRM"), "SC_clock_start")
                rep_id = prm_int(joinpath("..", "SLC", "$aligned.PRM"), "SC_clock_start")
                cd("$(ref_id)_$(rep_id)") do
                    rc = isempty(region_cut) ? grd_R("phase.grd") : region_cut
                    # landmask
                    if mask_water == 1 || switch_land == 1
                        cd(joinpath("..", "..", "topo")) do
                            isfile("landmask_ra.grd") || landmask(rc)
                        end
                        cp(joinpath("..", "..", "topo", "landmask_ra.grd"), "landmask_ra.grd"; force=true)
                    end
                    println("\nSNAPHU.CSH - START\nthreshold_snaphu: $threshold_snaphu")
                    if near_interp == 1
                        snaphu_interp_unwrap(threshold_snaphu, defomax; region=rc)
                    else
                        snaphu_unwrap(threshold_snaphu, defomax; region=rc)
                    end
                    println("SNAPHU.CSH - END")
                end
            end
        else
            println("\nSKIP UNWRAP PHASE")
        end
    end

    ###########################
    # 6 - start from geocode  #
    ###########################
    if stage <= 6
        if threshold_geocode != 0
            cd("intf") do
                ref_id = prm_int(joinpath("..", "SLC", "$master.PRM"), "SC_clock_start")
                rep_id = prm_int(joinpath("..", "SLC", "$aligned.PRM"), "SC_clock_start")
                cd("$(ref_id)_$(rep_id)") do
                    println("\nGEOCODE.CSH - START")
                    for f in ("raln.grd", "ralt.grd"); isfile(f) && rm(f); end
                    if topo_phase == 1
                        isfile("trans.dat") || cp(joinpath("..", "..", "topo", "trans.dat"), "trans.dat"; force=true)
                        println("threshold_geocode: $threshold_geocode")
                        geocode(threshold_geocode)
                    else
                        error("topo_ra is needed to geocode")
                    end
                    println("GEOCODE.CSH - END")
                end
            end
        else
            println("\nSKIP GEOCODE\n")
        end
    end
end

# ------------------------------------------------------------------------
# CLI entry point: julia p2p_S1_TOPS.jl master_image aligned_image config
# ------------------------------------------------------------------------
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 3
        println("Usage: julia p2p_S1_TOPS.jl master_image aligned_image configuration_file")
        exit(1)
    end
    p2p_S1_TOPS(ARGS[1], ARGS[2], ARGS[3])
end
