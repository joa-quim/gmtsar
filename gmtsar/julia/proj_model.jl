#!/usr/bin/env julia
#       $Id$

# Creator: Xiaopeng Tong, David Sandwell
# Date:    July 6th 2013

# alias rm 'rm -f'

function main(argv::Vector{String})
    if length(argv) != 7
        println("")
        println("Usage: proj_model.csh SAT ve.grd vn.grd vu.grd master.PRM dem.grd los.grd")
        println("")
        println("  project a simulated crust motion model into radar look directions ")
        println("  the radar look direction is spatial variable")
        println("")
        println("  SAT             --  can be ALOS or ERS or ENVI or generic SAT")
        println("  ve, vn, vu.grd  --  input: east, north, vertical motion simulated from numerical model ")
        println("  master.PRM      --  PRM file of the radar image")
        println("  dem.grd         --  DEM grid (wider than the coverage of the radar image)")
        println("  los.grd         --  output: file name of the LOS grid ")
        println("")
        println("  note that the grid of the grd files must be consistent")
        println("  note the program need master.PRM and its LED file")
        println("")
        exit(1)
    end

    if !isfile(argv[2]) || !isfile(argv[3]) || !isfile(argv[4])
        println("")
        println("no input model file found: $(argv[2]), $(argv[3]), $(argv[4])")
        println("")
        exit(1)
    end

    if !isfile(argv[5])
        println("")
        println("no input PRM file found: $(argv[5])")
        println("")
        exit(1)
    end

    if !isfile(argv[6])
        println("")
        println("no input DEM grid found: $(argv[6])")
        println("")
        exit(1)
    end

    SAT = argv[1]
    if SAT != "ENVI" && SAT != "ERS" && SAT != "ALOS" && SAT != "SAT"
        println("")
        println(" SAT can be ALOS ENVISAT or ERS or generic SAT")
        println("")
        exit(1)
    end

    ve = argv[2]
    vn = argv[3]
    vu = argv[4]
    prm = argv[5]
    dem = argv[6]
    out = argv[7]

    int = strip(read(`gmt grdinfo -I $ve`, String))
    run(`gmt set FORMAT_GEO_OUT D`)
    run(pipeline(`gmt grd2xyz $dem -fg`, `$(SAT)_look $prm -bos`, stdout="look.xyz"))

    rdem1a = strip(read(`gmt grdinfo -I- $dem`, String))
    rdem1b = strip(read(`gmt grdinfo -I- $dem`, String))
    run(pipeline(`gmt blockmedian look.xyz -i0,1,3 -bi6f $rdem1a $int -bo -fg`,
                 `gmt surface -fg -bi -Gtmp.grd $int $rdem1b -T0.5`))
    run(`gmt grdsample tmp.grd -T -Glle.grd`)

    rdem2a = strip(read(`gmt grdinfo -I- $dem`, String))
    rdem2b = strip(read(`gmt grdinfo -I- $dem`, String))
    run(pipeline(`gmt blockmedian look.xyz -i0,1,4 -bi6f $rdem2a $int -bo -fg`,
                 `gmt surface -fg -bi -Gtmp.grd $int $rdem2b -T0.5`))
    run(`gmt grdsample tmp.grd -T -Glln.grd`)

    rdem3a = strip(read(`gmt grdinfo -I- $dem`, String))
    rdem3b = strip(read(`gmt grdinfo -I- $dem`, String))
    run(pipeline(`gmt blockmedian look.xyz -i0,1,5 -bi6f $rdem3a $int -bo -fg`,
                 `gmt surface -fg -bi -Gtmp.grd $int $rdem3b -T0.5`))
    run(`gmt grdsample tmp.grd -T -Gllu.grd`)

    region = strip(read(`gmt grdinfo -I- llu.grd`, String))
    #echo $region
    run(`gmt grdsample $ve $region $int -Gtmpve.grd -fg`)
    run(`gmt grdsample $vn $region $int -Gtmpvn.grd -fg`)
    run(`gmt grdsample $vu $region $int -Gtmpvu.grd -fg`)
    run(`gmt grdmath tmpve.grd lle.grd MUL tmpvn.grd lln.grd MUL ADD tmpvu.grd llu.grd MUL ADD = $out`)


    #clean up
    rm("look.xyz"; force=true)
    rm("tmp.grd"; force=true)
    rm("lle.grd"; force=true)
    rm("llu.grd"; force=true)
    rm("lln.grd"; force=true)
    rm("tmpve.grd"; force=true)
    rm("tmpvn.grd"; force=true)
    rm("tmpvu.grd"; force=true)
end

main(ARGS)
