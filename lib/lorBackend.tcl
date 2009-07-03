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

package require Tcl 8.4
package require cmdline 1.2.5
package require base64 2.3.2

set appName tkLOR
set processId tkLOR-backend

set xdg_config_home ""
catch {set xdg_config_home $::env(XDG_CONFIG_HOME)}
if { $xdg_config_home == "" } {
    set xdg_config_home [ file join $::env(HOME) ".config" ]
}
set configDir [ file join $xdg_config_home $appName ]

if {[ string first Windows $tcl_platform(os) ] == -1} {
    set libDir "/usr/lib/tkLOR"
} else {
    set libDir "."
}

############################################################################
#                                 VARIABLES                                #
############################################################################

set useProxy 0
set proxyAutoSelect 0
set proxyHost ""
set proxyPort ""
set proxyAuthorization 0
set proxyUser ""
set proxyPassword ""
set debug 0

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc loadConfigFile {fileName} {
    if { ![ file exists $fileName ] } {
        return
    }
    catch {
        set f [ open $fileName "r" ]
        fconfigure $f -encoding utf-8
        set data [ read $f ]
        close $f

        uplevel #0 $data
    }
}

proc loadConfig {} {
    global configDir

    loadConfigFile [ file join $configDir "config" ]
    loadConfigFile [ file join $configDir "userConfig" ]
}

proc loadAppLibs {} {
    global libDir
    global auto_path

    lappend auto_path $libDir

    package require gaa_lambda 1.0
    package require lorParser 1.0
    package require gaa_httpTools 1.0
    package require gaa_remoting 2.0
    package require gaa_logger 1.0

    namespace import ::gaa::lambda::*
}

proc errorProcCallback {err {extInfo ""}} {
    send tkLOR [ list errorProc $err $extInfo ]
}

proc bgerror {msg} {
    logger::log "bgerror: $msg"
    logger::log "bgerror extended info: $::errorInfo"
}

proc login {login password} {
    if [ catch {lor::login $login $password} ] {
        remoting::sendRemote -async tkLOR "loginCallback 0"
    } else {
        remoting::sendRemote -async tkLOR "loginCallback 1"
    }
}

############################################################################
#                                   MAIN                                   #
############################################################################

wm withdraw .

array set param [ ::cmdline::getoptions argv [ list \
    [ list configDir.arg  $configDir    "Config directory" ] \
    [ list libDir.arg     $libDir       "Library path" ] \
    [ list appId.arg      $appName      "Application ID" ] \
    [ list debug.arg      $debug        "Debug flag" ] \
] ]

if { $param(configDir) != "" } {
    set configDir $param(configDir)
}
if { $param(libDir) != "" } {
    set libDir $param(libDir)
}
set debug $param(debug)

loadConfig
loadAppLibs

if {$debug != "0"} {
    logger::configure $processId
}

set myId [ remoting::startServer $processId ]
logger::log "backend id: $myId"
remoting::sendRemote -async $appName [ list set backendId $myId ]

gaa::httpTools::init \
    -useragent      $param(appId) \
    -proxy          $useProxy \
    -autoproxy      $proxyAutoSelect \
    -proxyhost      $proxyHost \
    -proxyport      $proxyPort \
    -proxyauth      $proxyAuthorization \
    -proxyuser      $proxyUser \
    -proxypassword  $proxyPassword \
    -charset        "utf-8"
