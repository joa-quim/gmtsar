#!/bin/csh -f
#       $Id$
# Matt WEI Feb 1 2010
# modified by Xiaopeng Feb 9 2010
# modifed by E. Feilding, DST, XT to add TSX data Jan 10 2014
#=======================================================================
#  script to make topography for interferograms 
#  The USGS elevations are height above WGS84 so this is OK.
#
alias rm 'rm -f'
unset noclobber
#
if ($#argv < 2) then
 echo " "
 echo "Usage: dem2topo_ra.csh master.PRM dem.grd" 
 echo " "
 echo "        Note: Works for TSX,ALOS,ERS,ENVISAT"
 echo " "
 exit 1
endif 

#
# local variables 
#
  set scale = -JX8i
#
#========================Mosaic topo data===============================

#-----------------------------------------------------------------------
# 

#------------------------Get bounds in radar coordinates----------------
set XMAX = `grep num_rng_bins $1 | awk '{print $3}'`
set yvalid = `grep num_valid_az $1 | awk '{print $3}'`
set num_patch = `grep num_patches $1 | awk '{print $3}'`
set YMAX = `echo "$yvalid $num_patch" | awk '{print $1*$2}'`
set SC = `grep SC_identity $1 | awk '{print $3}'`
set PRF = `grep PRF *.PRM | awk 'NR == 1 {printf("%d", $3)}'`
#
# look for range sampling rate
#
  set rng_samp_rate = `grep rng_samp_rate $1 | awk 'NR == 1 {printf("%d", $3)}'`

# set the range spacing of simulation in units of image range pixel size

if($rng_samp_rate > 0 && $rng_samp_rate < 25000000) then
  set rng = 1
else if($rng_samp_rate >= 25000000 && $rng_samp_rate < 72000000 || $SC == 7 ) then
  set rng = 2
else if($rng_samp_rate >= 72000000) then
  set rng = 4
else
   echo "range sampling rate out of bounds"
   exit 0
endif
echo " range decimation is: " $rng

#   use special ALOS_llt2rat if this is ALOS otherwise use SAT_llt2rat

if ($SC == 5) then
  echo " processing for ALOS data"
  gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $2 -s | ALOS_llt2rat $1 0 -bod  > trans.dat
else 
  echo " processing generic data"
  if($SC == 10) then
     gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $2 -s | SAT_llt2rat $1 1 -bod  > trans.dat
  else
     gmt grd2xyz --FORMAT_FLOAT_OUT=%lf $2 -s | SAT_llt2rat $1 0 -bod  > trans.dat
  endif
endif
#
# use an aximuth spacing of 2 for low PRF data such as S1A TOPS
#
if ($PRF < 1000) then
  gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d | gmt blockmedian -R0/$XMAX/0/$YMAX -I2/32 -bi3d -bo3d -r -V > temp.rat 
  gmt surface temp.rat -Q -R0/$XMAX/0/$YMAX -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r -V >& tmp.hint
  set nregion = `grep Hint tmp.hint | awk 'NR==1 {print $4}'`
  echo "region=$nregion"
  gmt surface temp.rat $nregion -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r -V 
  gmt grdsample pixel.grd -R0/$XMAX/0/$YMAX -I2/32 -r -Gpixel.grd
else
  gmt gmtconvert trans.dat -o0,1,2 -bi5d -bo3d | gmt blockmedian -R0/$XMAX/0/$YMAX -I2/32 -bi3d -bo3d -r -V > temp.rat 
  gmt surface temp.rat -Q -R0/$XMAX/0/$YMAX -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r -V >& tmp.hint
  set nregion = `grep Hint tmp.hint | awk 'NR==1 {print $4}'`
  echo "region=$nregion"
  gmt surface temp.rat $nregion -I2/32 -bi3d -T.50 -N1000 -Gpixel.grd -r -V 
  gmt grdsample pixel.grd -R0/$XMAX/0/$YMAX -I2/32 -r -Gpixel.grd
endif
# 
# flip top to bottom for both ascending and descending passes
#  
  gmt grdmath pixel.grd FLIPUD = topo_ra.grd
# 
# plotting
# 
  gmt grd2cpt topo_ra.grd -Cgray -V -Z > topo_ra.cpt 
  gmt grdimage topo_ra.grd $scale -X0.2i -P -Ctopo_ra.cpt -V > topo_ra.ps
#
#  clean up
#
rm pixel.grd temp.rat dem.xyz 
rm topo_ra.cpt
