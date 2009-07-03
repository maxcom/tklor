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

package provide gaa_remoting 1.0

package require Tcl 8.4
package require cmdline 1.2.5
package require gaa_lambda 1.0
package require base64 2.3.2

namespace eval gaa {
namespace eval remoting {

namespace export \
    invokeSlave \
    invokeMaster \
    killSlave \
    defMasterLambda \
    encode \
    decode

proc invokeSlave {backend command args} {
    array set params [ ::cmdline::getoptions args {
        {oncomplete.arg ""  "Script to execute on background operation completes"}
        {onerror.arg    ""  "Script to execute on background operation error"}
        {timeout.arg    "0" "Execution timeout in milliseconds (0 - no timeout)"}
        {ontimeout.arg  ""  "Script to execute on background operation timeout"}
    } ]
    set f [ open [ concat "|$backend" [ list "<<" [ encode $command ] ] ] "r" ]
    fileevent $f readable [ ::gaa::lambda::lambda {f onComplete onError} {
        if { ![ eof $f ] } {
            set count [ gets $f ]
            if [ string is integer -strict $count ] {
                set cmd [ decode [ read $f $count ] ]
                eval $cmd
            }
        } else {
            if [ catch {close $f} err ] {
                eval [ concat $onError [ list $err ] ]
            }
            eval $onComplete
        }
    } $f $params(oncomplete) $params(onerror) ]
    if { $params(timeout) > 0 } {
        after $params(timeout) $params(ontimeout)
    }
    return $f
}

proc invokeMaster {arg} {
    set s [ encode $arg ]
    append s "\n"
    puts [ string length $s ]
    puts -nonewline $s
}

proc killSlave {slave {script ""}} {
    if { ![ catch {close $slave} ] } {
        eval $script
    }
}

proc addDollars {arg} {
    set res ""
    foreach i $arg {
        append res " \$$i"
    }
    return $res
}

proc defMasterLambda {id params script args} {
    uplevel [ concat [ list ::gaa::lambda::deflambda $id $params \
        "::gaa::remoting::invokeMaster \[ ::gaa::lambda::lambda [ list $params $script ] [ ::gaa::remoting::addDollars $params ] \]" \
    ] $args ]
}

proc encode {str} {
    return [ ::base64::encode [ encoding convertto utf-8 $str ] ]
}

proc decode {str} {
    return [ encoding convertfrom utf-8 [ ::base64::decode $str ] ]
}

}
}
