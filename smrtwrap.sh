#!/bin/bash
echo "$1 == $0  -- $@ --"

# ---- error handling
set -o errexit;
set -o posix;
set -o pipefail;
set -o errtrace;
unexpected_error() {
    local errstat=$?
    echo "${g_prog:-$(basename $0)}: Error! Encountered unexpected error at 'line $(caller)', bailing out..." 1>&2
    exit $errstat;
}
trap unexpected_error ERR;

# Save off the original path, just in case
PATH_ORIG=$PATH;

# Assume that basename, dirname and readlink in the user's path are 
# standard (or at least compatible with what we expect)
g_prog=$(basename $0);
g_progdir=$(dirname $0);
g_progdir_abs=$(readlink -f "$g_progdir");

# ---- main

# Source the smrtanalysis setup.sh file
. $($(dirname $(readlink -f "$0"))/../../admin/bin/getsetupfile)

# Fire off the program
exec ${1+"$@"}
