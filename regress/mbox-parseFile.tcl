#!/bin/sh
# \
exec tclsh "$0" "$@"

set dataFile "mbox.dat"

lappend auto_path "../lib"

package require gaa_mbox

mbox::parseFile $dataFile puts \
    -oncomplete {set finish 1}

vwait finish

