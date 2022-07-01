#!/bin/sh

set -xe

NCP=${NCP:-'/bin/cp'}
NLN=${NLN:-'/bin/ln -sf'}
NDATE=${NDATE:-ndate}

TOTAL_TASKS=${TOTAL_TASKS:-2016}
NCTSK=${NCTSK:-12}
NCNODE=${NCNODE:-24}
OMP_NUM_THREADS=${OMP_NUM_THREADS:-2}
OMP_STACKSIZE=${OMP_STACKSIZE:-2048m}
APRUNC=${APRUNC:-"aprun -b -j1 -n${TOTAL_TASKS} -N${NCTSK} -d${OMP_NUM_THREADS} -cc depth"}
export APRUN=time

CDATE=${CDATE:-${YMDH}}
cyc=${cyc:-00}
STORM=${STORM:-FAKE}
STORMID=${STORMID:-00L}

export CASE=${CASE:-C768}
export CRES=`echo $CASE | cut -c 2-`
export gtype=${gtype:-regional}
export gridfixdir=${gridfixdir:-'/let/hafs_grid/generate/grid'}
export LEVS=${LEVS:-65}
export istart_nest=${istart_nest:-46}
export jstart_nest=${jstart_nest:-238}
export iend_nest=${iend_nest:-1485}
export jend_nest=${jend_nest:-1287}
export stretch_fac=${stretch_fac:-1.0001}
export target_lon=${target_lon:--62.0}
export target_lat=${target_lat:-22.0}
export refine_ratio=${refine_ratio:-4}
export res=${res:-$CRES}
export halo=${halo:-3}
export halop1=${halop1:-4}
export halo0=${halo0:-0}
export NTRAC=7

export FIXam=${FIXhafs}/fix_am
export FIXorog=${FIXhafs}/fix_orog
export FIXfv3=${FIXhafs}/fix_fv3
export FIXsfc_climo=${FIXhafs}/fix_sfc_climo

export MAKEHGRIDEXEC=${EXEChafs}/hafs_make_hgrid.x
export MAKEMOSAICEXEC=${EXEChafs}/hafs_make_solo_mosaic.x
export FILTERTOPOEXEC=${EXEChafs}/hafs_filter_topo.x
export FREGRIDEXEC=${EXEChafs}/hafs_fregrid.x
export OROGEXEC=${EXEChafs}/hafs_orog.x
export SHAVEEXEC=${EXEChafs}/hafs_shave.x
export SFCCLIMOEXEC=${EXEChafs}/hafs_sfc_climo_gen.x

export MAKEGRIDSSH=${USHhafs}/hafs_make_grid.sh
export MAKEOROGSSH=${USHhafs}/hafs_make_orog.sh
export FILTERTOPOSSH=${USHhafs}/hafs_filter_topo.sh
export STORMCENTERPY=${USHhafs}/GFDLgrid-stormcenter.py

export gridfixdir=${gridfixdir:-'/let/hafs_grid/generate/grid'}
export script_dir=${USHhafs}
export exec_dir=${EXEChafs}
export out_dir=${OUTDIR:-${WORKhafs}/intercom/grid}
export DATA=${DATA:-${WORKhafs}/atm_prep}

# If gridfixdir is specified and exists, use the grid fix files directly
if [ -d $gridfixdir ]; then
  echo "$gridfixdir is specified and exists."
  echo "Copy the grid fix files directly."
  cp -r $gridfixdir/* ${out_dir}/
  ls ${out_dir}
  exit
fi

# Otherwise, generate grid according to the following parameters
#----------------------------------------------------------------
if [ $gtype = uniform ];  then
  echo "creating uniform ICs"
elif [ $gtype = stretch ]; then
  export stretch_fac=${stretch_fac:-1.5}      # Stretching factor for the grid
  export target_lon=${target_lon:--97.5}      # center longitude of the highest resolution tile
  export target_lat=${target_lat:-35.5}       # center latitude of the highest resolution tile
  echo "creating stretched grid"
elif [ $gtype = nest -o $gtype = regional ]; then
  export stretch_fac=${stretch_fac:-1.0001}   # Stretching factor for the grid
  export target_lon=${target_lon:--62.0}      # center longitude of the highest resolution tile
  export target_lat=${target_lat:-22.0}       # center latitude of the highest resolution tile

  export nest_grids=${nest_grids:-1}
  export parent_tile=${parent_tile:-6}
  export refine_ratio=${refine_ratio:-4}
  export istart_nest=${istart_nest:-46}
  export jstart_nest=${jstart_nest:-238}
  export iend_nest=${iend_nest:-1485}
  export jend_nest=${jend_nest:-1287}

  export halo=${halo:-3}                      # halo size to be used in the atmosphere cubic sphere model for the grid tile.
  export halop1=${halop1:-4}                  # halo size that will be used for the orography and grid tile in chgres
  export halo0=${halo0:-0}                    # no halo, used to shave the filtered orography for use in the model

  echo "creating grid for gtype of $gtype"
else
  echo "Error: please specify grid type with 'gtype' as uniform, stretch, nest or regional"
  exit 1
fi


#----------------------------------------------------------------
#----------------------------------------------------------------
#----------------------------------------------------------------
# MAKE GRID AND OROGRAPHY

export grid_dir=$DATA/grid
export orog_dir=$DATA/orog
if [ $gtype = uniform ] || [ $gtype = stretch ] ;  then
  export filter_dir=$DATA/filter_topo
elif [ $gtype = nest ] || [ $gtype = regional ] ;  then
  export filter_dir=$DATA/filter_topo
  export filter_dir=$orog_dir   # nested grid topography will be filtered online
fi
mkdir -p $grid_dir $orog_dir $filter_dir


#----------------------------------------------------------------
#----------------------------------------------------------------
# uniform or stretched global grid
if [ $gtype = uniform ] || [ $gtype = stretch ] ;  then
  export ntiles=6
  date
  echo "............ execute $MAKEGRIDSSH ................."
  if [ $gtype = uniform ];  then
    ${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $script_dir
  elif [ $gtype = stretch ]; then
    ${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat $script_dir
  fi
  date
  echo "............ execute $MAKEOROGSSH ................."
  # Run multiple tiles simulatneously for the orography

  echo "${APRUNO} $MAKEOROGSSH $CRES 1 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 2 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 3 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 4 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 5 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 6 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
if [ "$machine" = hera ] || [ "$machine" = orion ] || [ "$machine" = jet ]; then
  echo 'wait' >> orog.file1
fi
  chmod u+x $DATA/orog.file1
  #aprun -j 1 -n 4 -N 4 -d 6 -cc depth cfp $DATA/orog.file1
  ${APRUNF} $DATA/orog.file1
  wait
  #rm $DATA/orog.file1
  date
  echo "............ execute $FILTERTOPOSSH .............."
  $FILTERTOPOSSH $CRES $grid_dir $orog_dir $filter_dir
  echo "Grid and orography files are now prepared"


#----------------------------------------------------------------
#----------------------------------------------------------------
# nested grid
elif [ $gtype = nest ]; then
  export ntiles=$((6 + ${nest_grids}))
  date
  echo "............ execute $MAKEGRIDSSH ................."
  #${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat $refine_ratio $istart_nest $jstart_nest $iend_nest $jend_nest $halo $script_dir
  ${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat \
       $nest_grids \
       "$parent_tile" \
       "$refine_ratio" \
       "$istart_nest" \
       "$jstart_nest" \
       "$iend_nest" \
       "$jend_nest" \
       $halo $script_dir
  date
  echo "............ execute $MAKEOROGSSH ................."
  # Run multiple tiles simulatneously for the orography
  echo "${APRUNO} $MAKEOROGSSH $CRES 1 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >$DATA/orog.file1
  for itile in $(seq 2 $ntiles)
  do 
    echo "${APRUNO} $MAKEOROGSSH $CRES ${itile} $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
  done
if [ "$machine" = hera ] || [ "$machine" = orion ] || [ "$machine" = jet ]; then
  echo 'wait' >> orog.file1
fi
  chmod u+x $DATA/orog.file1
  #aprun -j 1 -n 4 -N 4 -d 6 -cc depth cfp $DATA/orog.file1
  ${APRUNF} $DATA/orog.file1
  wait
  #rm $DATA/orog.file1
  date
  echo "Grid and orography files are now prepared"


#----------------------------------------------------------------
#----------------------------------------------------------------
# regional grid with nests
#elif [ $gtype = regional ] && [ ${nest_grids} -gt 1 ]; then
elif [ "${gtype}" == "regional" ]; then

  #----------------------------------------------------------------
  # Create Tile 7 (parent domain) halo.
  echo "............ Creating/preparing the halo for Tile 7 .............."
  export ntiles=1
  tile=7

  # Tile 7 grid locations and refinement ratio
  iend_nest_t7=`echo $iend_nest | cut -d , -f 1`
  istart_nest_t7=`echo $istart_nest | cut -d , -f 1`
  jend_nest_t7=`echo $jend_nest | cut -d , -f 1`
  jstart_nest_t7=`echo $jstart_nest | cut -d , -f 1`
  refine_ratio_t7=`echo $refine_ratio | cut -d , -f 1`

  # number of Tile 7 grid points
  nptsx=`expr $iend_nest_t7 - $istart_nest_t7 + 1`
  nptsy=`expr $jend_nest_t7 - $jstart_nest_t7 + 1`

  # number of compute grid points
  npts_cgx=`expr $nptsx  \* $refine_ratio_t7 / 2`
  npts_cgy=`expr $nptsy  \* $refine_ratio_t7 / 2`
 
  # figure out how many columns/rows to add in each direction so we have at least 5 halo points
  # for make_hgrid and the orography program
  index=0
  add_subtract_value=0
  while (test "$index" -le "0")
  do
    add_subtract_value=`expr $add_subtract_value + 1`
    iend_nest_halo=`expr $iend_nest_t7 + $add_subtract_value`
    istart_nest_halo=`expr $istart_nest_t7 - $add_subtract_value`
    newpoints_i=`expr $iend_nest_halo - $istart_nest_halo + 1`
    newpoints_cg_i=`expr $newpoints_i  \* $refine_ratio_t7 / 2`
    diff=`expr $newpoints_cg_i - $npts_cgx`
    if [ $diff -ge 10 ]; then 
      index=`expr $index + 1`
    fi
  done
  jend_nest_halo=`expr $jend_nest_t7 + $add_subtract_value`
  jstart_nest_halo=`expr $jstart_nest_t7 - $add_subtract_value`

  echo "================================================================================== "
  echo "For refine_ratio= $refine_ratio_t7" 
  echo " iend_nest= $iend_nest_t7 iend_nest_halo= $iend_nest_halo istart_nest= $istart_nest_t7 istart_nest_halo= $istart_nest_halo"
  echo " jend_nest= $jend_nest_t7 jend_nest_halo= $jend_nest_halo jstart_nest= $jstart_nest_t7 jstart_nest_halo= $jstart_nest_halo"
  echo "================================================================================== "

  echo "............ execute $MAKEGRIDSSH ................."
  ${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat $refine_ratio $istart_nest_halo $jstart_nest_halo $iend_nest_halo $jend_nest_halo $halo $script_dir

  date
  echo "............ execute $MAKEOROGSSH ................."
  #echo "$MAKEOROGSSH $CRES 7 $grid_dir $orog_dir $script_dir $FIXorog $DATA " >$DATA/orog.file1
  echo "${APRUNO} $MAKEOROGSSH $CRES 7 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >$DATA/orog.file1
if [ "$machine" = hera ] || [ "$machine" = orion ] || [ "$machine" = jet ]; then
  echo 'wait' >> orog.file1
fi
  chmod u+x $DATA/orog.file1
  #aprun -j 1 -n 4 -N 4 -d 6 -cc depth cfp $DATA/orog.file1
  ${APRUNF} $DATA/orog.file1
  wait
  #rm $DATA/orog.file1

  date
  echo "............ execute $FILTERTOPOSSH .............."
  ${APRUNS} $FILTERTOPOSSH $CRES $grid_dir $orog_dir $filter_dir

  echo "............ execute shave to reduce grid and orography files to required compute size .............."
  cd $filter_dir
  # shave the orography file and then the grid file, the echo creates the input file that contains the number of required points
  # in x and y and the input and output file names.This first run of shave uses a halo of 4. This is necessary so that chgres will create BC's 
  # with 4 rows/columns which is necessary for pt.
  echo $npts_cgx $npts_cgy $halop1 \'$filter_dir/oro.${CASE}.tile${tile}.nc\' \'$filter_dir/oro.${CASE}.tile${tile}.shave.nc\' >input.shave.orog
  echo $npts_cgx $npts_cgy $halop1 \'$filter_dir/${CASE}_grid.tile${tile}.nc\' \'$filter_dir/${CASE}_grid.tile${tile}.shave.nc\' >input.shave.grid

  #aprun -n 1 -N 1 -j 1 -d 1 -cc depth $exec_dir/shave.x <input.shave.orog
  #aprun -n 1 -N 1 -j 1 -d 1 -cc depth $exec_dir/shave.x <input.shave.grid
  ${APRUNS} ${SHAVEEXEC} < input.shave.orog
  ${APRUNS} ${SHAVEEXEC} < input.shave.grid

  # Copy the shaved files with the halo of 4
  cp $filter_dir/oro.${CASE}.tile${tile}.shave.nc $out_dir/${CASE}_oro_data.tile${tile}.halo${halop1}.nc
  cp $filter_dir/${CASE}_grid.tile${tile}.shave.nc  $out_dir/${CASE}_grid.tile${tile}.halo${halop1}.nc

  # Now shave the orography file with no halo and then the grid file with a halo of 3. This is necessary for running the model.
  echo $npts_cgx $npts_cgy $halo \'$filter_dir/oro.${CASE}.tile${tile}.nc\' \'$filter_dir/oro.${CASE}.tile${tile}.shave.nc\' >input.shave.orog.halo${halo}
  echo $npts_cgx $npts_cgy $halo \'$filter_dir/${CASE}_grid.tile${tile}.nc\' \'$filter_dir/${CASE}_grid.tile${tile}.shave.nc\' >input.shave.grid.halo${halo}
  ${APRUNS} ${SHAVEEXEC} < input.shave.orog.halo${halo}
  ${APRUNS} ${SHAVEEXEC} < input.shave.grid.halo${halo}

  # Copy the shaved files with the halo of 3
  cp $filter_dir/oro.${CASE}.tile${tile}.shave.nc $out_dir/${CASE}_oro_data.tile${tile}.halo${halo}.nc
  cp $filter_dir/${CASE}_grid.tile${tile}.shave.nc  $out_dir/${CASE}_grid.tile${tile}.halo${halo}.nc

  # Now shave the orography file and then the grid file with a halo of 0. This is handy for running chgres.
  echo $npts_cgx $npts_cgy $halo0 \'$filter_dir/oro.${CASE}.tile${tile}.nc\' \'$filter_dir/oro.${CASE}.tile${tile}.shave.nc\' >input.shave.orog.halo${halo0}
  echo $npts_cgx $npts_cgy $halo0 \'$filter_dir/${CASE}_grid.tile${tile}.nc\' \'$filter_dir/${CASE}_grid.tile${tile}.shave.nc\' >input.shave.grid.halo${halo0}

  ${APRUNS} ${SHAVEEXEC} < input.shave.orog.halo${halo0}
  ${APRUNS} ${SHAVEEXEC} < input.shave.grid.halo${halo0}

  # Copy the shaved files with the halo of 0
  cp $filter_dir/oro.${CASE}.tile${tile}.shave.nc $out_dir/${CASE}_oro_data.tile${tile}.halo${halo0}.nc
  cp $filter_dir/${CASE}_grid.tile${tile}.shave.nc  $out_dir/${CASE}_grid.tile${tile}.halo${halo0}.nc

  echo "Grid and orography files are now prepared"
  echo "............ Finished preparing Tile 7 halo ................."
  #----------------------------------------------------------------


  #----------------------------------------------------------------
  # If necessary, update i/j locations for Tile 8

  # Check if Tile 8 i/j locations should be computed here
  istart_nest_t8=`echo $istart_nest | cut -d , -f 2`
  iend_nest_t8=`echo $iend_nest | cut -d , -f 2`
  jstart_nest_t8=`echo $jstart_nest | cut -d , -f 2`
  jend_nest_t8=`echo $jend_nest | cut -d , -f 2`

  if [ "${istart_nest_t8}" == "-999" ] || [ "${iend_nest_t8}" == "-999" ] || \
     [ "${jstart_nest_t8}" == "-999" ] || [ "${jend_nest_t8}" == "-999" ]; then

    # Find i/j for the TC center
    GRIDFILE="${out_dir}/${CASE}_grid.tile${tile}.halo${halo0}.nc"
    STORMCENTEROUT="${WORKhafs}/atm_prep/gfdlcentergr.txt"
    TMPVIT="${WORKhafs}/tmpvit"

    source /work2/noaa/aoml-hafs1/galaka/gus-toolbox/conda/load_conda.miniconda3_v397.GPLOT_20220614.sh

    python3 ${STORMCENTERPY} ${STORMID} ${CDATE} ${GRIDFILE} ${TMPVIT} ${STORMCENTEROUT}
    if [ ! -f ${STORMCENTEROUT} ]; then
        echo "ERROR! Could not find the storm center file --> ${STORMCENTEROUT}. Can't proceed."
        exit 1
    fi

    # Read i/j for the TC center
    npx_t7="`echo ${npx} | cut -d',' -f1`"
    icen_nest_t8="`cat ${STORMCENTEROUT} | awk '{$1=$1};1' | cut -d' ' -f1`"
    #icen_nest_t8_sw=$(( ( 2 * npx_t7 ) + 1 - icen_nest_t8))

    npy_t7="`echo ${npy} | cut -d',' -f1`"
    jcen_nest_t8="`cat ${STORMCENTEROUT} | awk '{$1=$1};1' | cut -d' ' -f2`"
    #jcen_nest_t8_sw=$(( ( 2 * npy_t7 ) + 1 - jcen_nest_t8))

    refine_ratio_t8=`echo $refine_ratio | cut -d , -f 2`

    # Calculate istart/iend    
    npx_t8="`echo ${npx} | cut -d',' -f2`"
    ispan=$(( ( npx_t8 - 1 ) * 2 / refine_ratio_t8 ))
    istart_nest_t8=$(( icen_nest_t8 - ( ispan / 2 ) ))
    iend_nest_t8=$(( icen_nest_t8 + ( ispan / 2 ) ))
    if [ $((iend_nest_t8 - istart_nest_t8)) -ne $((ispan-1)) ]; then
        istart_nest_t8=$((istart_nest_t8 + ( iend_nest_t8 - istart_nest_t8 - ispan ) ))
    fi
    if [ $((istart_nest_t8%2)) -eq 0 ]; then
        istart_nest_t8=$(( istart_nest_t8 + 1))
    fi
    if [ $((iend_nest_t8%2)) -eq 1 ]; then
        iend_nest_t8=$(( iend_nest_t8 + 1))
    fi
    #istart_nest_t8_sw=$(( icen_nest_t8_sw - ( ispan / 2 ) ))
    #iend_nest_t8_sw=$(( icen_nest_t8_sw + ( ispan / 2 ) ))
    #if [ $((iend_nest_t8_sw - istart_nest_t8_sw)) -ne $((ispan-1)) ]; then
    #    istart_nest_t8_sw=$((istart_nest_t8_sw + ( iend_nest_t8_sw - istart_nest_t8_sw - ispan ) ))
    #fi
    #if [ $((istart_nest_t8_sw%2)) -eq 0 ]; then
    #    istart_nest_t8_sw=$(( istart_nest_t8_sw + 1))
    #fi
    #if [ $((iend_nest_t8_sw%2)) -eq 1 ]; then
    #    iend_nest_t8_sw=$(( iend_nest_t8_sw + 1))
    #fi

    # Calculate jstart/jend
    npy_t8="`echo ${npy} | cut -d',' -f2`"
    jspan=$(( ( npy_t8 - 1 ) * 2 / refine_ratio_t8 ))
    jstart_nest_t8=$(( jcen_nest_t8 - ( jspan / 2 ) ))
    jend_nest_t8=$(( jcen_nest_t8 + ( jspan / 2 ) ))
    if [ $((jend_nest_t8 - jstart_nest_t8)) -ne $((jspan-1)) ]; then
        jstart_nest_t8=$((jstart_nest_t8 + ( jend_nest_t8 - jstart_nest_t8 - jspan ) ))
    fi
    if [ $((jstart_nest_t8%2)) -eq 0 ]; then
        jstart_nest_t8=$(( jstart_nest_t8 + 1))
    fi
    if [ $((jend_nest_t8%2)) -eq 1 ]; then
        jend_nest_t8=$(( jend_nest_t8 + 1))
    fi
    #jstart_nest_t8_sw=$(( jcen_nest_t8_sw - ( jspan / 2 ) ))
    #jend_nest_t8_sw=$(( jcen_nest_t8_sw + ( jspan / 2 ) ))
    #if [ $((jend_nest_t8_sw - jstart_nest_t8_sw)) -ne $((jspan-1)) ]; then
    #    jstart_nest_t8_sw=$((jstart_nest_t8_sw + ( jend_nest_t8_sw - jstart_nest_t8_sw - jspan ) ))
    #fi
    #if [ $((jstart_nest_t8_sw%2)) -eq 0 ]; then
    #    jstart_nest_t8_sw=$(( jstart_nest_t8_sw + 1))
    #fi
    #if [ $((jend_nest_t8_sw%2)) -eq 1 ]; then
    #    jend_nest_t8_sw=$(( jend_nest_t8_sw + 1))
    #fi

    # Update comma-separated i/j variables
    istart_nest="`echo ${istart_nest} | cut -d',' -f1`,${istart_nest_t8}"
    iend_nest="`echo ${iend_nest} | cut -d',' -f1`,${iend_nest_t8}"
    jstart_nest="`echo ${jstart_nest} | cut -d',' -f1`,${jstart_nest_t8}"
    jend_nest="`echo ${jend_nest} | cut -d',' -f1`,${jend_nest_t8}"
    #istart_nest_sw="`echo ${istart_nest} | cut -d',' -f1`,${istart_nest_t8_sw}"
    #iend_nest_sw="`echo ${iend_nest} | cut -d',' -f1`,${iend_nest_t8_sw}"
    #jstart_nest_sw="`echo ${jstart_nest} | cut -d',' -f1`,${jstart_nest_t8_sw}"
    #jend_nest_sw="`echo ${jend_nest} | cut -d',' -f1`,${jend_nest_t8_sw}"

    # Update storm1.conf and storm1.holdvars.txt for future tasks
    sed -i -e 's/^istart_nest = [0-9]\{3,4\},-999$/istart_nest = '${istart_nest}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^iend_nest = [0-9]\{3,4\},-999$/iend_nest = '${iend_nest}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^jstart_nest = [0-9]\{3,4\},-999$/jstart_nest = '${jstart_nest}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^jend_nest = [0-9]\{3,4\},-999$/jend_nest = '${jend_nest}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^export istart_nest=[0-9]\{3,4\},-999$/export istart_nest='${istart_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export iend_nest=[0-9]\{3,4\},-999$/export iend_nest='${iend_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export jstart_nest=[0-9]\{3,4\},-999$/export jstart_nest='${jstart_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export jend_nest=[0-9]\{3,4\},-999$/export jend_nest='${jend_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export istart_nest_ens=[0-9]\{3,4\},-999$/export istart_nest_ens='${istart_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export iend_nest_ens=[0-9]\{3,4\},-999$/export iend_nest_ens='${iend_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export jstart_nest_ens=[0-9]\{3,4\},-999$/export jstart_nest_ens='${jstart_nest}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^export jend_nest_ens=[0-9]\{3,4\},-999$/export jend_nest_ens='${jend_nest}'/g' ${COMhafs}/storm1.holdvars.txt

    # Get storm center from vitals and update storm1.conf/storm1.holdvars.txt for future tasks
    tclat=echo "`awk '{print $6}' ${WORKhafs}/tmpvit | rev | cut -c2- | rev` / 10" | bc -l | xargs printf "%.1f\n"
    if [ "$(awk '{print $6}' ${WORKhafs}/tmpvit | rev | cut -c1)" == "S" ]; then
        tclat=$(( tclat * -1 ))
    fi
    tclon=echo "`awk '{print $7}' ${WORKhafs}/tmpvit | rev | cut -c2- | rev` / 10" | bc -l | xargs printf "%.1f\n"
    if [ "$(awk '{print $7}' ${WORKhafs}/tmpvit | rev | cut -c1)" == "W" ]; then
        tclon=$(( tclon * -1 ))
    fi
    sed -i -e 's/^output_grid_cen_lon = {domlon},*$/output_grid_cen_lon = {domlon},'${tclon}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^output_grid_cen_lat = {domlat},*$/output_grid_cen_lat = {domlat},'${tclat}'/g' ${COMhafs}/storm1.conf
    sed -i -e 's/^output_grid_cen_lon=*,*$/output_grid_cen_lon='${target_lon}','${tclon}'/g' ${COMhafs}/storm1.holdvars.txt
    sed -i -e 's/^output_grid_cen_lat=*,*$/output_grid_cen_lat='${target_lat}','${tclat}'/g' ${COMhafs}/storm1.holdvars.txt

  fi
  #----------------------------------------------------------------


  #----------------------------------------------------------------
  # Create Tile 7 and Tile 8
  if [ ${nest_grids} -gt 1 ]; then
    export ntiles=$((6 + ${nest_grids}))

    echo "================================================================================== "
    echo "For refine_ratio= $refine_ratio"
    echo " iend_nest= $iend_nest istart_nest= $istart_nest"
    echo " jend_nest= $jend_nest jstart_nest= $jstart_nest"
    echo "================================================================================== "
 
    echo "............ execute $MAKEGRIDSSH ................."
    #${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat $refine_ratio $istart_nest $jstart_nest $iend_nest $jend_nest $halo $script_dir
    ${APRUNS} $MAKEGRIDSSH $CRES $grid_dir $stretch_fac $target_lon $target_lat \
         $nest_grids \
         "$parent_tile" \
         "$refine_ratio" \
         "$istart_nest" \
         "$jstart_nest" \
         "$iend_nest" \
         "$jend_nest" \
         $halo $script_dir
    date
    echo "............ execute $MAKEOROGSSH ................."
    # Run multiple tiles simulatneously for the orography
    echo "${APRUNO} $MAKEOROGSSH $CRES 7 $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >$DATA/orog.file1
    for itile in $(seq 8 $ntiles)
    do
      echo "${APRUNO} $MAKEOROGSSH $CRES ${itile} $grid_dir $orog_dir $script_dir $FIXorog $DATA ${BACKGROUND}" >>$DATA/orog.file1
    done
    if [ "$machine" = hera ] || [ "$machine" = orion ] || [ "$machine" = jet ]; then
      echo 'wait' >> ${DATA}/orog.file1
    fi
    chmod u+x $DATA/orog.file1
    #aprun -j 1 -n 4 -N 4 -d 6 -cc depth cfp $DATA/orog.file1
    ${APRUNF} $DATA/orog.file1
    wait
    #rm $DATA/orog.file1
    date
    echo "Grid and orography files are now prepared"
  
  fi
  #----------------------------------------------------------------

fi

# Copy mosaic file(s) to output directory.
cp $grid_dir/${CASE}_*mosaic.nc $out_dir/

# For non-regional grids, copy grid and orography files to output directory.
if [ $gtype = uniform -o $gtype = stretch -o $gtype = nest ]; then
  echo "Copy grid and orography files to output directory"
  tile=1
  ntiles=`expr ${nest_grids} + 6`
  while [ $tile -le $ntiles ]; do
    cp $filter_dir/oro.${CASE}.tile${tile}.nc $out_dir/${CASE}_oro_data.tile${tile}.nc
    cp $grid_dir/${CASE}_grid.tile${tile}.nc  $out_dir/${CASE}_grid.tile${tile}.nc
    tile=`expr $tile + 1 `
  done
fi

if [ $gtype = regional -a $nest_grids -gt 1 ]; then
  cp -p $out_dir/${CASE}_all_mosaic.nc $out_dir/${CASE}_mosaic.nc
  echo "Copy grid and orography files to output directory"
  tile=8
  ntiles=`expr ${nest_grids} + 6`
  while [ $tile -le $ntiles ]; do
    cp $filter_dir/oro.${CASE}.tile${tile}.nc $out_dir/${CASE}_oro_data.tile${tile}.nc
    cp $grid_dir/${CASE}_grid.tile${tile}.nc  $out_dir/${CASE}_grid.tile${tile}.nc
    tile=`expr $tile + 1 `
  done
fi

#----------------------------------------------------------------
# Make surface static fields - vegetation type, soil type, etc.
#
# For global grids with a nest, the program is run twice.  First
# to create the fields for the six global tiles.  Then to create
# the fields on the high-res nest.  This is done because the
# ESMF libraries can not interpolate to seven tiles at once.
# Note:
# Stand-alone regional grids may be run with any number of
# tasks.  All other configurations must be run with a
# MULTIPLE OF SIX MPI TASKS.

date
input_sfc_climo_dir=${FIXhafs}/fix_sfc_climo
sfc_climo_workdir=$DATA/sfc_climo
sfc_climo_savedir=$out_dir/fix_sfc
mkdir -p $sfc_climo_workdir $sfc_climo_savedir
cd ${sfc_climo_workdir}

if [ $gtype = uniform ] || [ $gtype = stretch ]; then
  GRIDTYPE=NULL
  HALO=${HALO:-0}
  mosaic_file=${out_dir}/${CASE}_mosaic.nc
  the_orog_files='"'${CASE}'_oro_data.tile1.nc","'${CASE}'_oro_data.tile2.nc","'${CASE}'_oro_data.tile3.nc","'${CASE}'_oro_data.tile4.nc","'${CASE}'_oro_data.tile5.nc","'${CASE}'_oro_data.tile6.nc"'
elif [ $gtype = nest ]; then
  # First pass for global-nesting configuration will run the 6 global tiles
  GRIDTYPE=NULL
  HALO=${HALO:-0}
  mosaic_file=$out_dir/${CASE}_coarse_mosaic.nc
  the_orog_files='"'${CASE}'_oro_data.tile1.nc","'${CASE}'_oro_data.tile2.nc","'${CASE}'_oro_data.tile3.nc","'${CASE}'_oro_data.tile4.nc","'${CASE}'_oro_data.tile5.nc","'${CASE}'_oro_data.tile6.nc"'
elif [ $gtype = regional ]; then
  GRIDTYPE=regional
  tile=7
  HALO=$halop1
  ln -fs $out_dir/${CASE}_grid.tile${tile}.halo${HALO}.nc $out_dir/${CASE}_grid.tile${tile}.nc
  ln -fs $out_dir/${CASE}_oro_data.tile${tile}.halo${HALO}.nc $out_dir/${CASE}_oro_data.tile${tile}.nc
  if [ $nest_grids -gt 1 ];  then
    mosaic_file=${out_dir}/${CASE}_coarse_mosaic.nc
  else
    mosaic_file=${out_dir}/${CASE}_mosaic.nc
  fi
  the_orog_files='"'${CASE}'_oro_data.tile'${tile}'.nc"'
else
  echo "Error: please specify grid type with 'gtype' as uniform, stretch, nest or regional"
  exit 1
fi

cat>./fort.41<<EOF
&config
input_facsf_file="${input_sfc_climo_dir}/facsf.1.0.nc"
input_substrate_temperature_file="${input_sfc_climo_dir}/substrate_temperature.2.6x1.5.nc"
input_maximum_snow_albedo_file="${input_sfc_climo_dir}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${input_sfc_climo_dir}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${input_sfc_climo_dir}/slope_type.1.0.nc"
input_soil_type_file="${input_sfc_climo_dir}/soil_type.statsgo.0.05.nc"
input_vegetation_type_file="${input_sfc_climo_dir}/vegetation_type.igbp.0.05.nc"
input_vegetation_greenness_file="${input_sfc_climo_dir}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${mosaic_file}"
orog_dir_mdl="${out_dir}"
orog_files_mdl=${the_orog_files}
halo=${HALO}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
/
EOF
more ./fort.41

#APRUNC="srun --ntasks=6 --ntasks-per-node=6 --cpus-per-task=1"
if [[ ! -e ./hafs_sfc_climo_gen.x ]]; then
  cp -p $SFCCLIMOEXEC ./hafs_sfc_climo_gen.x
fi
$APRUNC ./hafs_sfc_climo_gen.x
#$APRUNC $SFCCLIMOEXEC

rc=$?

if [[ $rc == 0 ]]; then
  if [[ $GRIDTYPE != "regional" ]]; then
    for files in *.nc
    do
      if [[ -f $files ]]; then
        mv $files ${sfc_climo_savedir}/${CASE}.${files}
      fi
    done
  else
    for files in *.halo.nc
    do
      if [[ -f $files ]]; then
        file2=${files%.halo.nc}
        mv $files ${sfc_climo_savedir}/${CASE}.${file2}.halo${HALO}.nc
      fi
    done
    for files in *.nc
    do
      if [[ -f $files ]]; then
        file2=${files%.nc}
        mv $files ${sfc_climo_savedir}/${CASE}.${file2}.halo0.nc
      fi
    done
  fi  # is regional?
else
  exit $rc
fi

if [ $gtype = regional ]; then
  rm -f $out_dir/${CASE}_grid.tile${tile}.nc
  rm -f $out_dir/${CASE}_oro_data.tile${tile}.nc
fi

#----------------------------------------------------------------
# Run for the global or regional nested tiles
# Second pass for global-nesting or regional-nesting configuration will run the 7+th/8+th tiles
#----------------------------------------------------------------

if [ $gtype = nest -o $nest_grids -gt 1 ];  then

ntiles=$(( ${nest_grids} + 6 ))
export GRIDTYPE=nest
HALO=0

if [ $gtype = regional ]; then
  stile=8
else
  stile=7
fi

for itile in $(seq $stile $ntiles)
do

inest=$(($itile + 2 - $stile))
mosaic_file=$out_dir/${CASE}_nested0${inest}_mosaic.nc
the_orog_files='"'${CASE}'_oro_data.tile'${itile}'.nc"'

cat>./fort.41<<EOF
&config
input_facsf_file="${input_sfc_climo_dir}/facsf.1.0.nc"
input_substrate_temperature_file="${input_sfc_climo_dir}/substrate_temperature.1.0.nc"
input_maximum_snow_albedo_file="${input_sfc_climo_dir}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${input_sfc_climo_dir}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${input_sfc_climo_dir}/slope_type.1.0.nc"
input_soil_type_file="${input_sfc_climo_dir}/soil_type.statsgo.0.05.nc"
input_vegetation_type_file="${input_sfc_climo_dir}/vegetation_type.igbp.0.05.nc"
input_vegetation_greenness_file="${input_sfc_climo_dir}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${mosaic_file}"
orog_dir_mdl="${out_dir}"
orog_files_mdl=${the_orog_files}
halo=${HALO}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
/
EOF
more ./fort.41

#APRUNC="srun --ntasks=6 --ntasks-per-node=6 --cpus-per-task=1"
if [[ ! -e ./hafs_sfc_climo_gen.x ]]; then
  cp -p $SFCCLIMOEXEC ./hafs_sfc_climo_gen.x
fi
$APRUNC ./hafs_sfc_climo_gen.x
#$APRUNC $SFCCLIMOEXEC

rc=$?

if [[ $rc == 0 ]]; then
  for files in *.nc
  do
    if [[ -f $files ]]; then
      mv $files ${sfc_climo_savedir}/${CASE}.${files}
    fi
  done
else
  exit $rc
fi

done

fi
# End of run for the global or regional nested tiles.
#----------------------------------------------------------------

exit
