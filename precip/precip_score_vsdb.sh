#!/bin/ksh
set -x

##--------------------------------------------------------------------
## Fanglin Yang, Oct 2010
##   Read in precip FHO data saved in VSDB format, compute precip threat 
##   skill scores, and make maps with Monte Carlo significane tests
##--------------------------------------------------------------------


stymd=${1:-${stymd:-20100601}}           ;#verification starting date 
edymd=${2:-${edymd:-20100901}}           ;#verification ending date
region=${3:-${region:-"G211/RFC"}}       ;#default G211/RFC is CONUS
fhour=${4:-${fhour:-"24 48"}}            ;#fcst hours of 24-hr accumulations to be included
expids=${5:-${expids:-"gfs nam ecmwf"}}  ;#up to 10 models


export datdir=${datdir:-/mmb/wd22yl/vsdb}                          ;#precip vsdb archive directory
export scrdir=${scrdir:-/global/save/wx24fy/VRFY/vsdb/precip} ;#source code and executable etc, do not change
export rundir=${rundir:-/ptmp/$LOGNAME/prvsdb}                     ;#temporaray running directory
export timeplot=${timeplot:-"YES"}                                 ;#plot time series for each intensity?
export mapdir=${mapdir:-/ptmp/$LOGNAME/prmap}                      ;#place to save plots at local machine
export webhost=${webhost:-"emcrzdm.ncep.noaa.gov"}                 ;#web display server                          
export webhostid=${webhostid:-"$LOGNAME"}                                  
export ftpdir=${ftpdir:-/home/people/emc/www/htdocs/gmb/$LOGNAME/etsbis}   
export doftp=${doftp:-"NO"}                                               
export archmon=${archmon:-"NO"}                                    ;#rename files and make archive
export NWPROD=${NWPROD:-/nwprod}
export ndate=${ndate:-$NWPROD/util/exec/ndate}
export vsdbhome=${vsdbhome:-/global/save/$LOGNAME/VRFY/vsdb}
export SUBJOB=${SUBJOB:-$vsdbhome/bin/sub_wcoss}
export ACCOUNT=${ACCOUNT:-GFS-T2O}
export CUE2RUN=${CUE2RUN:-shared}
export CUE2FTP=${CUE2FTP:-${CUE2RUN:-transfer}}
export GROUP=${GROUP:-g01}


catp=${catp:-".01 .10 .25 .50 .75 1.0 1.5 2.0 3.0"} ;#precip intensity category, inches/24hour
ncat=`echo $catp |wc -w`                            ;# number of precip intensity category
nfhr=`echo $fhour |wc -w`                           ;# number of 24-hour accumulations              
nexp=`echo $expids | wc -w`                         ;# number of experiments, must be within 10
ntest=${ntest:-10000}                               ;# number of monte carlo significane tests
area=`echo $region | sed "s?/??g" `
stymdc=`$scrdir/util/datestamp.sh $stymd 0 `
edymdc=`$scrdir/util/datestamp.sh $edymd 0 `
nexp1=`expr $nexp - 1 `


#=========================================================
#=========================================================
set -A fhours none $fhour
fhs=${fhours[1]}; fhe=${fhours[$nfhr]}

rundir0=${rundir}/${area}fh${fhs}fh${fhe}_${stymd}_${edymd}
mkdir -p $rundir0; cd $rundir0 || exit 8; rm $rundir0/*
if [ ! -s $mapdir ]; then mkdir -p $mapdir ; fi


nid=0
for ID in $expids ; do
nid=`expr $nid + 1 `
rm vsdbdata$nid ; touch vsdbdata$nid
model=`echo $ID |tr "[a-z]" "[A-Z]" `

for fh in $fhour; do
ymd=$stymd; ndays=0
while [ $ymd -le $edymd ]; do
   ndays=`expr $ndays + 1 `
   rm outtmp
   >outtmp
   for xcat in $catp; do
     grep " $model $fh " $datdir/${ID}/${ID}_${ymd}.vsdb |grep  " $region " |grep "FHO>${xcat} " >>outtmp       
   done
    fsize=`ls -l outtmp | awk '{print $5}'`
    #fline=`wc -l outtmp | cut -f 1 -d outtmp `
    fline=`wc -l outtmp | awk '{print $1}'`    
    if [ $fsize -le 1 -o $fline -ne $ncat ]; then
      nn=1
      while [ $nn -le $ncat ]; do
       echo "missing" >>vsdbdata$nid
       nn=`expr $nn + 1 `
      done
    else
      cat outtmp >>vsdbdata$nid
    fi
   ymd=`$ndate 24 $ymd\00 | cut -c1-8`
done
done
done
#-------------------------------------------------

${scrdir}/exec/precip_score_vsdb.x $nfhr $ncat $ndays $nexp $ntest
if [ $? -ne 0 ]; then exit 8 ; fi


mv fort.20 ${area}f${fhs}f${fhe}_daily.dat    
mv fort.30 ${area}f${fhs}f${fhe}_mean.dat 
mv fort.40 ${area}f${fhs}f${fhe}_std_montecarlo.dat 
mv fort.50 ${area}f${fhs}f${fhe}_dif_montecarlo.dat 
mv fort.99 ${area}f${fhe}.txt


#------------- GrADS control files ------------------
cat >${area}f${fhs}f${fhe}_daily.ctl <<EOF
dset ^${area}f${fhs}f${fhe}_daily.dat
format sequential big_endian 
undef -9999.0   
title daily-sample skill scores, y-models, x-category
xdef    $ncat linear 1 1
ydef    $nexp linear 1 1
zdef    1 linear    1.000  1.0000
tdef   $ndays linear   00z$stymdc     24hr
vars    3
bis   0 0 bias score
ets   0 0 equitable threat acore
obs   0 0 total obs counts
endvars
EOF

cat >${area}f${fhs}f${fhe}_mean.ctl <<EOF
dset ^${area}f${fhs}f${fhe}_mean.dat
format sequential big_endian
undef -9999.0   
title  all-sample skill scores, x-category, y-models
xdef    $ncat linear 1 1
ydef    $nexp linear 1 1
zdef    1 linear    1.000  1.0000
tdef 1 linear   00z$stymdc     24hr
vars    8 
bis  0 0 all-sample bias score
ets  0 0 all-sample equitable threat acore
obt  0 0 observed grid counts above a given threshold
mbis  0 0 mean of daily bias score
mets  0 0 mean of equitable threat acore
vbis  0 0 standard deviation of daily bias score
vets  0 0 standard deviation of equitable threat acore
ngood 0 0 number of sampele days used to compute mean and standard deviation
endvars
EOF

cat >${area}f${fhs}f${fhe}_std_montecarlo.ctl <<EOF
dset ^${area}f${fhs}f${fhe}_std_montecarlo.dat
format sequential  big_endian
undef -9999.0   
title  x-category, y-models
xdef    $ncat linear 1 1
ydef    $nexp linear 1 1
zdef    1 linear    1.000  1.0000
tdef 1 linear   00z$stymdc     24hr
vars    2 
std_bis 0 0 standard devistion of bias score differences from Monte Carlo tests
std_ets 0 0 standard deviation of equitable threat score differences from Monte Carlo tests
endvars
EOF
 
cat >${area}f${fhs}f${fhe}_dif_montecarlo.ctl <<EOF
dset ^${area}f${fhs}f${fhe}_dif_montecarlo.dat
format sequential  big_endian
undef -9999.0   
title  x-category, z-monte carlo ntest, t-model
xdef    $ncat linear 1 1
ydef    1 linear     1 1
zdef    $ntest linear    1.000  1.0000
tdef $nexp1 linear   1jan1900   1dy        
vars    2 
dif_bis $ntest 0 bias score differences from Monte Carlo tests
dif_ets $ntest 0 equitable threat score differences from Monte Carlo tests
endvars
EOF
#------------- end of GrADS control files --------


#------------------------------------------------
#------------- Make maps -------------------------
fh00=`expr $fhs - 24 `
if [ $fh00 -le 10 ]; then fh00=0$fh00 ; fi

#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#////////////////////////////////////////////////////////////
# PLOT 1:  All-sample ETS BIAS with significance test 
areac=$area ; if [ $area = "G211RFC" ]; then areac="CONUS" ; fi
set -A expname none `echo $expids |tr "[a-z]" "[A-Z]" ` 
set -A catpc none $catp

cat >etsbis.${area}f${fhs}f${fhe}.gs <<EOF1 
'reinit'; 'set font 1'
'open ${area}f${fhs}f${fhe}_mean.ctl'
'open ${area}f${fhs}f${fhe}_std_montecarlo.ctl'

*-- define line styles 
  cst.1=1; cst.2=1; cst.3=1; cst.4=1; cst.5=1; cst.6=1; cst.7=1; cst.8=1; cst.9=1; cst.10=1
  cth.1=12; cth.2=12; cth.3=9; cth.4=9; cth.5=9; cth.6=9; cth.7=9; cth.8=9; cth.9=9; cth.10=9
  cma.1=2; cma.2=3; cma.3=6; cma.4=8; cma.5=7; cma.6=5; cma.7=4; cma.8=1; cma.9=9; cma.10=10
  cco.1=1; cco.2=2; cco.3=3; cco.4=4; cco.5=8; cco.6=9; cco.7=5; cco.8=6; cco.9=7; cco.10=15
  bar.1=30; bar.2=40; bar.3=50; bar.4=60; bar.5=70; bar.6=80; bar.7=90; bar.8=92; bar.9=94; bar.10=96

*--model name
  mdc.1=${expname[1]}
  if($nexp>=2); mdc.2=${expname[2]} ;endif
  if($nexp>=3); mdc.3=${expname[3]} ;endif
  if($nexp>=4); mdc.4=${expname[4]} ;endif
  if($nexp>=5); mdc.5=${expname[5]} ;endif
  if($nexp>=6); mdc.6=${expname[6]} ;endif
  if($nexp>=7); mdc.7=${expname[7]} ;endif
  if($nexp>=8); mdc.8=${expname[8]} ;endif
  if($nexp>=9); mdc.9=${expname[9]} ;endif
  if($nexp>=10); mdc.10=${expname[10]} ;endif

*--observation counts
  count=read(${area}f${fhe}.txt)
  outrec=sublin(count,2)
  nc.1=subwrd(outrec,1); nc.2=subwrd(outrec,2); nc.3=subwrd(outrec,3)
  nc.4=subwrd(outrec,4); nc.5=subwrd(outrec,5); nc.6=subwrd(outrec,6)
  nc.7=subwrd(outrec,7); nc.8=subwrd(outrec,8); nc.9=subwrd(outrec,9)
*------------------------------


  xwd=4.4; ywd=4.0; yy=ywd/15
  'set parea 0 11.0 0 8.4'                    
  'set string 1 bc 6'; 'set strsiz 0.17 0.17'
  'draw string 5.5 8.3 ${areac} Precip Skill Scores, fh${fh00}-fh${fhe}, $stymdc-$edymdc '
  'set string 1 bl 4'; 'set strsiz 0.11 0.11'
  'draw string 0.8 0.2 Differences outside of the hollow bars are 95% significant based on $ntest Monte Carlo Tests '

*---------------------------------------
*----first panel ETS--------------------
  xmin=0.8; xmax=xmin+xwd
  ymin=4.0; ymax=ymin+ywd
  yt=ymax-0.1; xt=xmin+0.6*xwd; xt1=xt+0.5; xt2=xt1+0.1
  'set parea 'xmin' 'xmax' 'ymin' 'ymax

  'set x 1 $ncat' 
  'set y 1 '

*--find maximum and minmum values to determine y-axis labels
 cmax=-1.0; cmin=1.0
 i=1
 while (i <= $nexp)
    'set gxout stat'
    'd ets(y='%i')'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 1); cmax=1; endif
 if(cmin < 0); cmin=0; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif

   i=1
   while (i <= $nexp)
   'set y 'i
      'set strsiz 0.15 0.15'; yt=yt-yy
      'set line 'cco.i' 'cst.i' 11'; 'draw line 'xt' 'yt' 'xt1' 'yt
      'set string 'cco.i' bl 6';  'draw string 'xt2' 'yt' 'mdc.i 

      'set gxout line'
      'set mproj off'
      'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
      'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
      'set vrange 0 'cmax; 'set ylint 0.1'
      'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
      'd ets(y='%i')'
   i=i+1
   endwhile
  'draw ylab Equitable Threat Score'

*--plot observed count
  'set string 4 bc 4'; 'set strsiz 0.09 0.09'
  j=1; while (j <= $ncat)
   xpos=xmin+(j-1)*xwd/8.0                   
   'draw string 'xpos' 'ymin+0.1' 'nc.j
   j=j+1
  endwhile

*---------------------------
* plot difference between others and the first
  ymin=ymin-3; ymax=ymin+3
  'set parea 'xmin' 'xmax' 'ymin' 'ymax
  xlabx=xmin+0.40*xwd;  xlaby=ymin-0.50
  xlabx1=xmin+0.51*xwd;  xlaby1=ymin-0.2                  

*--find maximum and minmum values to determine y-axis labels
 cmax=-1.0; cmin=1.0
 i=2
 while (i <= $nexp)
    'set gxout stat'
    'd ets(y='%i')-ets(y=1)'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
      'd 1.96*std_ets.2(y='%i')'
      range=sublin(result,9); zmax=subwrd(range,6); zmin=-zmax
      if(zmax > cmax); cmax=zmax; endif
      if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 1); cmax=1; endif
 if(cmin < -1); cmin=-1; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif
 
*---------------------------------------------------------
* standard deviation of the difference between the 
* first and each of the rest models for each category  

 i=2
 while (i <= $nexp)
** plot the 5% conf interval of difference of means : 1.96*std
   'define intvl=1.96*std_ets.2(y='%i')'
*  'define intvl=maskout( 1.96*std_ets.2(y='%i'), ets(y='%i') )'
   'set gxout bar'
   'set bargap 'bar.i
   'set baropts outline'
   'set ccolor 'cco.i
   'set cstyle 1'; 'set cthick 3'; 'set cmark 0'
   'set mproj off'
   'set display color white'; 'set grads off'; 'set grid on'
   'set xlopts 1 6 0.0';     'set ylopts 1 6 0.0'; 'set clopts 1 6 0.0'
   'set vrange 'cmin' 'cmax; 'set ylint 'cintp
   'd -intvl;intvl'
**add missing bars when intvl is larger than cmax
   'set ccolor 'cco.i
   'define xa=maskout(intvl*0+0.999*'cmin',intvl+'cmin')'
   'define xb=maskout(intvl*0+0.999*'cmax',intvl-'cmax')'
   'set datawarn off'
   'd xa;xb'
 i=i+1
 endwhile

 i=1
 while (i <= $nexp)
     'set gxout line'
     'set mproj off'
     'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
     'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
     'set vrange 'cmin' 'cmax; 'set ylint 'cintp
     'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
     if(i=1); 'set cstyle 1'; 'set cthick 1'; 'set cmark 0'; 'set ccolor 1'; endif
     'd ets(y='%i')-ets(y=1)'
 i=i+1
 endwhile

 'set string 1 bc 5'
 'set strsiz 0.15 0.15'
 'draw string 'xlabx' 'xlaby' Threshold (inch/day)'
 'set string 1 bl 6'
 'set strsiz 0.14 0.14'
 'draw string 'xmin+0.2' 'ymax-0.2' Difference w.r.t. '${expname[1]}
 'set string 1 bl 3'
 'set strsiz 0.11 0.11'

*--add marks of precip intensity categories
  pi.1=0${catpc[1]} ; pi.2=0${catpc[2]} ; pi.3=0${catpc[3]} 
  pi.4=0${catpc[4]} ; pi.5=0${catpc[5]} ; pi.6=${catpc[6]} 
  pi.7=${catpc[7]} ; pi.8=${catpc[8]} ; pi.9=${catpc[9]}
  if( $ncat >= 10 ); pi.10=${catpc[10]}; endif
  if( $ncat >= 11 ); pi.11=${catpc[11]}; endif
  if( $ncat >= 12 ); pi.12=${catpc[12]}; endif
  if( $ncat >= 13 ); pi.13=${catpc[13]}; endif
  if( $ncat >= 14 ); pi.14=${catpc[14]}; endif
  if( $ncat >= 15 ); pi.15=${catpc[15]}; endif
  'set string 1 bc 6'; 'set strsiz 0.12 0.12'
  j=1; while (j <= $ncat)
   xpos=xmin+(j-1)*xwd/8.0                   
   'draw string 'xpos' 'ymin-0.2' 'pi.j
   j=j+1
  endwhile




*---------------------------------------
*----2nd panel BIAS--------------------
  xmin=xmax+1.0; xmax=xmin+xwd
  ymin=4.0; ymax=ymin+ywd
  yt=ymax-0.1; xt=xmin+0.1*xwd; xt1=xt+0.5; xt2=xt1+0.1
  xlabx=xmin+0.45*xwd;  xlaby=ymin-0.50
  'set parea 'xmin' 'xmax' 'ymin' 'ymax

  'set x 1 $ncat' 
  'set y 1 '

*--find maximum and minmum values to determine y-axis labels
 cmax=-999.0; cmin=999.0
 i=1
 while (i <= $nexp)
    'set gxout stat'
    'd bis(y='%i')'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 3);   cmax=3; endif
 if(cmax < 2.0); cmax=2.0; endif
 if(cmin < 0.48); cmin=0.48; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif


   i=1
   while (i <= $nexp)
   'set y 'i
      'set strsiz 0.15 0.15'; yt=yt-yy
      'set line 'cco.i' 'cst.i' 11'; 'draw line 'xt' 'yt' 'xt1' 'yt
      'set string 'cco.i' bl 6';  'draw string 'xt2' 'yt' 'mdc.i 

      'set gxout line'
      'set mproj off'
      'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
      'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
*     'set vrange 'cmin' 'cmax; 'set ylint 'cintp
      'set vrange 0.5 'cmax; 'set ylint 0.5 '
      'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
      'd bis(y='%i')'
   i=i+1
   endwhile
  'draw ylab BIAS Score'

*--plot observed count
  'set string 4 bc 4'; 'set strsiz 0.09 0.09'
  j=1; while (j <= $ncat)
   xpos=xmin+(j-1)*xwd/8.0                   
   'draw string 'xpos' 'ymin+0.1' 'nc.j
   j=j+1
  endwhile

*---------------------------
* plot difference between others and the first
  ymin=ymin-3; ymax=ymin+3
  'set parea 'xmin' 'xmax' 'ymin' 'ymax
  xlabx=xmin+0.40*xwd;  xlaby=ymin-0.50
  xlabx1=xmin+0.51*xwd;  xlaby1=ymin-0.2                  

*--find maximum and minmum values to determine y-axis labels
 cmax=-99.0; cmin=99.0
 i=2
 while (i <= $nexp)
    'set gxout stat'
    'd bis(y='%i')-bis(y=1)'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
      'd 1.96*std_bis.2(y='%i')'
      range=sublin(result,9); zmax=subwrd(range,6); zmin=-zmax
      if(zmax > cmax); cmax=zmax; endif
      if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 1.5); cmax=1.5; endif
 if(cmin < -1.5); cmin=-1.5; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 dist=cmax-cmin 
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif

*---------------------------------------------------------
* standard deviation of the difference between the 
* first and each of the rest models for each category  

 i=2
 while (i <= $nexp)
**plot the 5% conf interval of difference of means : 1.96*std
   'define intvl=1.96*std_bis.2(y='%i')'
*  'define intvl=maskout( 1.96*std_bis.2(y='%i'), bis(y='%i') )'
   'set gxout bar'
   'set bargap 'bar.i
   'set baropts outline'
   'set ccolor 'cco.i
   'set cstyle 1'; 'set cthick 3'; 'set cmark 0'
   'set mproj off'
   'set display color white'; 'set grads off'; 'set grid on'
   'set xlopts 1 6 0.0';     'set ylopts 1 6 0.0'; 'set clopts 1 6 0.0'
   'set vrange 'cmin' 'cmax; 'set ylint 'cintp
   'd -intvl;intvl'
**add missing bars when intvl is larger than cmax
   'set ccolor 'cco.i
   'set datawarn off'
   'define xa=maskout(intvl*0+0.999*'cmin',intvl+'cmin')'
   'define xb=maskout(intvl*0+0.999*'cmax',intvl-'cmax')'
   'd xa;xb'
 i=i+1
 endwhile

 i=1
 while (i <= $nexp)
     'set gxout line'
     'set mproj off'
     'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
     'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
     'set vrange 'cmin' 'cmax; 'set ylint 'cintp
     'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
     if(i=1); 'set cstyle 1'; 'set cthick 1'; 'set cmark 0'; 'set ccolor 1'; endif
     'd bis(y='%i')-bis(y=1)'
 i=i+1
 endwhile

 'set string 1 bc 5'
 'set strsiz 0.15 0.15'
 'draw string 'xlabx' 'xlaby' Threshold (inch/day)'
 'set string 1 bl 6'
 'set strsiz 0.14 0.14'
 'draw string 'xmin+0.2' 'ymax-0.2' Difference w.r.t. '${expname[1]}
 'set string 1 bl 3'
 'set strsiz 0.11 0.11'

*--add marks of precip intensity categories
  'set string 1 bc 6'; 'set strsiz 0.12 0.12'
  j=1; while (j <= $ncat)
   xpos=xmin+(j-1)*xwd/8.0                   
   'draw string 'xpos' 'ymin-0.2' 'pi.j
   j=j+1
  endwhile

*----------------------------------------------
  'printim etsbis.${area}f${fhs}f${fhe}d${ndays}.png png x800 y600'
  'set vpage off'
'quit'
EOF1
grads -bcl "run etsbis.${area}f${fhs}f${fhe}.gs"
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#////////////////////////////////////////////////////////////




#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#/////////////////////////////////////////////////////////////////////
# PLOT 2:  ETS, BIAS and COUNT for each caterory as a function of time
ntplot=1
if [ $timeplot = "YES" ]; then ntplot=$ncat ;fi

set -A intrain none $catp                               
icat=1
while [ $icat -le $ntplot ]; do
intp=${intrain[$icat]}

cat >etsbis.${area}f${fhs}f${fhe}p${intp}.gs <<EOF1 
'reinit'; 'set font 1'
'open ${area}f${fhs}f${fhe}_daily.ctl'

*-- define line styles 
  cst.1=1; cst.2=1; cst.3=1; cst.4=1; cst.5=1; cst.6=1; cst.7=1; cst.8=1; cst.9=1; cst.10=1
  cth.1=12; cth.2=12; cth.3=9; cth.4=9; cth.5=9; cth.6=9; cth.7=9; cth.8=9; cth.9=9; cth.10=9
  cma.1=2; cma.2=3; cma.3=6; cma.4=8; cma.5=7; cma.6=5; cma.7=4; cma.8=1; cma.9=9; cma.10=10
  cco.1=1; cco.2=2; cco.3=3; cco.4=4; cco.5=8; cco.6=9; cco.7=5; cco.8=6; cco.9=7; cco.10=15
  bar.1=30; bar.2=40; bar.3=50; bar.4=60; bar.5=70; bar.6=80; bar.7=90; bar.8=92; bar.9=94; bar.10=96

*--model name
  mdc.1=${expname[1]}
  if($nexp>=2); mdc.2=${expname[2]} ;endif
  if($nexp>=3); mdc.3=${expname[3]} ;endif
  if($nexp>=4); mdc.4=${expname[4]} ;endif
  if($nexp>=5); mdc.5=${expname[5]} ;endif
  if($nexp>=6); mdc.6=${expname[6]} ;endif
  if($nexp>=7); mdc.7=${expname[7]} ;endif
  if($nexp>=8); mdc.8=${expname[8]} ;endif
  if($nexp>=9); mdc.9=${expname[9]} ;endif
  if($nexp>=10); mdc.10=${expname[10]} ;endif

*------------------------------
  xwd=7.0; ywd=3.0; yy=ywd/15
  'set parea 0 8.5 0 11'                    
  'set string 1 bc 6'; 'set strsiz 0.15 0.15'
  'draw string 4.3 10.7 ${areac} Precip Skill Scores, $stymdc-$edymdc '
  'draw string 4.3 10.4 fh${fh00}-fh${fhe}, Threshold >= $intp inch/day  '

*----first/top panel ETS--------------------
  xmin=1.0; xmax=xmin+xwd
  ymin=7.0; ymax=ymin+ywd
  yt=ymax-0.1; xt=xmin+0.1*xwd; xt1=xt+0.5; xt2=xt1+0.1
  'set parea 'xmin' 'xmax' 'ymin' 'ymax

  'set x $icat' 
  'set t 1 $ndays' 
  'set y 1 '

*--find maximum and minmum values to determine y-axis labels
 cmax=-1.0; cmin=1.0
 i=1
 while (i <= $nexp)
    'set gxout stat'
    'd ets(y='%i')'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 1); cmax=1; endif
 if(cmin < 0); cmin=0; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif

   i=1
   while (i <= $nexp)
   'set y 'i
      'set strsiz 0.15 0.15'; yt=yt-yy
      'set line 'cco.i' 'cst.i' 11'; 'draw line 'xt' 'yt' 'xt1' 'yt
      'set string 'cco.i' bl 6';  'draw string 'xt2' 'yt' 'mdc.i 

      'set gxout line'
      'set mproj off'
      'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
      'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
      'set vrange 'cmin ' 'cmax; 'set ylint 0.1'
      'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
      'd ets(y='%i')'
   i=i+1
   endwhile
  'draw ylab ET Score'


*----2nd/middle panel BIAS--------------------
  xmin=1.0; xmax=xmin+xwd
  ymin=3.8; ymax=ymin+ywd
  yt=ymax-0.1; xt=xmin+0.1*xwd; xt1=xt+0.5; xt2=xt1+0.1
  'set parea 'xmin' 'xmax' 'ymin' 'ymax

  'set x $icat' 
  'set t 1 $ndays' 
  'set y 1 '

*--find maximum and minmum values to determine y-axis labels
 cmax=-999.0; cmin=999.0
 i=1
 while (i <= $nexp)
    'set gxout stat'
    'd bis(y='%i')'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,6); cmax=substr(cmax,1,6)
 if(cmax > 3); cmax=3; endif
 if(cmin < 0); cmin=0; endif
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif

   i=1
   while (i <= $nexp)
   'set y 'i
      'set strsiz 0.15 0.15'; yt=yt-yy
      'set line 'cco.i' 'cst.i' 11'; 'draw line 'xt' 'yt' 'xt1' 'yt
      'set string 'cco.i' bl 6';  'draw string 'xt2' 'yt' 'mdc.i 

      'set gxout line'
      'set mproj off'
      'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
      'set xlopts 1 6 0.0';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
      'set vrange 'cmin' 'cmax; 'set ylint 0.5'
      'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
      'd bis(y='%i')'
   i=i+1
   endwhile
  'draw ylab BIAS Score'


*----3rd/bottom panel OBS Count--------------------
  xmin=1.0; xmax=xmin+xwd
  ymin=0.6; ymax=ymin+ywd
  yt=ymax-0.1; xt=xmin+0.1*xwd; xt1=xt+0.5; xt2=xt1+0.1
  'set parea 'xmin' 'xmax' 'ymin' 'ymax

  'set x $icat' 
  'set t 1 $ndays' 
  'set y 1 '

*--find maximum and minmum values to determine y-axis labels
 cmax=-999.0; cmin=999.0
 i=1
 while (i <= $nexp)
    'set gxout stat'
    'd obs(y='%i')'
    range=sublin(result,9); zmin=subwrd(range,5); zmax=subwrd(range,6)
    if(zmax > cmax); cmax=zmax; endif
    if(zmin < cmin); cmin=zmin; endif
 i=i+1
 endwhile
 cmin=substr(cmin,1,7); cmax=substr(cmax,1,7)
 dist=cmax-cmin 
 if (dist = 0); dist=1; endif
 cintp=10*substr(dist/40,1,4)
 if (cintp = 0); cintp=10*substr(dist/40,1,5); endif
 if (cintp = 0); cintp=10*substr(dist/40,1,6); endif

   i=1
*  while (i <= $nexp)
   'set y 'i
      'set strsiz 0.15 0.15'; yt=yt-yy
      'set line 'cco.i' 'cst.i' 11'; 'draw line 'xt' 'yt' 'xt1' 'yt
      'set string 'cco.i' bl 6';  'draw string 'xt2' 'yt' 'mdc.i 

      'set gxout line'
      'set mproj off'
      'set display color white'; 'set missconn off';     'set grads off'; 'set grid on'
      'set xlopts 1 6 0.12';     'set ylopts 1 6 0.14'; 'set clopts 1 6 0.0'
      'set vrange 0 'cmax; 'set ylint 'cintp
      'set cstyle 'cst.i; 'set cthick 'cth.i; 'set cmark 'cma.i; 'set ccolor 'cco.i
      'd obs(y='%i')'
*  i=i+1
*  endwhile
  'draw ylab OBS Count'

*----------------------------------------------
  'printim etsbis.${area}f${fhs}f${fhe}p${intp}d${ndays}.png x600 y800'
  'set vpage off'
'quit'
EOF1
grads -bcp "run etsbis.${area}f${fhs}f${fhe}p${intp}.gs"

icat=`expr $icat + 1 `
done
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#////////////////////////////////////////////////////////////

cp -p *png  $mapdir/.
cat << EOF >ftpin
  promt
  cd $ftpdir
  mput *png                        
  quit
EOF
if [ $doftp = "YES" -a $CUE2RUN = $CUE2FTP ]; then
 sftp  ${webhostid}@${webhost} <ftpin 
 if [ $? -ne 0 ]; then scp -p *png ${webhostid}@${webhost}:$ftpdir/. ;fi
fi

# make archive at the end of each month
 file_local=etsbis.${area}f${fhs}f${fhe}d${ndays}.png
 file_arch=etsbis.${area}f${fhs}f${fhe}d${ndays}.${edymd}.png
if [ $archmon = "YES" -a $doftp = "YES" -a $CUE2RUN = $CUE2FTP ]; then
 scp -pq $file_local ${webhostid}@${webhost}:$ftpdir/arch/$file_arch 
fi



#--------------------------------------------
##--send plots to web server using dedicated
##--transfer node (required by NCEP WCOSS)
if [ $doftp = "YES" -a $CUE2RUN != $CUE2FTP ]; then
#--------------------------------------------
cd $mapdir
cat << EOF >ftprain.sh
#!/bin/ksh
set -x
  scp -Bp *png ${webhostid}@${webhost}:$ftpdir/.
  if [ $archmon = "YES" ]; then
    scp -Bp $file_local ${webhostid}@${webhost}:$ftpdir/arch/$file_arch 
  fi
EOF
  chmod u+x $mapdir/ftprain.sh
  $SUBJOB -a $ACCOUNT -q $CUE2FTP -g $GROUP -p 1/1/S -t 0:30:00 -r 256/1 -j ftprain -o ftprain.out $mapdir/ftprain.sh
#--------------------------------------------
fi
#--------------------------------------------

exit
