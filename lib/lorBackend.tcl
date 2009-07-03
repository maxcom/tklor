#!/bin/sh
############################################################################
#    Copyright (C) 2008 by Alexander Galanin                               #
#    gaa.nnov@mail.ru                                                      #
#                                                                          #
#    This program is free software; you can redistribute it and/or modify  #
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

# \
exec tclsh "$0" "$@"

package require Tcl 8.4
package require cmdline 1.2.5
package require struct::stack 1.3

if {[ string first Windows $tcl_platform(os) ] == -1} {
    set libDir "/usr/lib/tkLOR"
} else {
    set libDir "."
}

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc loadAppLibs {libDir} {
    global auto_path

    lappend auto_path $libDir

    package require lorParser 1.3
    package require gaa_httpTools 1.0
    package require gaa_mbox 1.1
}

proc bgerror {msg} {
    error $msg $::errorInfo
}

proc parseArgs {stream} {
    set res ""
    while { [ gets $stream line ] >= 0 } {
        if { $line == "" } {
            break
        }
        if [ regexp {([\w-]+):\s*(.*)} $line dummy key val ] {
            lappend res $key $val
        } else {
            error "Unable to parse string '$line'"
        }
    }
    return $res
}

proc printTopic {id nick header date content} {
    ::mbox::writeToStream stdout [ list \
        "From"          $nick \
        "X-LOR-Id"      $id \
        "X-LOR-Time"    $date \
        "Subject"       $header \
        "body"          $content \
    ]
}

proc printTopicText {id nick header msg date approver approveTime} {
    ::mbox::writeToStream stdout [ list \
        "From"          $nick \
        "X-LOR-Id"      $id \
        "X-LOR-Time"    $date \
        "Subject"       $header \
        "X-LOR-Approver" $approver \
        "X-LOR-Approve-Time" $approveTime \
        "body"          $msg \
    ]
}

proc printMessage {id nick header date msg parent parentNick} {
    ::mbox::writeToStream stdout [ list \
        "From"          $nick \
        "To"            $parentNick \
        "X-LOR-ReplyTo-Id" $parent \
        "X-LOR-Id"      $id \
        "X-LOR-Time"    $date \
        "Subject"       $header \
        "body"          $msg \
    ]
}

proc pushArgs {stack args} {
    st push $args
}

############################################################################
#                                   MAIN                                   #
############################################################################

foreach stream {stdin stdout} {
    fconfigure $stream -encoding "utf-8"
}

array set p [ ::cmdline::getoptions argv [ list \
    [ list libDir.arg   $libDir "Library path" ] \
    {get.arg            ""      "Get messages from thread"} \
    {list.arg           ""      "List threads in category"} \
    {login                      "Log in to LOR"} \
    {useragent.arg      "tkLOR" "HTTP User-Agent"} \
    {useproxy                   "Use proxy"} \
    {autoproxy                  "Use proxy autoconfiguration"} \
    {proxyhost.arg      ""      "Proxy host"} \
    {proxyport.arg      ""      "Proxy port"} \
    {proxyauth                  "Proxy authorization"} \
    {proxyuser.arg      ""      "Proxy user"} \
    {proxypassword.arg  ""      "Proxy password"} \
    {debug.secret               "Turn on debug mode"} \
] ]

loadAppLibs $p(libDir)

set httpParams {-charset "utf-8"}
foreach key {useproxy autoproxy useragent proxyhost proxyport 
        proxyauth proxyuser proxypassword} {
    lappend httpParams -$key $p($key)
}
eval [ concat ::httpTools::init $httpParams ]

if [ catch {
    if { $p(get) != "" } {
        ::lor::parseTopic $p(get) [ list printTopicText $p(get) ] printMessage
        exit 0
    }
    if { $p(list) != "" } {
        struct::stack st
        ::lor::getTopicList $p(list) {pushArgs st}
        while { [ st size ] > 0 } {
            eval [ concat printTopic [ st pop ] ]
        }
        exit 0
    }
    if $p(login) {
        array set arg [ parseArgs stdin ]
        puts -nonewline [ ::lor::login $arg(login) $arg(password) ]
        exit 0
    }
} err ] {
    if $p(debug) {
        puts stderr "$err $errorInfo"
    } else {
        puts stderr $err
    }
    exit 1
}

puts stderr "No actions given"
exit 1

