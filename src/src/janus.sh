#!/bin/bash

SYSTEM_PATH=`pwd`

export SYSTEM=`/bin/uname`
export HOSTNAME=`hostname`
export HOST=`hostname`

export JANUS_LIBRARY="${SYSTEM_PATH}/janus-lib/library"
export TCL_LIBRARY="${SYSTEM_PATH}/janus-lib/tcl-lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${SYSTEM_PATH}/janus-lib/lib"

export OMP_NUM_THREADS=4  # optimal number of threads
#Janus online
${SYSTEM_PATH}/janus-lib/janus ${@:1:$#}
