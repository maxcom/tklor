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

package provide gaa_lambda 1.2

package require Tcl 8.4

namespace eval lambda {

namespace export \
    lambda \
    deflambda \
    closure \
    defclosure

proc lambdaLowlevel {paramsVar scriptVar argsVar} {
    set params [ uplevel [ list set $paramsVar ] ]
    set script [ uplevel [ list set $scriptVar ] ]
    set args [ uplevel [ list set $argsVar ] ]
    uplevel [ list unset $paramsVar $scriptVar $argsVar ]
    for {set i 0} {$i < [ llength $params ]} {incr i} {
        if { [ lindex $params $i ] != "args" } {
            uplevel [ list set [ lindex $params $i ] [ lindex $args $i ] ]
        } else {
            uplevel [ list set [ lindex $params $i ] [ lrange $args $i end ] ]
        }
    }
    uplevel [ list eval $script ]
}

proc lambdaProc {params script args} {
    if {( [ lindex $params end ] == "args" && [ llength $params ] > [ llength $args ] ) || \
        ( [ lindex $params end ] != "args" && [ llength $params ] != [ llength $args ] )} {
        error "Arguments count mismatch: expected $params, but $args passed."
    }
    ::lambda::lambdaLowlevel params script args
}

proc lambda {params script args} {
    return [ concat [ list [ namespace current ]::lambdaProc $params $script ] $args ]
}

proc deflambda {id params script args} {
    uplevel [ list set $id [ concat [ list [ namespace current ]::lambdaProc $params $script ] $args ] ]
}

proc closure {locals params script args} {
    set localParams ""
    set localArgs ""
    foreach p $locals {
        lappend localParams $p
        lappend localArgs [ uplevel [ list set $p ] ]
    }
    return [ concat \
        [ list [ namespace current ]::lambdaProc \
            [ concat $localParams $params ] \
            $script \
        ] \
        [ concat $localArgs $args ] \
    ]
}

proc defclosure {id locals params script args} {
    set localParams ""
    set localArgs ""
    foreach p $locals {
        lappend localParams $p
        lappend localArgs [ uplevel [ list set $p ] ]
    }
    uplevel [ concat \
        [ list deflambda \
            $id \
            [ concat $localParams $params ] \
            $script \
        ] \
        [ concat $localArgs $args ] \
    ]
}

}

