[![GMTSAR tests](https://github.com/gmtsar/gmtsar/actions/workflows/gmtsar.yml/badge.svg)](https://github.com/gmtsar/gmtsar/actions/workflows/gmtsar.yml)

__ABOUT THIS FORK__
-------------------

This repository (joa-quim/gmtsar) is a fork of the official GMTSAR repository, [gmtsar/gmtsar](https://github.com/gmtsar/gmtsar), whose changes are merged in regularly. It differs from the original in these ways:

- **Windows**: GMTSAR builds natively on Windows with MSVC, and also with MinGW-w64, with CMake.
- **GMT modules**: the GMTSAR programs (core, Sentinel-1, ALOS, ERS, ENVISAT, TSX, RS2, CSK and snaphu) are also built as GMT modules in the `gmtsar` shared library, so they run in-process from GMT and from GMT's language wrappers (e.g. GMT.jl). Small executables in `gmtsar/cli` keep the traditional command-line syntax. The Makefiles still build the standalone programs.
- **InteractiveGMT plugin**: that library is also built against GMT_jll as a plugin that [InteractiveGMT](https://github.com/joa-quim/InteractiveGMT) downloads and installs (Geophysics > GMTSAR > Install as plugin).
- **Julia scripts**: `gmtsar/julia` holds Julia ports of the csh processing scripts (`p2p_S1_TOPS_Frame`, `p2p_ALOS2_SCAN_Frame`, `intf_tops`, ...), with the same names. See [gmtsar/julia/README.md](gmtsar/julia/README.md) for what they need and how to run them with the GMT modules.
- **Builds for download**: GitHub Actions builds GMTSAR for Windows, Linux and macOS, and the InteractiveGMT plugins for Windows, Linux and macOS (arm64 and x86_64). All of them are on the [gmtsar-latest release](https://github.com/joa-quim/gmtsar/releases/tag/gmtsar-latest), rebuilt from every change to master.

Questions about GMTSAR itself belong to the official project; issues with the Windows port, the GMT modules, the Julia scripts or the InteractiveGMT plugin belong here.

__INSTRUCTIONS FOR INSTALLING AND RUNNING GMTSAR__
----------------------------------------------

...

__RUN__

1) GET DATA. There is an example data set at our website:
       https://topex.ucsd.edu/gmtsar/downloads/

Uncompress the file and then unpack with tar.

2) ORGANIZE the DISK. The standard GMTSAR run has the following directories. 

  raw    SLC    topo   intf

raw - contains the original data.

SLC - contains the single look complex images derived from the raw data.

topo - contains a digital elevation model for the area in geographic and ultimately radar coordinates.

intf - contains subdirectories with the possible interferograms (only 1 for this example).

3) MAKE DEM 

Enter the following command to make a NETCDF file of heights above the ellipsoid from SRTM.  This used the GMT dem 
generation facility.
	make_dem.csh W E S N [mode]
Place the file dem.grd in the /topo directory. 

4) EXAMPLE RUNS

There are complete examples for each data type at the following web site:
      https://topex.ucsd.edu/gmtsar/downloads/

To process a pair interferogram, try `p2p_processing.csh`, or `p2p_S1_TOPS_Frame.csh` for Sentinel-1 TOPS data and `p2p_ALOS2_SCAN_Frame.csh` for ALOS-2 ScanSAR data. For batch processing, see instructions in the GMTSAR documentation (http://topex.ucsd.edu/gmtsar/tar/GMTSAR_2ND_TEX.pdf) or the Sentinel-1 time-series recipe (http://topex.ucsd.edu/gmtsar/tar/sentinel_time_series_5.pdf).
