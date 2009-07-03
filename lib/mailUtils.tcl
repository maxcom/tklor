############################################################################
#   Copyright (C) 2008 Alexander Galanin <gaa.nnov@mail.ru>                #
#                                                                          #
#   This program is free software: you can redistribute it and/or modify   #
#   it under the terms of the GNU Lesser General Public License as         #
#   published by the Free Software Foundation, either version 3 of the     #
#   License, or (at your option) any later version.                        #
#                                                                          #
#   This program is distributed in the hope that it will be useful,        #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of         #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
#   GNU General Public License for more details.                           #
#                                                                          #
#   You should have received a copy of the GNU Lesser GNU General Public   #
#   License along with this program.                                       #
#   If not, see <http://www.gnu.org/licenses/>.                            #
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
        From            ""
        To              ""
        In-Reply-To     ""
        Message-ID      ""
        Subject         ""
        Content-Type    "text/html"
        body            ""
    }
    foreach {h v} [ concat $letter $headers ] {
        if { [ lsearch [ array names tmp ] $h ] >= 0 } {
            set tmp($h) $v
        } else {
            lappend res $h $v
        }
    }
    lappend res From $from
    lappend res To $tmp(From)
    lappend res In-Reply-To $tmp(Message-ID)
    if { $tmp(Content-Type) == "text/html" } {
        set subj [ htmlToText $tmp(Subject) ]
        set body [ htmlToText $tmp(body) ]
    } else {
        set subj $tmp(Subject)
        set body $tmp(body)
    }
    #TODO: will be removed in v1.2
    lappend res Subject [ makeReplyHeader $subj ]
    lappend res Content-Type "text/plain"
    lappend res body [ quoteText $body ]
    array unset tmp

    return $res
}

#
# getMailHeaders    -   Get specified headers from letter as list.
#                       If header does not present in text, it will be
#                       substituded as ""
#
#   letter  -   message to process
#   headers -   list of headers
#
proc getMailHeaders {letter headers} {
    array set arr ""
    foreach h $headers {
        set arr($h) ""
    }
    foreach {h v} $letter {
        if { [ lsearch $headers $h ] } {
            set arr($h) $v
        }
    }
    set res ""
    foreach h $headers {
        lappend res $arr($h)
    }
    array unset arr
    return $res
}

}

