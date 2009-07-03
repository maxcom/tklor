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

package provide gui_mailEditor 1.0

package require Tcl 8.4
package require Tk 8.4
package require tile 0.8
package require gaa_tileDialogs 1.0

namespace eval mailEditor {

namespace export \
    editMessage

set id 0

# editMessage   -   open mail editor
#
#   title   -   Window title.
#   letter  -   Mail message to edit.
#   buttons -   List of (id, text) pairs of possible buttons.
#   default -   Default button id. Will bw used on Ctrl-Return press.
#   command -   Command to execute on button press.
#               Two arguments will be passed: button id and modified message.
#
proc editMessage {title letter buttons default command} {
    variable id
    incr id

    set storage [ namespace current ]::storage$id
    global $storage
    array set $storage [ list \
        From            "" \
        To              "" \
        Subject         "" \
        body            "" \
        X-LOR-Pre       0 \
        X-LOR-AutoUrl   1 \
    ]
    foreach {header value} $letter {
        if [ info exists ${storage}($header) ] {
            set ${storage}($header) $value
        }
    }
    array set $storage [ list letter $letter ]

    set f [ toplevel .messagePostWindow$id ]
    wm withdraw $f
    wm title $f $title
 
    set w [ ttk::frame $f.headerFrame ]
    grid \
        [ ttk::label $w.labelFrom -text [ mc "From: " ] -anchor w ] \
        [ ttk::label $w.entryFrom -textvariable ${storage}(From) ] \
        -sticky we
    grid \
        [ ttk::label $w.labelTo -text [ mc "To: " ] -anchor w ] \
        [ ttk::label $w.entryTo -textvariable ${storage}(To) ] \
        -sticky we
    grid \
        [ ttk::label $w.labelSubject -text [ mc "Subject: " ] -anchor w ] \
        [ ttk::entry $w.entrySubject -textvariable ${storage}(Subject) ] \
        -sticky we
    grid columnconfigure $w 1 -weight 1
    grid $w -sticky nwse

    set w [ ttk::frame $f.textFrame ]
    set ww [ ttk::frame $w.textContainer ]
    grid \
        [ text $ww.text \
            -yscrollcommand "$ww.scroll set" \
            -height 15 \
            -wrap word \
            -undo true \
        ] \
        [ ttk::scrollbar $ww.scroll -command "$ww.text yview" ] \
        -sticky nswe
    $ww.text insert 0.0 [ set ${storage}(body) ]
    unset ${storage}(body)

    grid columnconfigure $ww 0 -weight 1
    grid rowconfigure $ww 0 -weight 1
    grid $ww -sticky nwse

    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 1 -weight 1
    grid $w -sticky nwse

    set w [ ttk::frame $f.optionsFrame ]
    grid \
        [ ttk::combobox $w.format \
            -state readonly \
            -values {"User line breaks w/quoting" "Preformatted text"} \
        ] \
        [ ttk::checkbutton $w.autoUrl \
            -text [ mc "Auto URL" ] \
            -variable ${storage}(X-LOR-AutoUrl)
        ] \
        -sticky we
    $w.format current [ set ${storage}(X-LOR-Pre) ]

    grid columnconfigure $w 0 -weight 1
    grid columnconfigure $w 1 -weight 1
    grid $w -sticky nwse

    set destroyScript [ list \
        [ namespace current ]::destroyWindow $f $storage \
    ]

    set btn ""
    foreach {bid title} $buttons {
        lappend btn [ list \
            -text $title \
            -command [ list \
                [ namespace current ]::processClick \
                $f $storage $bid $command \
            ] \
        ]
    }
    lappend btn [ list -text [ mc "Cancel" ] -command $destroyScript ]
    grid [ eval [ concat \
        [ list ::gaa::tileDialogs::buttonBox $f ] \
        $btn \
    ] ] -sticky nswe

    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 1 -weight 1

    wm deiconify $f
    wm protocol $f WM_DELETE_WINDOW $destroyScript
    bind $f <Escape> $destroyScript
    bind $f.textFrame.textContainer.text <Control-Return> "[ list \
        [ namespace current ]::processClick \
        $f $storage $default $command \
    ];break"

    focus $f.textFrame.textContainer.text
}

proc destroyWindow {w storage} {
    upvar #0 $storage st

    array unset st
    destroy $w
}

proc processClick {w storage button command} {
    upvar #0 $storage st

    set st(body) [ $w.textFrame.textContainer.text get 0.0 end ]
    set st(X-LOR-Pre) [ $w.optionsFrame.format current ]
    set st(X-LOR-Time) [ clock format \
        [ clock seconds ] -format {%d.%m.%Y %H:%M:%S} \
    ]

    set res ""
    set letter $st(letter)
    unset st(letter)
    foreach {header value} $letter {
        if [ info exists st($header) ] {
            lappend res $header $st($header)
            unset st($header)
        } else {
            lappend res $header $value
        }
    }
    foreach {header value} [ array get st ] {
        lappend res $header $value
    }
    array unset st

    uplevel #0 [ concat $command [ list $button $res ] ]
    destroy $w
}

}

