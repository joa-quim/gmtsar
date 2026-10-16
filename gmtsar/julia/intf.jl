#!/usr/bin/env julia
#       $Id$
#
#  Xiaopeng Tong FEB 4 2010
#
# Make the interferogram.
#
#  Matt Wei May 4 2010, ENVISAT
#
# add in TSX, Jan 10 2014
# alias rm 'rm -f'

"""grep PATTERN file | awk '{print \$3}'  -- first matching line's 3rd whitespace field"""
function grep_field(file::AbstractString, pattern::AbstractString)
    for line in eachline(file)
        if occursin(pattern, line)
            return split(line)[3]
        end
    end
    error("pattern not found: $pattern in $file")
end

function usage_and_exit()
    println("")
    println("Usage: intf.csh ref.PRM rep.PRM [-topo topogrd] [-model modelgrd]")
    println("")
    println(" The dimensions of topogrd and modelgrd should be compatible with SLC file.")
    println("")
    println("Example: intf.csh IMG-HH-ALPSRP055750660-H1.0__A.PRM IMG-HH-ALPSRP049040660-H1.0__A.PRM -topo topo_ra.grd")
    println("")
    exit(1)
end

function main(argv::Vector{String})
    run(`gmt set IO_NC4_CHUNK_SIZE classic`)
    #
    #
    if length(argv) < 2
        usage_and_exit()
    end
    #
    # which satellite
    #
    SC = grep_field(argv[1], "SC_identity")
    if SC == "1" || SC == "2" || SC == "4" || SC == "6" || SC == "5"
        cp(argv[2], argv[2] * "0"; force=true)
        cp(argv[1], argv[1] * "0"; force=true)
        out = read(`SAT_baseline $(argv[1]) $(argv[2])`, String)
        lines = split(out, '\n')
        # drop a trailing empty element left by a final newline
        !isempty(lines) && lines[end] == "" && (lines = lines[1:end-1])
        tail9 = lines[max(1, length(lines) - 8):end]
        open(argv[2], "a") do io
            for line in tail9
                println(io, line)
            end
        end
        out2 = read(`SAT_baseline $(argv[1]) $(argv[1])`, String)
        open(argv[1], "a") do io
            for line in split(out2, '\n')
                if occursin("height", line)
                    println(io, line)
                end
            end
        end
    elseif parse(Int, SC) > 6
        cp(argv[2], argv[2] * "0"; force=true)
        cp(argv[1], argv[1] * "0"; force=true)
        out = read(`SAT_baseline $(argv[1]) $(argv[2])`, String)
        lines = split(out, '\n')
        !isempty(lines) && lines[end] == "" && (lines = lines[1:end-1])
        tail9 = lines[max(1, length(lines) - 8):end]
        open(argv[2], "a") do io
            for line in tail9
                println(io, line)
            end
        end
        out2 = read(`SAT_baseline $(argv[1]) $(argv[1])`, String)
        open(argv[1], "a") do io
            for line in split(out2, '\n')
                if occursin("height", line)
                    println(io, line)
                end
            end
        end
    else
        println("Incorrect satellite id in prm file")
        exit(0)
    end
    #
    # form the interferogram optionally using topo_ra and modelphase
    #
    if length(argv) == 2 || length(argv) == 4 || length(argv) == 6
        println("intf.csh")
        println("running phasediff...")
        run(Cmd(["phasediff"; argv]))
    else
        usage_and_exit()
    end
    mv(argv[1] * "0", argv[1]; force=true)
    mv(argv[2] * "0", argv[2]; force=true)
end

main(ARGS)
