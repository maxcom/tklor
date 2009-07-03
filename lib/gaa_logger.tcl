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

package provide gaa_logger 1.0

package require Tcl 8.4

namespace eval logger {

namespace export \
    log \
    traceStack \
    configure

variable appName ""

proc configure {app} {
    variable appName
    set appName $app
}

proc log {msg} {
    variable appName

    if {$appName != ""} {
        catch {
            set f [ open "$appName.log" "a" ]
            puts $f "[ clock format [ clock seconds ] ]: $msg"
            close $f
        }
    }
}

proc traceStack {} {
    set s ""
    for {set i 0} {$i < [ info level ]} {incr i} {
        lappend s "\[$i\] [ info level $i ]"
    }
    set s [ join $s "\n" ]
    log "Stack trace: $s"
}

}
