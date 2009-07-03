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
    initParser \
    closeParser \
    parseLine \
    parseFile \
    parseStream \
    writeToFile \
    writeToStream

set id 0

proc parseLine {id line} {
    variable letter$id
    variable state$id
    variable command$id

    set letter [ set letter$id ]
    set state [ set state$id ]
    array unset lt
    array set lt $letter

    if { $state == "EOF" ||
            ( [ regexp {^From:{0,1} (.+)$} $line dummy nick ] &&
                ( $state == "BODYSPACE" || $state == "BEGIN" ) ) } {
        regsub {(\n)+$} $lt(body) "" lt(body)
        set letter [ array get lt ]

        if [ info exists lt(From) ] {
            uplevel #0 [ concat [ set command$id ] [ list $letter ] ]
        }
        if { $state != "EOF" } {
            set state$id HEAD
            set letter$id [ list "From" $nick ]
        }
        return
    }
    if { $line == "" } {
        switch -exact $state {
            HEAD {
                set state$id BODY
                set lt(body) ""
            }
            BODY {
                set state$id BODYSPACE
            }
            BODYSPACE {
                set lt(body) "$lt(body)\n"
            }
        }
        set letter$id [ array get lt ]
        return
    }
    if { $state == "HEAD" || $state == "BEGIN" } {
        if [ regexp {^([\w-]+):\s*(.*)$} $line dummy tag val ] {
            set lt($tag) $val
        } else {
            error "Invalid data in the header section: $line"
        }
    } else {
        if [ regexp {^>(>*From:{0,1} .*)$} $line dummy ss ] {
            set line $ss
        }
        append lt(body) "$line\n"
    }
    set letter$id [ array get lt ]
}

proc outputHandler {id stream onoutput onerror oncomplete} {
    if { [ gets $stream s ] < 0 } {
        if [ eof $stream ] {
            if [ catch {
                fconfigure $stream -blocking 1
                close $stream
            } err ] {
                lappend onerror $err
                uplevel #0 $onerror
            } else {
                closeParser $id
                uplevel #0 $oncomplete
            }
        }
    } else {
        lappend onoutput $s
        uplevel #0 $onoutput
    }
}

proc parseFile {fileName command args} {
    array set p [ ::cmdline::getoptions args {
        {mode.arg       "r"     "Stream open mode"}
        {sync.arg       "0"     "Parse stream in synchronous mode"}
        {oncomplete.arg ""      "Script to execute on complete(async mode)"}
        {onerror.arg    "error" "Script to execute on error(async mode)"}
    } ]

    set f [ open $fileName $p(mode) ]
    parseStream $f $command \
        -oncomplete [ join [ list $p(oncomplete) [ list close $f ] ] ";" ] \
        -onerror $p(onerror) \
        -sync $p(sync)
}

proc parseStream {stream command args} {
    array set p [ ::cmdline::getoptions args {
        {sync.arg       "0"     "Parse stream in synchronous mode"}
        {oncomplete.arg ""      "Script to execute on complete(async mode)"}
        {onerror.arg    "error" "Script to execute on error(async mode)"}
    } ]

    set id [ initParser $command ]
    if $p(sync) {
        fconfigure $stream -blocking 1
        if [ catch {
            while { [ gets $stream s ] >= 0 } {
                parseLine $id $s
            }
        } err ] {
            set errInfo $::errorInfo
            catch {closeParser $id}
            error $err $errInfo
        }
        closeParser $id
        close $stream
    } else {
        fconfigure $stream \
            -buffering line \
            -blocking 0
        fileevent $stream readable [ list \
            [ namespace current ]::outputHandler \
            $id \
            $stream \
            [ list [ namespace current ]::parseLine $id ] \
            $p(onerror) \
            $p(oncomplete) \
        ]
    }
}

proc initParser {command} {
    variable id
    incr id

    variable letter$id
    variable state$id
    variable command$id

    set letter$id {body ""}
    set state$id "BEGIN"
    set command$id $command

    return $id
}

proc closeParser {id} {
    variable letter$id
    variable state$id
    variable command$id

    set state$id EOF
    if [ catch {parseLine $id ""} err ] {
        unset letter$id state$id command$id

        error $err $::errorInfo
    }
    unset letter$id state$id command$id
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
    if [ catch {
        foreach letter $letter {
            writeToStream $f $letter
        }
    } err ] {
        close $f
        error $err $::errorInfo
    }
    close $f
}

proc writeToStream {stream letter} {
    set body ""
    set fromExists 0
    foreach {header value} $letter {
        if { $header == "From"} {
            puts $stream "From $value"
            set fromExists 1
            break
        }
    }
    if { $fromExists == 0 } {
        error "No From header"
    }
    foreach {header value} $letter {
        if {$header != "body"} {
            if {$header != "From"} {
                puts $stream "$header: $value"
            }
        } else {
            set body $value
        }
    }
    puts $stream ""

    foreach line [ split $body "\n" ] {
        if [ regexp {^>*From } $line ] {
            puts -nonewline $stream ">"
        }
        puts $stream $line
    }
    puts $stream ""
}

}
