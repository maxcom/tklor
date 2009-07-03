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

package provide gaa_mbox 1.1

package require Tcl 8.4
package require cmdline 1.2.5

namespace eval mbox {

namespace export \
    parse \
    writeToFile \
    writeToStream

set id 0

proc parseLetter {stream id command onerror oncomplete} {
    variable letter$id
    variable state$id

    set letter [ set letter$id ]
    set state [ set state$id ]
    array unset lt
    array set lt $letter

    if [ eof $stream ] {
        if [ catch {close $stream} err ] {
            eval [ concat $onerror [ list $err ] ]
        }
        set state EOF
    } else {
        gets $stream s
    }
    if { $state == "EOF" ||
            ( [ regexp -lineanchor -- {^From:{0,1} (.+)$} $s dummy nick ] &&
                ( $state == "BODYSPACE" || $state == "BEGIN" ) ) } {
        if { ! [ regexp {^\s*$} $letter ] } {
            if [ catch {eval [ concat $command [ list $letter ] ]} err ] {
                eval [ concat $onerror [ list $err ] ]
            }
        }
        if { $state != "EOF" } {
            set state$id HEAD
            set letter$id [ list "From" $nick ]
            return 1
        } else {
            eval $oncomplete
            return 0
        }
    }
    if { $s == "" } {
        switch -exact $state {
            HEAD {
                set state$id BODY
                set lt(body) ""
                set letter$id [ array get lt ]
            }
            BODY {
                set state$id BODYSPACE
            }
            BODYSPACE {
                set lt(body) "$lt(body)\n"
                set letter$id [ array get lt ]
            }
        }
        return 1
    }
    if { $state == "HEAD" } {
        if [ regexp -lineanchor -- {^([\w-]+): (.+)$} $s dummy tag val ] {
            set lt($tag) $val
        } else {
            eval [ concat $onerror \
                [ list "Invalid data in the header section: $s" ] \
            ]
        }
    } else {
        if [ regexp -lineanchor {^>(>*From:{0,1} .*)$} $s dummy ss ] {
            set s $ss
        }
        set lt(body) "$lt(body)\n$s"
    }
    set letter$id [ array get lt ]
    return 1
}

proc parse {fileName script args} {
    variable id

    array set p [ ::cmdline::getoptions args {
        {encoding.arg   ""      "Encoding"}
        {noasync                "Parse file in synchronous mode"}
        {oncomplete.arg ""      "Script to execute on complete(async mode)"}
        {onerror.arg    "error" "Script to execute on error(async mode)"}
    } ]
    set stream [ open $fileName "r" ]
    if { $p(encoding) != ""} {
        fconfigure $stream -encoding $p(encoding)
    }
    incr id

    variable letter$id
    variable state$id

    set letter$id ""
    set state$id "BEGIN"

    if $p(noasync) {
        while { [ parseLetter $stream $id $script "error" "" ] == 1 } {}
    } else {
        fconfigure $stream -buffering line
        fileevent $stream readable \
            [ list [ namespace current ]::parseLetter \
                $stream $id $script $p(onerror) $p(oncomplete) ]
    }
}

proc writeToFile {fileName letter args} {
    array set param [ ::cmdline::getoptions args {
        {encoding.arg   ""  "Encoding"}
        {append             "Append to file instead of overwriting"}
    } ]
    if $param(append) {
        set mode "a"
    } else {
        set mode "w"
    }
    set f [ open $fileName $mode ]
    if {$param(encoding) != ""} {
        fconfigure $f -encoding $param(encoding)
    }
    foreach letter $letter {
        writeToStream $f $letter
    }
    close $f
}

proc writeToStream {stream letter} {
    set body ""
    foreach {header value} $letter {
        if {$header != "body"} {
            puts -nonewline $stream "$header"
            if {$header != "From"} {
                puts -nonewline $stream ":"
            }
            puts $stream " $value"
        } else {
            set body $value
        }
    }
    puts $stream ""

    foreach line [ split $body "\n" ] {
        if [ regexp -lineanchor {^>*From } $line ] {
            puts -nonewline $stream ">"
        }
        puts $stream $line
    }
    puts $stream ""
}

}
