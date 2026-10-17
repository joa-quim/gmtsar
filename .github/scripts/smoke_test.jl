# Smoke test of the GMTSAR GMT plugin as InteractiveGMT loads it: GMT.jl on GMT_jll, the plugin
# named in GMT_CUSTOM_LIBS of a ./gmt.conf that GMT itself wrote with gmtset.
#
#   julia --project=<env> smoke_test.jl setup <path/to/gmtsar.{so,dylib,dll}>
#   julia --project=<env> smoke_test.jl run   <directory the plugin was unpacked to>
#
# Two processes, because GMT builds its plugin list ONCE, in GMT_Create_Session (gmt_api.c,
# gmtapi_init_sharedlibs); setting GMT_CUSTOM_LIBS in a live session only stores the string.
# `setup` has GMT write ./gmt.conf; `run` starts a new session in that directory, which reads it.
# Both run in the same (scratch) directory.

using GMT, Libdl

if ARGS[1] == "setup"
	GMT.isJLL || error("GMT.jl is not running GMT_jll here")
	gmt("gmtset GMT_CUSTOM_LIBS " * replace(ARGS[2], '\\' => '/'))
	println(filter(l -> occursin("GMT_CUSTOM_LIBS", l), readlines("gmt.conf")))
	exit(0)
end

probedir = lowercase(normpath(ARGS[2]))
api = GMT.G_API[]
exists(m) = GMT.GMT_Call_Module(api, m, GMT.GMT_MODULE_EXIST, C_NULL) == 0
# Straight through GMT_Call_Module: GMT.jl's gmt() appends its own output options (->@G...).
callm(m, a) = GC.@preserve a GMT.GMT_Call_Module(api, m, GMT.GMT_MODULE_CMD, pointer(a))

for m in ("nearest_grid", "SAT_baseline", "make_s1a_tops", "snaphu")
	println(rpad(m, 16), exists(m) ? "found" : "MISSING")
	exists(m) || error("GMT did not load the GMTSAR plugin (no module $m)")
end

ours = filter(l -> startswith(lowercase(normpath(l)), probedir), Libdl.dllist())
println("loaded from the archive: ", ours)
any(l -> lowercase(basename(l)) in ("gmtsar.so", "gmtsar.dylib", "gmtsar.dll"), ours) ||
	error("the plugin loaded is not the one in the archive")

# A grid both ways: GMT writes one with a NaN in the middle, the GMTSAR module fills it through
# GMT's own grid I/O, and GMT reads the result back.
st = callm("grdmath", "-R0/4/0/4 -I1 X Y ADD X 2 SUB ABS Y 2 SUB ABS ADD 0 NAN 0 MUL ADD = in.grd")
st == 0 || error("grdmath failed (status $st)")
st = callm("nearest_grid", "in.grd -Gout.grd")
println("nearest_grid status = ", st)
(st == 0 && isfile("out.grd")) || error("nearest_grid did not write its grid")
In  = gmtread("in.grd")
Out = gmtread("out.grd")
println("NaN nodes: in ", count(isnan, In.z), ", out ", count(isnan, Out.z))
count(isnan, In.z) == 1 || error("the input grid does not have the one NaN node it should")
any(isnan, Out.z) && error("nearest_grid left NaN nodes")
size(Out.z) == size(In.z) || error("the output grid is not the size of the input")
println("GMTSAR plugin OK")
