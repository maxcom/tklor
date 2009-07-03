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

package provide gaa_mbox 1.0

package require Tcl 8.4
package require cmdline 1.2.5

namespace eval ::gaa {
namespace eval mbox {

namespace export \
    parseFile \
    parseStream \
    writeToFile \
    writeToStream

proc parseFile {fileName script args} {
    array set param [ ::cmdline::getoptions args {
        {encoding.arg   ""  "Encoding"}
    } ]
    set f [ open $fileName "r" ]
    if { $param(encoding) != ""} {
        fconfigure $f -encoding $param(encoding)
    }
    if [ catch {
        parseStream $f $script
    } errMsg ] {
        close $f
        error $errMsg
    }
    close $f
}

proc parseStream {stream script} {
    while { [ gets $stream s ] >=0 } {
        if [ regexp -lineanchor -- {^From:{0,1} (.+)$} $s dummy nick ] {
            break
        }
    }
    if [ eof $stream ] {
        return ""
    }
    while { ! [eof $stream ] } {
        set cur ""
        lappend cur "From" $nick

        while { [ gets $stream s ] >=0 } {
            if { $s == "" } {
                break
            }
            if [ regexp -lineanchor -- {^([\w-]+): (.+)$} $s dummy tag val ] {
                lappend cur $tag $val
            }
        }

        set body ""
        while { [ gets $stream s ] >=0 } {
            if [ regexp -lineanchor -- {^From:{0,1} (.+)$} $s dummy nick ] {
                break
            } else {
                if [ regexp -lineanchor {^>(>*From:{0,1} .*)$} $s dummy ss ] {
                    set s $ss
                }
                append body "$s\n"
            }
        }
        lappend cur "body" [ string trimright $body "\n" ]

        eval [ concat $script [ list $cur ] ]
    }
}

proc writeToFile {fileName letters args} {
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
    foreach letter $letters {
        writeToStream $f $letter
    }
    close $f
}

proc writeToStream {stream letter} {
    set body ""
    foreach {header value} $letter {
        if {$header != "body"} {
            puts $stream "$header"
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
}
