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
    taskCompleted \
    isTaskStopped

struct::queue getMessageList
struct::queue getTopicList
struct::queue postMessage

proc addTask {queue args} {
    variable stopped

    $queue put $args
    if { [ $queue size ] == 1 } {
        runFromQueue $queue
    }
}

proc stopTask {queue} {
    variable stopped

    array set stopped [ list $queue 1 ]
}

proc runFromQueue {queue} {
    variable stopped

    array set stopped [ list $queue 0 ]
    if { [ $queue size ] != 0} {
        set script [ $queue get ]
        eval $script
    }
}

proc taskCompleted {queue} {
    runFromQueue $queue
}

proc isTaskStopped {queue} {
    variable stopped

    return $stopped($queue)
}

}
}
