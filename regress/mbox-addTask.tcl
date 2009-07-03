#!/bin/sh
# \
exec tclsh "$0" "$@"

set dataFile "mbox.dat"

lappend auto_path "../lib"

package require gaa_mbox
package require tkLor_taskManager

set id [ mbox::initParser puts ]

set task [ taskManager::addTask "cat $dataFile" \
    -onoutput [ list mbox::parseLine $id ] \
    -oncomplete [ join [ list \
        [ list mbox::closeParser $id ] \
        {set finish 1} \
    ] ";" ] \
]

vwait finish

