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

package provide gaa_tileDialogs 1.3

package require Tcl 8.4
package require Tk 8.4
package require cmdline 1.2.5
package require tile 0.8
package require gaa_lambda 1.0
package require gaa_tools 1.0

namespace eval ::gaa {
namespace eval tileDialogs {

namespace export \
    tabbedOptionsDialog \
    onePageOptionsDialog \
    inputStringDialog \
    buttonBox

proc packOptionsItem {w name item type val opt} {
    if { $type != "check" } {
        pack [ ttk::label [ join [ list $name Label ] "" ] -text "$item:" ] -anchor w -fill x
    }
    switch -exact -- $type {
        check {
            pack [ ttk::checkbutton $name -text $item ] -anchor w -fill x
            global [ $name cget -variable ]
            set [ $name cget -variable ] $val
        }
        list {
            set f [ ttk::frame $name ]
            set ff [ ttk::frame $f.f ]
            set addScript [ lindex $opt 1 ]
            set modifyScript [ lindex $opt 2 ]
            set opt [ lindex $opt 0 ]

            set v [ ttk::treeview $ff.list -yscrollcommand "$ff.scroll set" -columns [ lrange $opt 1 end ] -displaycolumns [ lrange $opt 1 end ] ]
            $v heading #0 -text [ lindex $opt 0 ] -anchor w
            foreach col [ lrange $opt 1 end ] {
                $v heading $col -text $col -anchor w
            }
            foreach item $val {
                $v insert "" end -text [ lindex $item 0 ] -values [ lrange $item 1 end ]
            }

            pack [ ttk::scrollbar "$ff.scroll" -command "$v yview" ] -side right -fill y
            pack $v -anchor w -fill both
            pack $ff -anchor w -fill both
            pack $f -anchor w -fill both
            bind $v <Double-Button-1> [ concat $modifyScript [ list $v $w ] ]
            pack [ buttonBox $name \
                [ list -text "Add..." -command [ concat $addScript [ list $v $w ] ] ] \
                [ list -text "Modify..." -command [ concat $modifyScript [ list $v $w ] ] ] \
                [ list -text "Remove" -command [ ::gaa::lambda::lambda {w} {
                        foreach item [ $w selection ] {
                            $w delete $item
                        }
                    } $v ] \
                ] \
                [ list -text "Move up" -command [ ::gaa::lambda::lambda {w} {
                        set item [ $w focus ]
                        if { $item == "" } return
                        set parent [ $w parent $item ]
                        set childs [ $w children $parent ]
                        set pos [ lsearch -exact $childs $item ]
                        if { $pos > 0 } {
                            lset childs $pos [ lindex $childs [ expr $pos - 1 ] ]
                            lset childs [ expr $pos - 1 ] $item
                            $w children $parent $childs
                        }
                    } $v ] \
                ] \
                [ list -text "Move down" -command [ ::gaa::lambda::lambda {w} {
                        set item [ $w focus ]
                        if { $item == "" } return
                        set parent [ $w parent $item ]
                        set childs [ $w children $parent ]
                        set pos [ lsearch -exact $childs $item ]
                        if { $pos + 1 < [ llength $childs ] } {
                            lset childs $pos [ lindex $childs [ expr $pos + 1 ] ]
                            lset childs [ expr $pos + 1 ] $item
                            $w children $parent $childs
                        }
                    } $v ] \
                ] \
            ] -fill x -side bottom
        }
        selectList {
            set f [ ttk::frame $name ]
            set v [ ttk::treeview $f.list -yscrollcommand "$f.scroll set" -selectmode none ]
            pack [ ttk::scrollbar $f.scroll -command "$v yview" ] -side right -fill y
            pack $v -anchor w -fill both
            pack $f -anchor w -fill both

            foreach {id text} $opt {
                $v insert {} end -id $id -text $text
                if { [ lsearch $val $id ] != -1 } {
                    $v selection add $id
                }
            }
            bind $v <space> [ ::gaa::lambda::lambda {v} {
                set cur [ $v focus ]
                if {$cur != ""} {
                   $v selection toggle $cur
                }
            } $v ]
        }
        editableCombo {
            pack [ ttk::combobox $name -values $opt ] -anchor w -fill x
            $name set $val
        }
        readOnlyCombo {
            pack [ ttk::combobox $name -values $opt -state readonly ] -anchor w -fill x
            $name set $val
        }
        password {
            pack [ ttk::entry $name -show * ] -anchor w -fill x
            $name insert end $val
        }
        color {
            pack [ ttk::button $name -text $val -command [ ::gaa::lambda::lambda {parent w} {
                if [ catch {set color [ tk_chooseColor -initialcolor [ $w cget -text ] -parent $parent ]} ] {
                    set color [ tk_chooseColor -parent $parent ]
                }
                if { $color != "" } {
                    $w configure -text $color
                }
            } $w $name ] ] -anchor w -fill x
        }
        font {
            pack [ ttk::button $name -text $val -command [ ::gaa::lambda::lambda {parent w} {
                set val [ $w cget -text ]
                array set ff $val
                set names [ array names ff ]
                foreach param {family size weight slant underline overstrike} {
                    if { [ lsearch -exact $names "-$param" ] == -1 } {
                        array set ff [ list "-$param" "" ]
                    }
                }
                onePageOptionsDialog \
                    -title "Choose font" \
                    -options [ list \
                        "Family" editableCombo family $ff(-family) { lsort [ font families ] } \
                        "Size" string size $ff(-size) "" \
                        "Weight" readOnlyCombo weight $ff(-weight) { list "" normal bold } \
                        "Slant" readOnlyCombo slant $ff(-slant) { list "" roman italic } \
                        "Underline" check underline $ff(-underline) "" \
                        "Overstrike" check overstrike $ff(-overstrike) "" \
                    ] \
                    -script [ lambda {w vals} {
                        set s ""
                        foreach {p t} $vals {
                            if { $t != "" } {
                                lappend s [ list "-$p" $t ]
                            }
                        }
                        set res [ join $s ]
                        if { $res == "" } {
                            set res [ font actual system ]
                        }
                        $w configure -text $res
                    } $w ] \
                    -parent $w
            } $w $name ] ] -anchor w -fill x
        }
        string -
        default {
            pack [ ttk::entry $name ] -anchor w -fill x
            $name insert end $val
        }
    }
}

proc getOptionsItemValue {name type} {
    switch -exact -- $type {
        check {
            global [ $name cget -variable ]
            return [ set [ $name cget -variable ] ]
        }
        list {
            set v $name.f.list
            set res ""
            foreach item [ $v children "" ] {
                set l [ concat [ list [ $v item $item -text ] ] [ $v item $item -values ] ]
                lappend res $l
            }
            return $res
        }
        selectList {
            return [ $name.list selection ]
        }
        font -
        color {
            return [ $name cget -text ]
        }
        editableCombo -
        readOnlyCombo -
        password -
        string -
        default {
            return [ $name get ]
        }
    }
}

proc tabbedOptionsDialog {args} {
    array set param [ ::cmdline::getoptions args {
        {title.arg      "Options" "Window title"}
        {options.arg    ""        "Options list in format {category {title type id value opt}}"}
        {pageScript.arg ""        "Script to execute on each page"}
        {script.arg     ""        "Script to execute on OK click"}
        {parent.arg     ""        "Parent window"}
    } ]
    foreach item {options pageScript script } {
        if { $param($item) == "" } {
            error "Parameter -$item is mandatory!"
        }
    }

    set f [ modalDialogCreate -title $param(title) -parent $param(parent) ]
    set d $f.client

    set notebook [ ttk::notebook $d.notebook ]
    grid $notebook -sticky nswe
    grid rowconfigure $d 0 -weight 1
    grid columnconfigure $d 0 -weight 1

    set n 0
    set okList ""
    foreach {category optList} $param(options) {
        set page [ ttk::frame "$notebook.page$n" ]

        set genList ""
        set fetchList ""
        foreach {item type var value opt} $optList {
            lappend genList $item $type $value $opt
            lappend fetchList $item $type $var $opt
        }

        lappend okList [ ::gaa::lambda::lambda {optList page ws script} {
                set vals [ ::gaa::tileDialogs::fetchOptionsFrameValues $optList $page $ws ]
                set var ""
                for {set i 0} {$i < [ llength $vals ]} {incr i} {
                    lappend var [ lindex $optList [ expr $i*4+2 ] ] [ lindex $vals $i ]
                }
                eval [ concat $script [ list $var ] ]
            } $fetchList $page [ generateOptionsFrame $f $genList $page ] $param(pageScript) \
        ]

        $notebook add $page -sticky nswe -text $category
        incr n
    }
    lappend okList $param(script)
    modalDialogConfigure $f [ join $okList ";" ]
}

proc generateOptionsFrame {d optList page} {
    set ws ""
    set i 0

    foreach {item type val opt} $optList {
        set f [ ttk::frame "$page.item$i" ]
        lappend ws $f
        packOptionsItem $d $f.value $item $type $val [ eval $opt ]
        pack $f -anchor w -fill both
        incr i
    }
    return $ws
}

proc fetchOptionsFrameValues {optList page ws} {
    set result ""
    set i 0
    foreach {item type var opt} $optList {
        lappend result [ getOptionsItemValue [ lindex $ws $i ].value $type ]
        incr i
    }
    return $result
}

proc onePageOptionsDialog {args} {
    array set param [ ::cmdline::getoptions args {
        {title.arg      "Options" "Window title"}
        {options.arg    ""        "Options list in format {title type id value opt}"}
        {script.arg     ""        "Script to execute on OK click"}
        {parent.arg     ""        "Parent window"}
    } ]
    foreach item {options script } {
        if { $param($item) == "" } {
            error "Parameter -$item is mandatory!"
        }
    }

    set f [ modalDialogCreate -title $param(title) -parent $param(parent) ]
    set d $f.client
    set page [ ttk::frame $d.optFrame ]
    pack $page -fill both

    set n 0
    set genList ""
    set fetchList ""
    foreach {item type var value opt} $param(options) {
        lappend genList $item $type $value $opt
        lappend fetchList $item $type $var $opt
    }
    modalDialogConfigure $f [ ::gaa::lambda::lambda {optList page ws script} {
            set vals [ ::gaa::tileDialogs::fetchOptionsFrameValues $optList $page $ws ]
            set var ""
            for {set i 0} {$i < [ llength $vals ]} {incr i} {
                lappend var [ lindex $optList [ expr $i*4+2 ] ] [ lindex $vals $i ]
            }
            eval [ concat $script [ list $var ] ]
        } $fetchList $page [ generateOptionsFrame $d $genList $page ] $param(script) ]
}

proc buttonBox {parent args} {
    set f [ ttk::frame $parent.buttonBox -padding 2 ]
    set b ""
    set i 0
    foreach p $args {
        set id [ join [ list $f ".button" $i "Frame" ] "" ]
        ttk::frame $id -padding 2
        eval [ concat [ list ttk::button $id.button ] $p ]
        pack $id.button
        set b [ concat [ list $id ] $b ]
        incr i
    }
    eval "pack [ join $b ] -side right"
    if { [ llength $args ] > 0 } {
        focus $f.button0Frame.button
    }
    return $f
}

proc inputStringDialog {args} {
    array set param [ ::cmdline::getoptions args {
        {title.arg      "Input string"  "Window title"}
        {label.arg      "Enter string"  "Entry label"}
        {script.arg     ""              "Script to execute on OK click"}
        {default.arg    ""              "Default parameter value"}
        {parent.arg     ""              "Parent window"}
    } ]
    if { $param(script) == "" } {
        error "Parameter -script is mandatory!"
    }

    set f [ modalDialogCreate -title $param(title) -sizeY 0 -parent $param(parent) ]
    set ff $f.client
    pack [ ttk::label $ff.label -text "$param(label): " ] -fill x
    pack [ ttk::entry $ff.entry ] -fill x
    $ff.entry insert end $param(default)
    $ff.entry selection range 0 end

    set script [ ::gaa::lambda::lambda {f script} {
            eval [ concat $script [ list [ $f.entry get ] ] ]
        } $ff $param(script) ]

    modalDialogConfigure $f $script

    focus $ff.entry
}

proc modalDialogCreate {args} {
    array set param [ ::cmdline::getoptions args {
        {title.arg  "Modal dialog"  "Window title"}
        {sizeX.arg  1               "Resizable on x"}
        {sizeY.arg  1               "Resizable on y"}
        {parent.arg ""              "Parent window"}
    } ]

    set f [ gaa::tools::generateUniqueWidgetId ".modalDialog" ]
    toplevel $f -class Dialog
    wm withdraw $f
    if {$param(parent) ne ""} {
        wm transient $f $param(parent)
    }
    grid [ ttk::frame $f.client ] -sticky nswe

    wm resizable $f $param(sizeX) $param(sizeY)
    wm title $f $param(title)

    return $f
}

proc modalDialogConfigure {f script} {
    set okScript [ join [ list \
        $script \
        [ list destroy $f ] \
    ] ";" ]
    set cancelScript [ join [ list \
        [ list destroy $f ] \
    ] ";" ]

    grid [ buttonBox $f \
        [ list -text "OK" -command $okScript ] \
        [ list -text "Cancel" -command $cancelScript ] \
    ] -sticky nswe

    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 0 -weight 1

    wm deiconify $f
    update
    wm protocol $f WM_DELETE_WINDOW $cancelScript

    bind $f <Return> $okScript
    bind $f <Escape> $cancelScript
}

}
}
