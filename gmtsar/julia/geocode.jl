#!/usr/bin/env julia
#       $Id$
#
#  D. Sandwell FEB 10 2010
#  Kurt Feigl 20150811 add annotation to grd files
#
# alias rm 'rm -f'
# unset noclobber
#
using Printf

"""grep PATTERN *.SUFFIX | awk '{print(\$3)}' | head -1  -- first matching line (sorted glob), 3rd field"""
function grep_field_glob(pattern::AbstractString, suffix::AbstractString)
    files = sort(filter(f -> endswith(f, suffix), readdir(".")))
    for f in files
        for line in eachline(f)
            if occursin(pattern, line)
                return split(line)[3]
            end
        end
    end
    error("pattern not found: $pattern in *$suffix")
end

function main(argv::Vector{String})
    if length(argv) < 1
        # errormessage:
        println("")
        println("Usage: geocode.csh correlation_threshold")
        println("")
        println(" phase is masked when correlation is less than correlation_threshold")
        println("")
        println("Example: geocode.csh .12")
        println("")
        exit(1)
    end
    #
    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end

    #   first mask the phase and phase gradient using the correlation
    #
    run(`gmt grdmath corr.grd $(argv[1]) GE 0 NAN mask.grd MUL = mask2.grd $V`)
    run(`gmt grdmath phasefilt.grd mask2.grd MUL = phase_mask.grd`)
    if isfile("xphase.grd")
        run(`gmt grdmath xphase.grd mask2.grd MUL = xphase_mask.grd`)
        run(`gmt grdmath yphase.grd mask2.grd MUL = yphase_mask.grd`)
    end
    if isfile("unwrap.grd")
        r1 = strip(read(`gmt grdinfo unwrap.grd -I-`, String))
        r2 = strip(read(`gmt grdinfo unwrap.grd -I`, String))
        run(`gmt grdsample mask2.grd $r1 $r2 -Gmask3.grd`)
        run(`gmt grdmath unwrap.grd mask3.grd MUL = unwrap_mask.grd`)
    end
    if isfile("phasefilt.grd")
        run(`gmt grdmath phasefilt.grd mask2.grd MUL = phasefilt_mask.grd`)
    end
    #
    #   look at the masked phase
    #
    run(pipeline(`gmt grdimage phase_mask.grd -JX6.5i -Cphase.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -X1.3i -Y3i -P -K`, stdout="phase_mask.ps"))
    open("phase_mask.ps", "a") do io
        run(pipeline(`gmt psscale -Rphase_mask.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l"Phase" -By+lrad -O`, stdout=io))
    end
    run(`gmt psconvert -Tf -P -A -Z phase_mask.ps`)
    println("Masked phase map: phase_mask.pdf")
    if isfile("xphase_mask.grd")
        run(pipeline(`gmt makecpt -Cgray -T-.3/.3/.1 -Z -M --COLOR_NAN=red`, stdout="xphase.cpt"))
        run(pipeline(`gmt grdimage xphase_mask.grd -JX8i -Cxphase.cpt -Bxaf+lrange -Byaf+lazimuth -BWSen -X1.3i -Y3i -Q -P -K`, stdout="xphase_mask.ps"))
        open("xphase_mask.ps", "a") do io
            run(pipeline(`gmt psscale -Rxphase_mask.grd -J -DJTC+w5i/0.2i+h -Cxphase.cpt -Bxa0.1+l"x-phase" -By+lrad -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z xphase_mask.ps`)
        println("Masked x phase map: xphase_mask.pdf")
        run(pipeline(`gmt makecpt -Cgray -T-.6/.6/.1 -Z -M --COLOR_NAN=red`, stdout="yphase.cpt"))
        run(pipeline(`gmt grdimage yphase_mask.grd -JX8i -Cyphase.cpt -Bxaf+lrange -Byaf+lazimuth -BWSen -X1.3i -Y3i -Q -P -K`, stdout="yphase_mask.ps"))
        open("yphase_mask.ps", "a") do io
            run(pipeline(`gmt psscale -Ryphase_mask.grd -J -DJTC+w5i/0.2i+h -Cyphase.cpt -Bxa0.1+l"y-phase" -By+lrad -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z yphase_mask.ps`)
        println("Masked y phase map: yphase_mask.pdf")
    end
    if isfile("unwrap_mask.grd")
        run(pipeline(`gmt grdimage unwrap_mask.grd -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cunwrap.cpt -X1.3i -Y3i -P -K`, stdout="unwrap_mask.ps"))
        open("unwrap_mask.ps", "a") do io
            run(pipeline(`gmt psscale -Runwrap_mask.grd -J -DJTC+w5i/0.2i+h+e -Cunwrap.cpt -Bxaf+l"Unwrapped phase" -By+lrad -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z unwrap_mask.ps`)
        println("Unwrapped masked phase map: unwrap_mask.pdf")
    end
    if isfile("phasefilt_mask.grd")
        run(pipeline(`gmt grdimage phasefilt_mask.grd -JX6.5i -Bxaf+lRange -Byaf+lAzimuth -BWSen -Cphase.cpt -X1.3i -Y3i -P -K`, stdout="phasefilt_mask.ps"))
        open("phasefilt_mask.ps", "a") do io
            run(pipeline(`gmt psscale -Rphasefilt_mask.grd -J -DJTC+w5i/0.2i+h -Cphase.cpt -Bxa1.57+l"Phase" -By+lrad -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z phasefilt_mask.ps`)
        println("Filtered masked phase map: phasefilt_mask.pdf")
    end
    # line-of-sight displacement
    if isfile("unwrap_mask.grd")
        wavel = grep_field_glob("wavelength", ".PRM")
        run(`gmt grdmath unwrap_mask.grd $wavel MUL -79.58 MUL = los.grd`)
        run(`gmt grdgradient los.grd -Nt.9 -A0. -Glos_grad.grd`)
        tmp_fields = split(strip(read(`gmt grdinfo -C -L2 los.grd`, String)))
        limitU = @sprintf("%5.1f", parse(Float64, tmp_fields[12]) + parse(Float64, tmp_fields[13]) * 2)
        limitL = @sprintf("%5.1f", parse(Float64, tmp_fields[12]) - parse(Float64, tmp_fields[13]) * 2)
        run(pipeline(`gmt makecpt -Cpolar -Z -T$limitL/$limitU/1 -D`, stdout="los.cpt"))
        run(pipeline(`gmt grdimage los.grd -Ilos_grad.grd -Clos.cpt -Bxaf+lRange -Byaf+lAzimuth -BWSen -JX6.5i -X1.3i -Y3i -P -K`, stdout="los.ps"))
        open("los.ps", "a") do io
            run(pipeline(`gmt psscale -Rlos.grd -J -DJTC+w5i/0.2i+h+e -Clos.cpt -Bxaf+l"LOS displacement [range decrease @~\256@~]" -By+lmm -O`, stdout=io))
        end
        run(`gmt psconvert -Tf -P -A -Z los.ps`)
        println("Line-of-sight map: los.pdf")
    end

    #
    #  now reproject the phase to lon/lat space
    #
    println("geocode.csh")
    println("project correlation, phase, unwrapped and amplitude back to lon lat coordinates")
    maker = basename(PROGRAM_FILE)
    today_words = split(strip(read(`date`, String)))
    remarked = join(vcat(["by", get(ENV, "USER", ""), "on"], today_words, ["with", maker]), " ")
    println("remarked is $remarked")

    pwdt = basename(pwd())

    run(`proj_ra2ll.csh trans.dat corr.grd corr_ll.grd`)
    darg = "-D//dimensionless/1///$pwdt geocoded correlation/$remarked"
    run(`gmt grdedit $darg corr_ll.grd`)
    #proj_ra2ll.csh trans.dat phase.grd       phase_ll.grd          ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase"/"$remarked"                   phase_ll.grd
    run(`proj_ra2ll.csh trans.dat phasefilt.grd phasefilt_ll.grd`)
    darg = "-D//radians/1///$pwdt wrapped phase after filtering/$remarked"
    run(`gmt grdedit $darg phasefilt_ll.grd`)
    run(`proj_ra2ll.csh trans.dat phase_mask.grd phase_mask_ll.grd`)
    darg = "-D//radians/1///$pwdt wrapped phase after masking/$remarked"
    run(`gmt grdedit $darg phase_mask_ll.grd`)
    run(`proj_ra2ll.csh trans.dat display_amp.grd display_amp_ll.grd`)
    darg = "-D//dimensionless/1///PWD:t amplitude/$remarked"
    run(`gmt grdedit $darg display_amp_ll.grd`)
    if isfile("xphase_mask.grd")
        run(`proj_ra2ll.csh trans.dat xphase_mask.grd xphase_mask_ll.grd`)
        darg = "-D//radians/1///$pwdt xphase/$remarked"
        run(`gmt grdedit $darg xphase_mask_ll.grd`)
        run(`proj_ra2ll.csh trans.dat yphase_mask.grd yphase_mask_ll.grd`)
        darg = "-D//radians/1///$pwdt yphase/$remarked"
        run(`gmt grdedit $darg yphase_mask_ll.grd`)
    end
    if isfile("unwrap_mask.grd")
        run(`proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd`)
        darg = "-D//radians/1///PWD:t unwrapped, masked phase/$remarked"
        run(`gmt grdedit $darg unwrap_mask_ll.grd`)
    end
    if isfile("unwrap.grd")
        run(`proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd`)
        darg = "-D//radians/1///PWD:t unwrapped phase/$remarked"
        run(`gmt grdedit $darg unwrap_ll.grd`)
    end
    if isfile("phasefilt_mask.grd")
        run(`proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd`)
        darg = "-D//phase in radians/1///PWD:t wrapped phase masked filtered/$remarked"
        run(`gmt grdedit $darg phasefilt_mask_ll.grd`)
    end
    #
    #   now image for google earth
    #
    println("geocode.csh")
    println("make the KML files for Google Earth")
    run(`grd2kml.csh display_amp_ll display_amp.cpt`)
    run(`grd2kml.csh corr_ll corr.cpt`)
    run(`grd2kml.csh phase_mask_ll phase.cpt`)
    run(`grd2kml.csh phasefilt_mask_ll phase.cpt`)
    if isfile("xphase_mask_ll.grd")
        run(`grd2kml.csh xphase_mask_ll xphase.cpt`)
        run(`grd2kml.csh yphase_mask_ll yphase.cpt`)
    end
    if isfile("unwrap_mask_ll.grd")
        run(`grd2kml.csh unwrap_mask_ll unwrap.cpt`)
    end
    if isfile("phasefilt_mask_ll.grd")
        run(`grd2kml.csh phasefilt_mask_ll phase.cpt`)
    end
    if isfile("unwrap_mask_ll.grd")
        # constant is negative to make LOS = -1 * range change
        # constant is (1000 mm) / (4 * pi)
        run(`gmt grdmath unwrap_mask_ll.grd $wavel MUL -79.58 MUL = los_ll.grd`)
        darg = "-D//mm/1///$pwdt LOS displacement/equals negative range"
        run(`gmt grdedit $darg los_ll.grd`)
        run(`grd2kml.csh los_ll los.cpt`)
    end
end

main(ARGS)
