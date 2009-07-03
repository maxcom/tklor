#!/bin/sh
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
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# \
exec wish "$0" "$@"

package require Tk
package require tile
package require http 2.0

set appName "tkLOR"
set appVersion "0.1.0"
set appId "$appName $appVersion $tcl_platform(os) $tcl_platform(osVersion) $tcl_platform(machine)"

set configDir [ file join $::env(HOME) ".$appName" ]
set threadSubDir "threads"

#---------------- debug start --------------
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

############################################################################
#                                 VARIABLES                                #
############################################################################

set messageWidget ""
set allTopicsWidget ""
set topicWidget ""
set topicTextWidget ""

set currentHeader ""
set currentNick ""
set currentTopic ""

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

set forumGroups {
    126     General
    1339    Desktop
    1340    Admin
    1342    Linux-install
    4066    Development
    4068    Linux-org-ru
    7300    Security
    8403    Linux-hardware
    8404    Talks
    9326    Job
    10161   Games
    19109   Web-development
}

#------------------------------
set forumGroups {
    4068    Linux-org-ru
    8404    Talks
}
#------------------------------

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc initMenu {} {
    menu .menu -type menubar
    .menu add cascade -label "Topic" -menu .menu.file
    .menu add cascade -label "Help" -menu .menu.help

    menu .menu.file -tearoff 0
    .menu.file add command -label "Add..." -command addTopic
    .menu.file add command -label "Refresh" -command refreshTopic
    .menu.file add separator
    .menu.file add command -label "Exit" -command exitProc

    menu .menu.help -tearoff 0
    .menu.help add command -label "About" -command helpAbout

    .  configure -menu .menu
}

proc initAllTopicsTree {} {
    global allTopicsWidget
    global forumGroups

    set allTopicsWidget [ ttk::treeview .allTopicsTree -columns {unread unreadChild} -displaycolumns {unreadChild} ]
    configureTags $allTopicsWidget
    $allTopicsWidget heading #0 -text "Title" -anchor w
    $allTopicsWidget heading unreadChild -text "Messages" -anchor w

    $allTopicsWidget insert "" end -id news -text "News" -values [ list 0 0 ]

    $allTopicsWidget insert "" end -id forum -text "Forum" -values [ list 0 0 ]
    foreach {id title} $forumGroups {
        $allTopicsWidget insert forum end -id "forum$id" -text $title -values [ list 0 0 ]
    }

    $allTopicsWidget insert "" end -id favorites -text "Favorites" -values [ list 0 0 ]

    return $allTopicsWidget
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
    set topicWidget [ ttk::treeview $f.topicTree -columns {nick header time msg unread unreadChild parent parentNick} -displaycolumns {header time} -xscrollcommand "$f.scrollx set" -yscrollcommand "$f.scrolly set" ]
    $topicWidget heading #0 -text "Nick" -anchor w
    $topicWidget heading header -text "Title" -anchor w
    $topicWidget heading time -text "Time" -anchor w

    configureTags $topicWidget

    bind $topicWidget <<TreeviewSelect>> "messageClick %W"

    ttk::scrollbar $f.scrollx -command "$topicWidget xview" -orient horizontal
    ttk::scrollbar $f.scrolly -command "$topicWidget yview"
    pack $f.scrollx -side bottom -fill x
    pack $f.scrolly -side right -fill y
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

    .vertPaned add [ initTopicText ] -weight 3
    .vertPaned add [ initTopicTree ] -weight 1
    .vertPaned add [ initMessageWidget ] -weight 3
}

proc helpAbout {} {
    global appName appVersion

    tk_messageBox -title "About $appName" -message "$appName $appVersion\nClient for reading linux.org.ru written on Tcl/Tk/Tile.\nCopyright (c) 2008 Alexander Galanin (gaa at linux.org.ru)\nLicense: GPLv3" -parent . -type ok
}

proc exitProc {} {
    global appName
    global currentTopic

    if { [ tk_messageBox -title $appName -message "Are you really want to quit?" -type yesno -icon question -default yes ] == yes } {
        saveTopicToCache $currentTopic
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

proc updateTopicText {header msg} {
    global topicTextWidget topicHeader

    renderHtml $topicTextWidget $msg
    set topicHeader $header
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

    startWait

    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    set currentTopic $topic
    set err 1
    set errStr ""
    set url "http://pingu/lor.html"
    #set url "http://$lorUrl/view-message.jsp?msgid=$topic&page=-1"

    loadTopicTextFromCache $topic
    loadCachedMessages $topic

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            parseTopicText $topic [ ::http::data $token ]
            parsePage $topic [ ::http::data $token ]
            set err 0
        } else {
            set errStr [ ::http::code $token ]
        }
        ::http::cleanup $token
    }
    if $err {
        tk_messageBox -title "$appName error" -message "Unable to contact LOR\n$errStr" -parent . -type ok -icon error
    }
    stopWait
}

proc parseTopicText {topic data} {
    global topicNick topicHeader

    if [ regexp -- {<div class=msg><h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i></div><div class=reply>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        set topicText $msg
        set topicNick $nick
        set topicHeader $header
        saveTopicTextToCache $topic $header $topicText $nick $time $approver $approveTime
    } else {
        set topicText "Unable to parse topic text :("
        set topicNick ""
        set topicHeader ""
        saveTopicTextToCache $topic "" $topicText "" "" "" ""
    }
    updateTopicText $topicHeader $topicText
}

proc parsePage {topic data} {
    global topicWidget

    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+&amp;lastmod=\d+(?:&amp;page=\d+){0,1}#(\d+)">[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div><div class=reply>\[<a href="add_comment.jsp\?topic=\d+&amp;replyto=\d+">[^<]+</a>} $message dummy2 parent parentNick id header msg nick time ] {
            if { ! [ $topicWidget exists $id ] } {
                $topicWidget insert $parent end -id $id -text $nick
                foreach i {nick header time msg parent parentNick} {
                    setItemValue $id $i [ set $i ]
                }
                setItemValue $id unread 1
                setItemValue $id unreadChild 0
                addUnreadChild $parent
                updateItemState $id
            }
        }
    }
}

proc getItemValue {item valueName} {
    global topicWidget itemValuesMap
    set val [ $topicWidget item $item -values ]
    set pos [ lsearch -exact [ $topicWidget cget -columns ] $valueName ]
    return [ lindex $val $pos ]
}

proc setItemValue {item valueName value} {
    global topicWidget itemValuesMap
    set val [ $topicWidget item $item -values ]
    if { $val == "" } {
        set val [ $topicWidget cget -columns ]
    }
    set pos [ lsearch -exact [ $topicWidget cget -columns ] $valueName ]
    lset val $pos $value
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

proc refreshTopic {} {
    global currentTopic

    if { $currentTopic != "" } {
        setTopic $currentTopic
    }
}

proc initHttp {} {
    global appId

    ::http::config -useragent "$appId"
    set ::http::defaultCharset "utf-8"
}

proc initDirs {} {
    global appName configDir threadSubDir

    file mkdir $configDir
    file mkdir [ file join $configDir $threadSubDir ]
}

proc saveTopicTextToCache {topic header text nick time approver approveTime} {
    global appName
    global configDir threadSubDir

    set f [ open [ file join $configDir $threadSubDir [ join [ list $topic ".topic" ] "" ] ] "w+" ]
    puts $f "From $nick"
    puts $f "Subject: $header"
    puts $f "X-LOR-Time: $time"
    puts $f "X-LOR-Approver: $approver"
    puts $f "X-LOR-Approve-Time: $approveTime"
    puts $f ""
    foreach line [ split $text "\n" ] {
        if [ string equal -length 5 $line "From " ] {
            puts $f ">$line"
        } else {
            puts $f $line
        }
    }
    close $f
}

proc parseMbox {fileName} {
    set res ""

    set f [ open $fileName "r" ]
    while { [ gets $f s ] >=0 } {
        if [ regexp -lineanchor -- {^From ([\w-]+)$} $s dummy nick ] {
            break
        }
    }
    if [ eof $f ] {
        return ""
    }
    while { ! [eof $f ] } {
        set cur ""
        lappend cur "From" $nick

        while { [ gets $f s ] >=0 } {
            if { $s == "" } {
                break
            }
            if [ regexp -lineanchor -- {^([\w-]+): (.+)$} $s dummy tag val ] {
                lappend cur $tag $val
            }
        }

        set body ""
        while { [ gets $f s ] >=0 } {
            if [ regexp -lineanchor -- {^From ([\w-]+)$} $s dummy nick ] {
                break
            } else {
                if [ string equal -length 6 $s ">From " ] {
                    set s [ string trimleft $s ">" ]
                }
                append body "$s\n"
            }
        }
        lappend cur "body" [ string trimright $body "\n" ]

        lappend res $cur
    }
    close $f

    return $res
}

proc loadTopicTextFromCache {topic} {
    global appName
    global configDir threadSubDir

    updateTopicText "" ""
    catch {
        array set res [ lindex [ parseMbox [ file join $configDir $threadSubDir [ join [ list $topic "_text" ] "" ] ] ] 0 ]
        updateTopicText $res(Subject) $res(body)
    }
}

proc saveMessage {topic id header text nick time replyTo replyToId unread} {
    global appName
    global configDir threadSubDir

    set f [ open [ file join $configDir $threadSubDir $topic ] "a" ]
    puts $f "From $nick"
    puts $f "Subject: $header"
    puts $f "X-LOR-Time: $time"
    puts $f "X-LOR-Id: $id"
    puts $f "X-LOR-Unread: $unread"
    if { $replyTo != "" } {
        puts $f "To: $replyTo"
        puts $f "X-LOR-ReplyTo-Id: $replyToId"
    }
    puts $f ""

    foreach line [ split $text "\n" ] {
        if [ string equal -length 5 $line "From " ] {
            puts $f ">$line"
        } else {
            puts $f $line
        }
    }
    puts $f ""
    close $f
}

proc loadCachedMessages {topic} {
    global appName
    global configDir threadSubDir
    global topicWidget

    catch {
    foreach letter [ parseMbox [ file join $configDir $threadSubDir $topic ] ] {
        array set res $letter
        catch {
            if { [ lsearch -exact [ array names res ] "To" ] != -1 } {
                set parentNick $res(To)
                set parent $res(X-LOR-ReplyTo-Id)
            } else {
                set parentNick ""
                set parent ""
            }
            set id $res(X-LOR-Id)
            set nick $res(From)
            set header $res(Subject)
            set time $res(X-LOR-Time)
            set msg $res(body)
            set unread $res(X-LOR-Unread)
            puts "$id $unread"

            $topicWidget insert $parent end -id $id -text $nick
            foreach i {nick header time msg parent parentNick unread} {
                setItemValue $id $i [ set $i ]
            }
            setItemValue $id unreadChild 0
            if $unread {
                addUnreadChild $parent
            }
            updateItemState $id
        }
        array unset res
    }
    }
}

proc clearDiskCache {topic} {
    global appName
    global configDir threadSubDir

    set f [ open [ file join $configDir $threadSubDir $topic ] "w+" ]
    close $f
}

proc saveTopicRecursive {topic item} {
    global topicWidget

    foreach id [ $topicWidget children $item ] {
        saveMessage $topic $id [ getItemValue $id header ] [ getItemValue $id msg ] [ getItemValue $id nick ] [ getItemValue $id time ] [ getItemValue $id parentNick ] [ getItemValue $id parent ] [ getItemValue $id unread ]
        saveTopicRecursive $topic $id
    }
}

proc saveTopicToCache {topic} {
    startWait
    if { $topic != "" } {
        clearDiskCache $topic
        saveTopicRecursive $topic ""
    }
    stopWait
}

proc processArgv {} {
    global argv

    foreach arg $argv {
        if [ regexp -lineanchor -- {^-(.+)=(.*)$} $arg dummy param value ] {
            uplevel #0 "set {$param} {$value}"
        }
    }
}

proc startWait {} {
    . configure -cursor clock
}

proc stopWait {} {
    . configure -cursor ""
}

proc loadConfig {} {
    # TODO
}

proc updateTopicList {{section ""}} {
    global forumGroups

    if {$section == "" } {
        updateTopicList news
        foreach {id title} $forumGroups {
            updateTopicList "forum$id"
        }
        return
    }

    switch -glob -- $section {
        news {
            
        }
        forum* {
            parseForum [ string trimleft $section "forum" ]
        }
        default {
            
        }
    }
}

proc parseForum {forum} {
    global lorUrl

    startWait

    set url "http://$lorUrl/group.jsp?group=$forum"
    set url "http://pingu/lor-group.html"
    set err 0

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            parseTopicList $forum [ ::http::data $token ]
            set err 0
        } else {
            set errStr [ ::http::code $token ]
        }
        ::http::cleanup $token
    }
    if $err {
        tk_messageBox -title "$appName error" -message "Unable to contact LOR\n$errStr" -parent . -type ok -icon error
    }

    stopWait
}

proc parseTopicList {forum data} {
    global allTopicsWidget

    foreach {dummy id header nick} [ regexp -all -inline -- {<tr><td><a href="view-message.jsp\?msgid=(\d+)(?:&amp;lastmod=\d+){0,1}" rev=contents>([^<]*)</a>(?:&nbsp;\(стр\.(?: <a href="view-message.jsp\?msgid=\d+&amp;lastmod=\d+&amp;page=\d+">\d+</a>)+\)){0,1} \(([\w-]+)\)</td><td align=center>(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)</td></tr>} $data ] {
        if { $id != "" } {
            catch {
                $allTopicsWidget insert "forum$forum" end -id $id -text $header -values [ list 0 0 ]
            }
        }
        #addUnreadChild $prev
        #updateItemState $id
    }
    $allTopicsWidget see "forum$forum"
}

############################################################################
#                                   MAIN                                   #
############################################################################

processArgv
loadConfig

initDirs

initMenu
initMainWindow
initHttp

updateTopicList

setTopic 2412284
#setTopic 2418741
