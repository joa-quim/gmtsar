#!/usr/bin/env julia
#       $Id$
# Usage: m2s.csh pixel_size_in_meters llpfile
#
# Convert pixel dimension in meters to dx/dy in arc seconds at mean latitude
function main(argv::Vector{String})
    pix = argv[1]    # Input pixel dimension in meters
    llp = argv[2]    # lon lat phase binary float file
    # 1. Get w e s n in array
    range = split(strip(read(`gmt gmtinfo $llp -bi3f -C`, String)))
    # 2. Get mean latitude
    mlat = strip(read(`gmt math -Q $(range[3]) $(range[4]) ADD 2 DIV =`, String))
    # 3. Get nearest integer 1/2 arc second for latitude (at least 1")
    dy = strip(read(`gmt math -Q $pix 111195.079734 DIV 3600 MUL 2 MUL RINT 1 MAX 2 DIV =`, String))
    # 4. Get nearest integer 1/2 arc second for longitude at mean latitude (at least 1")
    dx = strip(read(`gmt math -Q $pix 111195.079734 DIV $mlat COSD DIV 3600 MUL 2 MUL RINT 1 MAX 2 DIV =`, String))
    # Report two -Idx/dy settings: first for actual grid and 2nd for 10 times larger intervals
    inc1 = "$(dx)s/$(dy)s"
    dx = strip(read(`gmt math -Q $dx 10 MUL =`, String))
    dy = strip(read(`gmt math -Q $dy 10 MUL =`, String))
    inc2 = "$(dx)s/$(dy)s"
    println("$inc1 $inc2")
end

main(ARGS)
