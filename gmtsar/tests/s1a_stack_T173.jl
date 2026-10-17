#!/usr/bin/env julia
#
# The Sentinel-1 stack test of GMTSAR (S1A_Stack_CPGF_T173: 5 TOPS scenes, subswath IW1, track 173),
# run from the Julia ports of the GMTSAR scripts (gmtsar/julia), with every GMTSAR step a GMT module
# of the gmtsar plugin run by GMT (`gmt make_s1a_tops -A... -B...`, `gmt sbas ...`): no standalone
# GMTSAR program is used.
#
# It does what the dataset's README_prep.txt, README_proc.txt and README_sbas.txt do (upstream's CI
# job S1A_Stack_CPGF_T173 in .github/workflows/gmtsar.yml runs those csh files), with csh replaced
# by Julia:
#   prep  preprocess and align the 5 scenes        preproc_batch_tops.jl data.in dem.grd 2
#   proc  9 interferograms, unwrapped, geocoded    intf_tops.jl intf.in batch_tops.config
#   sbas  SBAS velocity, projected to lon/lat, KML  gmt sbas, proj_ra2ll.jl, grd2kml.jl
#
# Usage:
#   julia s1a_stack_T173.jl --share <dir> [--plugin <lib>] [--data <dir>] [--steps prep,proc,sbas]
#
#   --share  the GMTSAR share directory, <prefix>/share/gmtsar (env GMTSAR_SHAREDIR)
#   --plugin the gmtsar plugin library to test (gmtsar.dll/.so/.dylib). Without it, GMT uses the
#            gmtsar plugin it already has (its plugin directory, or GMT_CUSTOM_LIBS in gmt.conf).
#            With it, every gmt call gets GMT_CUSTOM_LIBS=<lib> through a GMT user directory made
#            for the run (GMT_USERDIR); a gmtsar plugin in GMT's own plugin directory is loaded
#            first and would win, so it must be that same build or absent.
#   --data   where the dataset is downloaded (1.66 GB, kept for later runs) and processed
#            (default: <tempdir>/S1A_Stack_CPGF_T173)
#   --steps  which steps to run (default: all three, in order); later steps reuse earlier results
#
# GMT itself (`gmt`) must be on PATH, with the libraries the plugin needs. The test fails (exit 1) if a step fails or the final
# velocity grid is missing or has no finite values.

using Downloads

const DATA_URL = "https://topex.ucsd.edu/gmtsar/tar/S1A_Stack_CPGF_T173.tar.gz"
const JULIA_DIR = normpath(joinpath(@__DIR__, "..", "julia"))
const JL = `$(Base.julia_cmd()) --startup-file=no`
script(name) = joinpath(JULIA_DIR, name * ".jl")

# The five scenes and their precise orbits (README_prep.txt).
const SCENES = [
	"s1a-iw1-slc-vv-20150403t134413-20150403t134424-005320-006bc4-001" => "S1A_OPER_AUX_POEORB_OPOD_20150424T123026_V20150402T225944_20150404T005944.EOF",
	"s1a-iw1-slc-vv-20150121t134413-20150121t134424-004270-005317-001" => "S1A_OPER_AUX_POEORB_OPOD_20150211T122339_V20150120T225944_20150122T005944.EOF",
	"s1a-iw1-slc-vv-20150310t134412-20150310t134424-004970-006386-001" => "S1A_OPER_AUX_POEORB_OPOD_20150331T123006_V20150309T225944_20150311T005944.EOF",
	"s1a-iw1-slc-vv-20150427t134414-20150427t134426-005670-00745c-001" => "S1A_OPER_AUX_POEORB_OPOD_20150518T122528_V20150426T225944_20150428T005944.EOF",
	"s1a-iw1-slc-vv-20150521t134415-20150521t134427-006020-007c3f-001" => "S1A_OPER_AUX_POEORB_OPOD_20150611T122710_V20150520T225944_20150522T005944.EOF",
]

# The interferograms (README_proc.txt).
const PAIRS = ["S1_20150121_ALL_F1:S1_20150310_ALL_F1", "S1_20150121_ALL_F1:S1_20150403_ALL_F1",
               "S1_20150121_ALL_F1:S1_20150427_ALL_F1", "S1_20150310_ALL_F1:S1_20150403_ALL_F1",
               "S1_20150310_ALL_F1:S1_20150427_ALL_F1", "S1_20150310_ALL_F1:S1_20150521_ALL_F1",
               "S1_20150403_ALL_F1:S1_20150427_ALL_F1", "S1_20150403_ALL_F1:S1_20150521_ALL_F1",
               "S1_20150427_ALL_F1:S1_20150521_ALL_F1"]

# SBAS inputs (README_sbas.txt): interferogram, days, perpendicular baseline; scene, day.
const INTF_TAB = [("2015020_2015068", -90.333), ("2015020_2015092", -52.6118), ("2015020_2015116", -83.0324),
                  ("2015068_2015092", 37.7213), ("2015068_2015116", 7.30062), ("2015068_2015140", -13.2457),
                  ("2015092_2015116", -30.4207), ("2015092_2015140", -50.967), ("2015116_2015140", -20.5463)]
const SCENE_TAB = ["2015092 448", "2015020 376", "2015068 424", "2015116 472", "2015140 496"]

function parse_args(args)
	opt = Dict("plugin" => "", "share" => get(ENV, "GMTSAR_SHAREDIR", ""),
	           "data" => joinpath(tempdir(), "S1A_Stack_CPGF_T173"), "steps" => "prep,proc,sbas")
	i = 1
	while i <= length(args)
		k = lstrip(args[i], '-')
		(haskey(opt, k) && i < length(args)) || error("unknown or incomplete option $(args[i])")
		opt[k] = args[i+1]
		i += 2
	end
	(isempty(opt["plugin"]) || isfile(opt["plugin"])) || error("--plugin: no file '$(opt["plugin"])'")
	isdir(joinpath(opt["share"], "filters")) || error("--share: '$(opt["share"])' has no filters/ (the GMTSAR share directory)")
	return opt
end

# Link `src` as `dst` as the README's `ln -s` does; Windows without symlink rights gets a hard
# link (same volume) or, failing that, a copy.
function link(src, dst)
	ispath(dst) && rm(dst; force = true)
	try
		symlink(src, dst)
	catch
		try
			hardlink(src, dst)
		catch
			cp(src, dst)
		end
	end
end

function fetch(dir)
	mkpath(dir)
	isdir(joinpath(dir, "raw_orig")) && return
	tarball = joinpath(dir, "S1A_Stack_CPGF_T173.tar.gz")
	if !isfile(tarball)
		println("Downloading $DATA_URL (1.66 GB) ...")
		Downloads.download(DATA_URL, tarball * ".part")
		mv(tarball * ".part", tarball)
	end
	println("Unpacking $tarball ...")
	# Relative name, run in the directory: a GNU tar on Windows reads "C:..." as a remote host.
	cd(() -> run(`tar -xzf $(basename(tarball))`), dir)
end

# README_prep.txt: the annotation files (scene xml + manifest without its first line + calibration
# xml), links to the images, orbits and DEM, data.in, then preprocessing and alignment.
function prep(dir)
	raw, orig = joinpath(dir, "raw"), joinpath(dir, "raw_orig")
	rm(raw; recursive = true, force = true)
	mkpath(raw)
	cal = read(joinpath(orig, "s1a-aux-cal.xml"), String)
	for (stem, _) in SCENES
		date = match(r"-(\d{8})t", stem).captures[1]
		manifest = readlines(joinpath(orig, "$(date)_manifest.safe"); keep = true)
		write(joinpath(raw, stem * ".xml"), read(joinpath(orig, stem * ".xml"), String) * join(manifest[2:end]) * cal)
	end
	for f in readdir(orig)
		(endswith(f, "EOF") || endswith(f, "tiff")) && link(joinpath(orig, f), joinpath(raw, f))
	end
	link(joinpath(dir, "topo", "dem.grd"), joinpath(raw, "dem.grd"))
	write(joinpath(raw, "data.in"), join(("$s:$o" for (s, o) in SCENES), '\n') * '\n')
	cd(() -> run(`$JL $(script("preproc_batch_tops")) data.in dem.grd 2`), raw)
end

# README_proc.txt: the interferograms.
function proc(dir)
	cd(dir) do
		rm("intf.in"; force = true)
		rm("intf"; recursive = true, force = true)
		rm("intf_all"; recursive = true, force = true)
		write("intf.in", join(PAIRS, '\n') * '\n')
		run(`$JL $(script("intf_tops")) intf.in batch_tops.config`)
	end
end

# README_sbas.txt: SBAS time series and mean velocity, projected and made into a KML.
function sbas(dir)
	sb = joinpath(dir, "SBAS")
	rm(sb; recursive = true, force = true)
	mkpath(sb)
	cd(sb) do
		write("intf.tab", join(("../intf_all/$p/unwrap.grd ../intf_all/$p/corr.grd $(replace(p, '_' => ' ')) $b" for (p, b) in INTF_TAB), '\n') * '\n')
		write("scene.tab", join(SCENE_TAB, '\n') * '\n')
		info = split(read(`gmt grdinfo -C ../intf_all/2015068_2015092/unwrap.grd`, String))
		xdim, ydim = info[10], info[11]
		# sbas intf.tab scene.tab 9 5 xdim ydim -smooth 1.0 -wavelength 0.0554658 -incidence 30 -range 800184.946186 -rms -dem
		run(`gmt sbas -Aintf.tab -Bscene.tab -N9 -S5 -X$xdim -Y$ydim -M1.0 -W0.0554658 -C30 -D800184.946186 -Q -E`)
		link(joinpath(dir, "topo", "trans.dat"), "trans.dat")
		run(`$JL $(script("proj_ra2ll")) trans.dat vel.grd vel_ll.grd`)
		run(pipeline(`gmt grd2cpt vel_ll.grd -T= -Z -Cjet`, stdout = "vel_ll.cpt"))
		run(`$JL $(script("grd2kml")) vel_ll vel_ll.cpt`)
	end
end

# The result: a velocity grid in lon/lat with finite values.
function check(dir)
	g = joinpath(dir, "SBAS", "vel_ll.grd")
	isfile(g) || error("no $g")
	r = split(read(`gmt grdinfo -C -L $g`, String))   # ... z_min z_max ...
	zmin, zmax = parse(Float64, r[6]), parse(Float64, r[7])
	(isfinite(zmin) && isfinite(zmax)) || error("$g has no finite values")
	println("vel_ll.grd: z from $zmin to $zmax")
end

function main(args)
	opt = parse_args(args)
	if !isempty(opt["plugin"])
		userdir = mktempdir()
		lib = replace(abspath(opt["plugin"]), '\\' => '/')   # gmt.conf has no backslash path separator
		write(joinpath(userdir, "gmt.conf"), "GMT_CUSTOM_LIBS = $lib\n")
		ENV["GMT_USERDIR"] = userdir
	end
	# GMT must have the GMTSAR modules (the plugin loaded) before anything runs.
	"make_s1a_tops" in split(read(`gmt --show-modules`, String)) ||
		error("GMT has no GMTSAR modules: the gmtsar plugin is not loaded (see --plugin)")
	ENV["GMTSAR_SHAREDIR"] = abspath(opt["share"])
	dir = abspath(opt["data"])
	fetch(dir)
	steps = split(opt["steps"], ',')
	for (name, f) in (("prep", prep), ("proc", proc), ("sbas", sbas))
		name in steps || continue
		println("==== $name")
		t = @elapsed f(dir)
		println("==== $name done in $(round(t / 60; digits = 1)) min")
	end
	"sbas" in steps && check(dir)
	println("S1A_Stack_CPGF_T173: OK")
end

try
	main(ARGS)
catch e
	println(stderr, "S1A_Stack_CPGF_T173: FAILED: ", sprint(showerror, e))
	exit(1)
end
