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

package provide mailUtils 1.0

package require Tcl 8.4
package require htmlparse 1.1

namespace eval mailUtils {

namespace export \
    makeReplyHeader \
    quoteText \
    makeReply

#
# makeReply -   Make header with "Re:" prefix
#
proc makeReplyHeader {header} {
    set re {^re(?:\^(\d+)|()):\s+}
    set count 0

    while { [ regexp -nocase -lineanchor -- $re $header dummy c ] != 0 } {
        if { $c == "" } {
            set c 1
        }
        incr count $c
        regsub -nocase -lineanchor -- $re $header {} header
    }

    if { $count != 0 } {
        return "Re^[ expr $count + 1 ]: $header"
    } else {
        return "Re: $header"
    }
}

#
# quoteText -   Put text into ">" quotes
#
proc quoteText {text} {
    set res ""
    foreach line [ split $text "\n" ] {
        if { [ string trim $line ] != "" } {
            if { [ string compare -length 1 $line ">" ] == 0 } {
                lappend res ">$line"
            } else {
                lappend res "> $line"
            }
        }
    }
    return [ join $res "\n\n" ]
}

#
# htmlToText    -   convert LOR-style HTML to text
#
proc htmlToText {text} {
    foreach {re s} {
        {<img src="/\w+/\w+/votes\.gif"[^>]*>} "\[\\&\]"
        "<img [^>]*?>" "[image]"
        "<!--.*?-->" ""
        "<tr>" "\n"
        "</tr>" ""
        "</{0,1}table>" ""
        "</{0,1}td(?: colspan=\\d+){0,1}>" " "
        "</{0,1}pre>" ""
        "\n<br>" "\n"
        "<br>\n" "\n"
        "<br>" "\n"
        "<p>" "\n"
        "</p>" ""
        "<a href=\"([^\"]+)\"[^>]*>[^<]*</a>" "\\1"
        "</{0,1}i>" ""
        "</{0,1}(?:u|o)l>" ""
        "<li>" "\n * "
        "</li>" ""
        "\n{3,}" "\n\n" } {
        regsub -all -nocase -- $re $text $s text
    }
    return [ ::htmlparse::mapEscapes $text ]
}

#
# makeReplyToMessage    -   Make reply to specified message
#
#   letter  -   original letter
#   from    -   string to substitute into From header
#   headers -   (optional) additional headers
#
proc makeReplyToMessage {letter from {headers ""}} {
    set res ""
    array set tmp {
        From        ""
        Message-ID  ""
        Subject     ""
        body        ""
    }
    foreach {h v} [ concat $letter $headers ] {
        if { [ lsearch \
            {From To Message-ID Subject In-Reply-To body} $h \
        ] >= 0 } {
            set tmp($h) $v
        } else {
            lappend res $h $v
        }
    }
    lappend res From $from
    lappend res To $tmp(From)
    lappend res In-Reply-To $tmp(Message-ID)
    lappend res Subject [ makeReplyHeader [ htmlToText $tmp(Subject) ] ]
    lappend res body [ quoteText [ htmlToText $tmp(body) ] ]
    array unset tmp

    return $res
}


}

