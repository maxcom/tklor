#!/bin/sh
############################################################################
#    Copyright (C) 2008 by Alexander Galanin   #
#    gaa.nnov@mail.ru   #
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
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# \
exec wish "$0" "$@"

package require Tk
package require tile
package require http 2.0

set appName "tkLOR"
set appVersion "0.1.0"

#---------------- debug start --------------
set currentTopic 2412284
set ignoreList {HEBECTb_KTO adminchik anonymous}
#---------------- debug end ----------------

set lorUrl "www.linux.org.ru"

array set fontPart {
    none ""
    item "-family Sans"
    unread "-weight bold"
    child "-weight bold -slant italic"
    ignored "-overstrike 1"
}

set htmlRenderer "local"
if { [ string equal -length 3 $tk_patchLevel "8.4" ] && ! [catch {package require Iwidgets}] } {
    set htmlRenderer "iwidgets"
}

#loadConfig

set messageWidget ""
set topicWidget ""
set topicTextWidget ""

set currentHeader ""
set currentNick ""

set topicNick ""
set topicHeader ""

array set itemValuesMap {
    header 0
    time 1
    msg 2
    unread 3
    unreadChild 4
    parent 5
    parentNick 6
}

############################################################################
#                                 FUNCTIONS                                #
############################################################################
proc initMenu {} {
    menu .menu -type menubar
    .menu add cascade -label "Topic" -menu .menu.file
    .menu add cascade -label "Edit" -menu .menu.edit
    .menu add cascade -label "Help" -menu .menu.help

    menu .menu.file
    .menu.file add command -label "Add..." -command addTopic
    .menu.file add separator
    .menu.file add command -label "Exit" -command exitProc

    menu .menu.edit
    .menu.edit add command -label "Cut" -command editCut
    .menu.edit add command -label "Copy" -command editCopy
    .menu.edit add command -label "Paste" -command editPaste

    menu .menu.help
    .menu.help add command -label "About" -command helpAbout

    .  configure -menu .menu
}

proc initAllTopicsTree {} {
    set tree [ ttk::treeview .allTopicsTree ]
    return $tree
}

proc initTopicText {} {
    global topicTextWidget
    global htmlRenderer

    set mf [ frame .topicTextFrame ]
    pack [ ttk::label $mf.header -textvariable topicHeader -font "-size 14 -weight bold" ] -fill x

    set f [ frame $mf.textFrame ]
    switch -exact $htmlRenderer {
        "local" {
            set topicTextWidget [ text $f.msg -state disabled -yscrollcommand "$f.scroll set" -setgrid true -wrap word -height 15 ]
            ttk::scrollbar $f.scroll -command "$topicTextWidget yview"
            pack $f.scroll -side right -fill y
            pack $topicTextWidget -expand yes -fill both
        }
        "iwidgets" {
            set topicTextWidget [ iwidgets::scrolledhtml $f.msg -state disabled -height 15 ]
            pack $topicTextWidget -expand yes -fill both
        }
    }
    pack $f -expand yes -fill both

    return $mf
}

proc initTopicTree {} {
    global topicWidget

    set f [ frame .topicFrame ]
    set topicWidget [ ttk::treeview $f.topicTree -columns {title time message unread unreadChilds parent parentNick} -displaycolumns {title time} -yscrollcommand "$f.scroll set" ]
    $topicWidget heading #0 -text "Nick" -anchor w
    $topicWidget heading title -text "Title" -anchor w
    $topicWidget heading time -text "Time" -anchor w

    configureTags $topicWidget

    bind $topicWidget <<TreeviewSelect>> "messageClick %W"

    ttk::scrollbar $f.scroll -command "$topicWidget yview"
    pack $f.scroll -side right -fill y
    pack $topicWidget -expand yes -fill both

    return $f
}

proc initMessageWidget {} {
    global messageWidget
    global htmlRenderer
    global currentHeader currentNick currentPrevNick currentTime

    set mf [ frame .msgFrame ]

    set width 10

    set f [ frame $mf.header ]
    pack [ ttk::label $f.label -text "Header: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentHeader ] -side left
    pack $f -fill x

    set f [ frame $mf.nick ]
    pack [ ttk::label $f.label -text "From: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentNick ] -side left
    pack $f -fill x

    set f [ frame $mf.prevNick ]
    pack [ ttk::label $f.label -text "To: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentPrevNick ] -side left
    pack $f -fill x

    set f [ frame $mf.time ]
    pack [ ttk::label $f.label -text "Time: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentTime ] -side left
    pack $f -fill x

    switch -exact $htmlRenderer {
        "local" {
            set messageWidget [ text $mf.msg -state disabled -yscrollcommand "$mf.scroll set" -setgrid true -wrap word -height 15 ]
            ttk::scrollbar $mf.scroll -command "$messageWidget yview"
            pack $mf.scroll -side right -fill y
            pack $messageWidget -expand yes -fill both
        }
        "iwidgets" {
            set messageWidget [ iwidgets::scrolledhtml $mf.msg -state disabled -height 15 ]
            pack $messageWidget -expand yes -fill both
        }
    }

    return $mf
}

proc initMainWindow {} {
    global appName

    wm protocol . WM_DELETE_WINDOW exitProc
    wm title . $appName

    ttk::panedwindow .horPaned -orient horizontal
    pack .horPaned -fill both -expand 1

    .horPaned add [ initAllTopicsTree ]

    ttk::panedwindow .vertPaned -orient vertical
    .horPaned add .vertPaned

    .vertPaned add [ initTopicText ] -weight 10
    .vertPaned add [ initTopicTree ] -weight 0
    .vertPaned add [ initMessageWidget ] -weight 10
}

proc helpAbout {} {
    global appName appVersion

    tk_messageBox -title "About $appName" -message "$appName $appVersion" -detail "Client for reading linux.org.ru written on Tcl/Tk/Tile.\nCopyright (c) 2008 Alexander Galanin (gaa at linux.org.ru)" -parent . -type ok
}

proc exitProc {} {
    global appName

    if { [ tk_messageBox -title $appName -message "Are you really want to quit?" -type yesno -icon question -default yes ] == yes } {
        exit
    }
}

proc renderHtml {w msg} {
    global htmlRenderer

    switch $htmlRenderer {
        "local" {
            $w configure -state normal
            $w delete 0.0 end
            $w insert 0.0 $msg
            $w yview 0.0
            $w configure -state disabled
        }
        "iwidgets" {
            $w render $msg
        }
    }
}

proc updateTopicText {msg} {
    global topicTextWidget

    renderHtml $topicTextWidget $msg
}

proc updateMessage {item} {
    global messageWidget
    global currentHeader currentNick currentPrevNick currentTime

    set msg [ getItemValue $item msg ]
    set currentHeader [ getItemValue $item header ]
    set currentNick [ getItemValue $item nick ]
    set currentPrevNick [ getItemValue $item parentNick ]
    set currentTime [ getItemValue $item time ]

    renderHtml $messageWidget $msg
}

proc configureTags {w} {
    global fontPart

    foreach a { none unread } {
        foreach b { none child } {
            foreach c { none ignored } {
                set id [ join [list "item" $a $b $c ] "_" ]
                regsub -all {_none} $id "" id

                $w tag configure $id -font [ join [ list $fontPart(item) $fontPart($a) $fontPart($b) $fontPart($c) ] " " ]
            }
        }
    }
}

proc setTopic {topic} {
    global currentTopic lorUrl appName

    set curentTopic $topic
    set err 1
    set errStr ""
    set url "http://pingu3/lor.html"
    #set url "http://$lorUrl/view-message.jsp?msgid=$topic&page=-1"

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            parseTopicText [ ::http::data $token ]
            parsePage [ ::http::data $token ]
            set err 0
        } else {
            set errStr [ ::http::code $token ]
        }
        ::http::cleanup $token
    }
    if $err {
        tk_messageBox -title "$appName error" -message "Unable to contact LOR" -detail $errStr -parent . -type ok -icon error
    }
}

proc parseTopicText {data} {
    global topicNick topicHeader

    if [ regexp -- {<div class=msg><h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>(\w+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w]+">\*</a>\) \(([^)]+)\)<br><i>[^ ]+ (\w+) \(<a href="whois.jsp\?nick=\w+">\*</a>\) ([^<]+)</i></div><div class=reply>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        #puts "matched-topic: {$header} {$msg} {$nick} {$time} {$approver} {$approveTime}"
        updateTopicText $msg
        set topicNick $nick
        set topicHeader $header
    } else {
        updateTopicText "Unable to parse topic text :("
        set topicNick ""
        set topicHeader ""
    }
}

proc parsePage {data} {
    global topicWidget

    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+&amp;lastmod=\d+(?:&amp;page=\d+){0,1}#(\d+)">[^<]*</a> \w+ (\w+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*)<div class=sign>(\w+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w]+">\*</a>\) \(([^)]+)\)</div><div class=reply>\[<a href="add_comment.jsp\?topic=\d+&amp;replyto=\d+">[^<]+</a>} $message dummy2 prev prevNick id header msg nick time ] {
            #puts "matched: {$prev} {$prevNick} {$id} {$header} {\$msg} {$nick} {$time}"

            $topicWidget insert $prev end -id $id -text $nick -values [ list $header $time $msg 1 0 $prev $prevNick ]
            addUnreadChild $prev
            updateItemState $id
#            after 100
        }
    }
}

proc getItemValue {item value} {
    global topicWidget itemValuesMap
    if { $value == "nick" } {
        return [ $topicWidget item $item -text ]
    } else {
        set val [ $topicWidget item $item -values ]
        return [ lindex $val $itemValuesMap($value) ]
    }
}

proc setItemValue {item valueName value} {
    global topicWidget itemValuesMap
    set val [ $topicWidget item $item -values ]
    set val [ lreplace $val $itemValuesMap($valueName) $itemValuesMap($valueName) $value ]
    $topicWidget item $item -values $val
}

proc messageClick {tree} {
    global topicWidget

    set item [ $tree focus ]
    updateMessage $item
    if [ getItemValue $item unread ] {
        setItemValue $item unread 0
        addUnreadChild [ getItemValue $item parent ] -1
    }
    updateItemState $item
}

proc addUnreadChild {item {count 1}} {
    if { $item != "" } {
        setItemValue $item unreadChild [ expr [ getItemValue $item unreadChild ] + $count ]
        if { [ getItemValue $item parent ] != "" } {
            addUnreadChild [ getItemValue $item parent ] $count
        }
        updateItemState $item
    }
}

proc updateItemState {item} {
    global topicWidget
    global ignoreList

    set tag "item"
    if [ getItemValue $item unread ] {
        append tag "_unread"
    }
    if [ getItemValue $item unreadChild ] {
        append tag "_child"
    }
    if { [ lsearch -exact $ignoreList [ getItemValue $item nick ] ] != -1 } {
        append tag "_ignored"
    }
    $topicWidget item $item -tags [ list $tag ]
}

proc addTopic {} {
    #TODO
}

proc initHttp {} {
    global appName appVersion

    ::http::config -useragent "$appName $appVersion"
    set ::http::defaultCharset "utf-8"
}

############################################################################
#                                   MAIN                                   #
############################################################################

initMenu
initMainWindow
initHttp

setTopic $currentTopic
