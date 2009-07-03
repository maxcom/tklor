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

package provide gaa_remoting 2.1

package require Tcl 8.4
package require gaa_logger 1.0

namespace eval remoting {

namespace export \
    startServer \
    sendRemote

proc startServer {serverName} {
    if { [ tk windowingsystem ] == "win32" } {
        package require dde 1.2

        return [ dde servername $serverName ]
    } else {
        return [ tk appname $serverName ]
    }
}

proc sendRemote {args} {
    set s [ list [ lindex $args 0 ] ]
    set args [ lreplace $args 0 0 ]
    if { $s == "-async" } {
        lappend s [ lindex $args 0 ]
        set args [ lreplace $args 0 0 ]
    }
    if { [ tk windowingsystem ] == "win32" } {
        return [ eval "dde eval $s [ list remoting::safeEval $args ]" ]
    } else {
        return [ eval "send $s [ list remoting::safeEval $args ]" ]
    }
}

proc safeEval {args} {
    if [ catch {set res [ eval "uplevel #0 $args" ]} err ] {
        puts stderr "err: $err"
        puts stderr "errinfo: $::errorInfo"
        logger::log "error while executing remote command: $err"
        logger::log "extended info: $::errorInfo"
    } else {
        return $res
    }
}

}
