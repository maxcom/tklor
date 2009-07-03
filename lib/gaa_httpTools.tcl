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

package provide gaa_httpTools 1.0

package require Tcl 8.4
package require http 2.0
package require cmdline 1.2.5
package require gaa_lambda 1.0

namespace eval ::gaa {
namespace eval httpTools {

namespace export \
    init

proc init {args} {
    array set param [ ::cmdline::getoptions args {
        {charset.arg    "utf-8" "Default charset"}
        {useragent.arg  ""      "HTTP User-Agent string"}
        {proxy.arg      "0"     "Use proxy"}
        {autoproxy.arg  "0"     "Proxy autoconfiguration"}
        {proxyhost      ""      "Proxy host"}
        {proxyport      ""      "Proxy port"}
        {proxyauth      "0"     "Proxy requires authorization"}
        {proxyuser      ""      "Proxy user"}
        {proxypassword  ""      "Proxy password"}
    } ]

    if { $param(proxy) != "0" } {
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
}