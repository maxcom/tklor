############################################################################
#    Copyright (C) 2008 by Alexander Galanin                               #
#    gaa.nnov@mail.ru                                                      #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 3 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA               #
############################################################################

package provide gaa_lambda 1.0

package require Tcl 8.4

namespace eval ::gaa {
namespace eval lambda {

namespace export \
    lambda \
    deflambda

proc lambdaLowlevel {paramsVar scriptVar argsVar} {
    set params [ uplevel [ list set $paramsVar ] ]
    set script [ uplevel [ list set $scriptVar ] ]
    set args [ uplevel [ list set $argsVar ] ]
    uplevel [ list unset $paramsVar $scriptVar $argsVar ]
    for {set i 0} {$i < [ llength $params ]} {incr i} {
        uplevel [ list set [ lindex $params $i ] [ lindex $args $i ] ]
    }
    uplevel [ list eval $script ]
}

proc lambdaProc {params script args} {
    if { [ llength $params ] != [ llength $args ] } {
        error "Arguments count mismatch: expected [ llength $params ], but [ llength $args ] passed."
    }
    ::gaa::lambda::lambdaLowlevel params script args
}

proc lambda {params script args} {
    return [ concat [ list ::gaa::lambda::lambdaProc $params $script ] $args ]
}

proc deflambda {id params script args} {
    uplevel [ list set $id [ concat [ list ::gaa::lambda::lambdaProc $params $script ] $args ] ]
}

}
}
