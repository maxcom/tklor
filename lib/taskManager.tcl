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

package provide tkLor_taskManager 1.0

package require Tcl 8.4
package require struct::queue 1.4

namespace eval tkLor {
namespace eval taskManager {

namespace export \
    addTask \
    stopTask \
    stopAllTasks \
    taskCompleted \
    isTaskStopped \
    setUpdateHandler \
    getTasksCount

struct::queue getMessageList
struct::queue getTopicList
struct::queue postMessage

set updateScript ""

proc addTask {queue args} {
    variable stopped
    variable updateScript

    $queue put $args
    if { [ $queue size ] == 1 } {
        runFromQueue $queue
    }
    uplevel #0 $updateScript
}

proc stopTask {queue} {
    variable stopped

    array set stopped [ list $queue 1 ]
}

proc stopAllTasks {queue} {
    variable stopped
    variable updateScript

    array set stopped [ list $queue 1 ]
    $queue clear
    $queue unget ""
    uplevel #0 $updateScript
}

proc runFromQueue {queue} {
    variable stopped
    variable updateScript

    array set stopped [ list $queue 0 ]
    if { [ $queue size ] != 0 } {
        set script [ $queue peek ]
        eval $script
    }
    uplevel #0 $updateScript
}

proc taskCompleted {queue} {
    $queue get
    runFromQueue $queue
}

proc isTaskStopped {queue} {
    variable stopped

    return $stopped($queue)
}

proc setUpdateHandler {script} {
    variable updateScript

    set updateScript $script
}

proc getTasksCount {queue} {
    return [ $queue size ]
}

}
}
