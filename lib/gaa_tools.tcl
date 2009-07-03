############################################################################
#    Copyright (C) 2008 by Alexander Galanin                               #
#    gaa.nnov@mail.ru                                                      #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
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

package provide gaa_tools 1.0

package require Tcl 8.4
package require Tk 8.4

namespace eval ::gaa {
namespace eval tools {

namespace export \
    generateUniqueWidgetId \
    generateUniqueVariable \
    generateUniqueId \
    centerToParent

set lastGeneratedIdSuffix 0

proc generateUniqueWidgetId {prefix} {
    return [ generateUniqueId $prefix [ list winfo exists ] ]
}

proc generateUniqueVariable {} {
    return [ generateUniqueId "::gaa_tempVar" [ list info exists ] ]
}

proc generateUniqueId {prefix script} {
    upvar #0 ::gaa::tools::lastGeneratedIdSuffix lastGeneratedIdSuffix

    set id $prefix
    while { [ eval [ concat $script [ list $id ] ] ] } {
        set id [ join [ list $prefix $lastGeneratedIdSuffix ] "" ]
        incr lastGeneratedIdSuffix
    }
    return $id
}

proc centerToParent {window parent} {
    catch {
        regexp -lineanchor {^(\d+)x(\d+)((?:\+|-)\d+)((?:\+|-)\d+)$} [ winfo geometry $parent ] md mw mh mx my
        regexp -lineanchor {^(\d+)x(\d+)((?:\+|-)\d+)((?:\+|-)\d+)$} [ winfo geometry $window ] d w h x y
        set x [ expr ( $mw - $w ) / 2  ]
        if { $x > "0" } {set x "+$x"}
        set y [ expr ( $mh - $h ) / 2  ]
        if { $y > "0" } {set y "+$y"}
        wm geometry $window [ join [ list $w "x" $h $x $y ] "" ]
    }
}

}
}
