# Shared by the Julia ports of the GMTSAR shell scripts.
#
# A script that called another script (`intf.csh ...`) calls that script's Julia port instead
# (intf.jl, next to this file), in a new Julia process, as csh started a new csh:
#
#     run(`$GMTSAR_JULIA $(gmtsar_script("intf")) $ref.PRM $rep.PRM`)
#
# The GMTSAR programs themselves (make_s1a_tops, SAT_baseline, ...) are run from PATH. In the
# CMake build they are thin wrappers that run the GMT_<name> modules of the gmtsar plugin
# library (gmtsar.dll / gmtsar.so / gmtsar.dylib).

# The Julia running this script, without the user's startup file.
const GMTSAR_JULIA = `$(Base.julia_cmd()) --startup-file=no`

# The Julia port of GMTSAR script `name` (no extension).
gmtsar_script(name::AbstractString) = joinpath(@__DIR__, name * ".jl")
