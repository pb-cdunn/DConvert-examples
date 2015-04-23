#!/bin/bash
set -e

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
paths=""
modules=""
verbose=0
dry_run=0

while getopts "hvnp:m:" opt; do
    case "$opt" in
    h)
        show_help
        exit 2
        ;;
    v)  verbose=1
        ;;
    n)  dry_run=1
	;;
    p)  paths="$paths $OPTARG"
        ;;
    m)  modules="$modules $OPTARG"
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

leftovers="$@"

function Echo(){
	if [ $verbose -ne 0 ]
	then
		echo "'$@'"
	fi
}

Echo "verbose=$verbose, dry_run=$dry_run paths='$paths', modules='$modules', Leftovers: $leftovers"

#########################################
# GNU module
. /mnt/software/Modules/current/init/bash

if [ -n "$paths" ]
then
	Echo module use $paths
	module use $paths
fi

if [ -n "$modules" ]
then
	Echo module load $modules
	module load $modules
fi

Echo "$@"
if [ $dry_run -eq 0 ]
then
	exec "$@"
fi
