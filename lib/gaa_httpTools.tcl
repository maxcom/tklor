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

package provide gaa_httpTools 1.1

package require Tcl 8.4
package require http 2.0
package require cmdline 1.2.5
package require autoproxy

namespace eval httpTools {

namespace export \
    init

proc init {args} {
    array set param [ ::cmdline::getoptions args {
        {charset.arg        "utf-8" "Default charset"}
        {useragent.arg      ""      "HTTP User-Agent string"}
        {useproxy.arg       "0"     "Use proxy"}
        {autoproxy.arg      "0"     "Proxy autoconfiguration"}
        {proxyhost.arg      ""      "Proxy host"}
        {proxyport.arg      ""      "Proxy port"}
        {proxyauth.arg      "0"     "Proxy requires authorization"}
        {proxyuser.arg      ""      "Proxy user"}
        {proxypassword.arg  ""      "Proxy password"}
    } ]

    if { $param(useproxy) != "0" } {
        ::autoproxy::init
        if { $param(autoproxy) == "0" } {
            ::autoproxy::configure -proxy_host $param(proxyhost) -proxy_port $param(proxyport)
        }
        if { $param(proxyauth) != "0" } {
            ::autoproxy::configure -basic -username $param(proxyuser) -password $param(proxypassword)
        }
        ::http::config -proxyfilter ::autoproxy::filter
    } else {
        ::http::config -proxyfilter ""
    }
    if { $param(useragent) != "" } {
        ::http::config -useragent $param(useragent)
    }
    set ::http::defaultCharset $param(charset)
}

}

