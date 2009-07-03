############################################################################
#    Copyright (C) 2008 by Alexander Galanin                               #
#    gaa.nnov@mail.ru                                                      #
#                                                                          #
#    This program is free software; you can redistribute it and/or modify  #
#    it under the terms of the GNU Library General Public License as       #
#    published by the Free Software Foundation; either version 3 of the    #
#    License, or (at your option) any later version.                       #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU Library General Public     #
#    License along with this program; if not, write to the                 #
#    Free Software Foundation, Inc.,                                       #
#    51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA               #
############################################################################

package provide tkLor_taskManager 1.1

package require Tcl 8.4
package require cmdline 1.2.5

namespace eval taskManager {

namespace export \
    addTask \
    stopTask \
    setUpdateHandler \
    getTasks \
    closeChannel

set updateScript ""

array set tasks ""

proc readableHandler {f onoutput onerror oncomplete} {
    if { [ gets $f str ] < 0 } {
        if [ eof $f ] {
            closeChannel $f $onerror
            uplevel #0 $oncomplete
        }
    } else {
        if { $onoutput != "" } {
            lappend onoutput $str
            uplevel #0 $onoutput
        }
    }
}

proc addTask {command args} {
    variable updateScript
    variable tasks

    array set p [ ::cmdline::getoptions args [ list \
        [ list title.arg      $command    "Title to display in task manager" ] \
        [ list mode.arg       "r"         "File open mode" ] \
        [ list encoding.arg   "utf-8"     "Encoding" ] \
        [ list onoutput.arg   ""          "Script to execute on output(1 arg)" ] \
        [ list onerror.arg    ""          "Script to execute on error(1 arg)" ] \
        [ list oncomplete.arg ""          "Script to execute on command finish" ] \
    ] ]

    set f [ open "|$command" $p(mode) ]
    if { $p(encoding) != ""} {
        fconfigure $f -encoding $p(encoding)
    }

    set tasks($f) $p(title)

    fconfigure $f -blocking 0 -buffering line
    fileevent $f readable [ list \
        [ namespace current ]::readableHandler \
            $f \
            $p(onoutput) \
            $p(onerror) \
            $p(oncomplete) \
    ]

    uplevel #0 $updateScript
    return $f
}

proc closeChannel {id {onerror ""}} {
    variable updateScript
    variable tasks

    unset tasks($id)
    uplevel #0 $updateScript
    fconfigure $id -blocking 1
    if [ catch {close $id} err ] {
        if { $onerror != "" } {
            lappend onerror $err
            uplevel #0 $onerror
        } else {
            error $err $::errorInfo
        }
    }
}

proc stopTask {id} {
    variable updateScript
    variable tasks

    unset tasks($id)
    uplevel #0 $updateScript
    fconfigure $id -blocking 0
    close $id
}

proc setUpdateHandler {script} {
    variable updateScript

    set updateScript $script
}

proc getTasks {} {
    return [ array get tasks ]
}

}

