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

    package require lorParser 1.0
    package require gaa_httpTools 1.0
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

############################################################################
#                                   MAIN                                   #
############################################################################

foreach stream {stdin stdout} {
    fconfigure $stream -encoding "utf-8"
}

array set p [ ::cmdline::getoptions argv [ list \
    [ list libDir.arg   $libDir "Library path" ] \
    {get.arg            ""      "Get messages from thread <id>"} \
    {login                      "Log in to LOR"} \
    {useragent.arg      "tkLOR" "HTTP User-Agent"} \
    {useproxy                   "Use proxy"} \
    {autoproxy                  "Use proxy autoconfiguration"} \
    {proxyhost.arg      ""      "Proxy host"} \
    {proxyport.arg      ""      "Proxy port"} \
    {proxyauth                  "Proxy authorization"} \
    {proxyuser.arg      ""      "Proxy user"} \
    {proxypassword.arg  ""      "Proxy password"} \
] ]

loadAppLibs $p(libDir)

set httpParams {-charset "utf-8"}
foreach key {useproxy autoproxy useragent proxyhost proxyport 
        proxyauth proxyuser proxypassword} {
    lappend httpParams $p($key)
}
eval [ concat gaa::httpTools::init $httpParams ]

if { $p(get) != "" } {
    #TODO
    exit 0
}

if $p(login) {
    array set arg [ parseArgs stdin ]
    if [ catch {
        puts -nonewline [ ::lor::login $arg(login) $arg(password) ]
    } err ] {
        puts stderr $err
        exit 1
    } else {
        exit 0
    }
}

puts stderr "No actions given"
exit 1

