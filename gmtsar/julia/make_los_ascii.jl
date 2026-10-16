#!/usr/bin/env julia
# subsample  and LOS grid and add the look vector
# need to include the PRM and LED file in the local directory
#
function main(argv::Vector{String})
    if length(argv) < 1 || length(argv) > 5
        println("")
        println("Usage: make_los_ascii.csh los.grd dem.grd -I0.01/0.01 PRM_file Satellite ")
        println("")
        println("Example: make_los_ascii.csh los_ll.grd dem.grd -I0.01/0.01 IMG-HH-ALOS2046743050-150405-WBDR1.1__D-F1.PRM ALOS")
        println("")
        println("output: los.lltnde")
        exit(1)
    end

    local V::Vector{String}
    if isfile(joinpath(homedir(), ".quiet"))
        V = String[]
    else
        V = ["-V"]
    end

    grdinfo_Ineg = split(strip(read(`gmt grdinfo $(argv[1]) -I-`, String)))
    grdinfo_I = split(strip(read(`gmt grdinfo $(argv[1]) -I`, String)))
    run(`gmt grdsample $(argv[2]) -Gtmp_topo.grd $grdinfo_Ineg $grdinfo_I -F`)
    run(`gmt grdmath $(argv[1]) 0 MUL 1 ADD tmp_topo.grd MUL = tmp_topo.grd`)
    run(pipeline(`gmt grd2xyz $(argv[1])`, stdout="tmp.xyz"))
    run(pipeline(`gmt grd2xyz tmp_topo.grd`, stdout="tmp_topo.xyz"))
    grdinfo_Ineg2 = split(strip(read(`gmt grdinfo $(argv[1]) -I-`, String)))
    run(pipeline(`gmt blockmedian tmp.xyz $grdinfo_Ineg2 $(argv[3]) $V`, stdout="tmp_b.xyz"))
    run(pipeline(`gmt blockmedian tmp_topo.xyz $grdinfo_Ineg2 $(argv[3]) $V`, stdout="tmp_topo_b.xyz"))

    SAT = argv[5]
    if SAT == "ERS"
        SAT = "ENVI"
    end

    run(pipeline(`$(SAT)_look $(argv[4])`, stdin="tmp_topo_b.xyz", stdout="tmp_topo_b_n.lltn"))
    b_lines = readlines("tmp_b.xyz")
    topo_lines = readlines("tmp_topo_b_n.lltn")
    open("los.lltnde", "w") do io
        for (bl, tl) in zip(b_lines, topo_lines)
            bf = split(bl)
            a = bf[3]
            tf = split(tl)
            println(io, tf[1], " ", tf[2], " ", tf[3], " ", tf[4], " ", tf[5], " ", tf[6], " ", a, " ", -1)
        end
    end
    for f in readdir(".")
        if startswith(f, "tmp")
            rm(f; force=true)
        end
    end
end

main(ARGS)
