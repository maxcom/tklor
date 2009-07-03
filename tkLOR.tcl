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

set lorUrl "www.linux.org.ru"

array set fontPart {
    none ""
    item "-family Sans"
    unread "-weight bold"
    child "-slant italic"
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
set currentMessage ""

set topicNick ""
set topicHeader ""

set useProxy 0
set proxyAutoSelect 0
set proxyHost ""
set proxyPort ""
set proxyUser ""
set proxyPassword ""

set ignoreList ""

set messageMenu ""
set topicMenu ""

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

set newsGroups {
    2       "Linux.org.ru server"
    3       Документация
    4       "Linux General"
    6       OpenSource
    7       Mozilla
    13      RedHat
    26      Java
    37      GNOME
    44      KDE
    196     "GNU's Not Unix"
    213     Security
    2121    "Linux в России"
    4228    "Коммерческое ПО"
    6204    "Linux kernel"
    6205    "Hardware and Drivers"
    9406    BSD
    10794   Debian
    10980   "OpenOffice (StarOffice)"
    19103   PDA
    19104   Игры
    19105   SCO
    19106   Кластеры
    19107   "Ubuntu Linux"
    19108   Slackware
    19110   Apple
}

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc initMenu {} {
    menu .menu -type menubar
    .menu add cascade -label "LOR" -menu .menu.lor
    .menu add cascade -label "Topic" -menu .menu.topic
    .menu add cascade -label "Help" -menu .menu.help

    menu .menu.lor -tearoff 0
    .menu.lor add command -label "Update topics" -command updateTopicList
    .menu.lor add separator
    .menu.lor add command -label "Exit" -command exitProc

    menu .menu.topic -tearoff 0
    .menu.topic add command -label "Add..." -command addTopic
    .menu.topic add command -label "Refresh" -command refreshTopic

    menu .menu.help -tearoff 0
    .menu.help add command -label "About" -command helpAbout

    .  configure -menu .menu
}

proc initPopups {} {
    global messageMenu topicMenu

    set messageMenu [ menu .messageMenu -tearoff 0 ]
    $messageMenu add command -label "Reply" -command "reply"
    $messageMenu add command -label "User info" -command "userInfo"
    $messageMenu add command -label "Open in browser" -command "openMessage"
    $messageMenu add separator
    $messageMenu add command -label "Mark as read" -command "markMessage message 0"
    $messageMenu add command -label "Mark as unread" -command "markMessage message 1"
    $messageMenu add command -label "Mark thread as read" -command "markMessage thread 0"
    $messageMenu add command -label "Mark thread as unread" -command "markMessage thread 1"
    $messageMenu add command -label "Mark all as read" -command "markAllMessages 0"
    $messageMenu add command -label "Mark all as unread" -command "markAllMessages 1"

    set topicMenu [ menu .topicMenu -tearoff 0 ]
    $topicMenu add command -label "Refresh" -command "refreshTopicList"
    $topicMenu add separator
    $topicMenu add command -label "Mark as read" -command "markTopic topic 0"
    $topicMenu add command -label "Mark as unread" -command "markTopic topic 1"
    $topicMenu add command -label "Mark thread as read" -command "markTopic thread 0"
    $topicMenu add command -label "Mark thread as unread" -command "markTopic thread 1"
    $topicMenu add separator
    $topicMenu add command -label "Move to favorites" -command "addToFavorites"
}

proc initAllTopicsTree {} {
    global allTopicsWidget
    global forumGroups newsGroups

    set f [ frame .allTopicsFrame ]
    set allTopicsWidget [ ttk::treeview $f.allTopicsTree -columns {nick unread unreadChild parent text} -displaycolumns {unreadChild} -yscrollcommand "$f.scroll set" ]

    configureTags $allTopicsWidget
    $allTopicsWidget heading #0 -text "Title" -anchor w
    $allTopicsWidget heading unreadChild -text "Messages" -anchor w
    $allTopicsWidget column #0 -width 250
    $allTopicsWidget column unreadChild -width 30

    $allTopicsWidget insert "" end -id news -text "News" -values [ list "" 0 0 "" "News" ]
    foreach {id title} $newsGroups {
        $allTopicsWidget insert news end -id "news$id" -text $title -values [ list "" 0 0 "news" $title ]
    }

    $allTopicsWidget insert "" end -id forum -text "Forum" -values [ list "" 0 0 "" "Forum" ]
    foreach {id title} $forumGroups {
        $allTopicsWidget insert forum end -id "forum$id" -text $title -values [ list "" 0 0 "forum" $title ]
    }

    $allTopicsWidget insert "" end -id favorites -text "Favorites" -values [ list "" 0 0 "" "Favorites" ]

    bind $allTopicsWidget <<TreeviewSelect>> "topicClick"
    bind $allTopicsWidget <ButtonPress-3> "topicPopup %X %Y %x %y"

    ttk::scrollbar $f.scroll -command "$allTopicsWidget yview"
    pack $f.scroll -side right -fill y
    pack $allTopicsWidget -expand yes -fill both
    return $f
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
    set topicWidget [ ttk::treeview $f.topicTree -columns {nick header time msg unread unreadChild parent parentNick text} -displaycolumns {header time} -xscrollcommand "$f.scrollx set" -yscrollcommand "$f.scrolly set" ]
    $topicWidget heading #0 -text "Nick" -anchor w
    $topicWidget heading header -text "Title" -anchor w
    $topicWidget heading time -text "Time" -anchor w

    configureTags $topicWidget

    bind $topicWidget <<TreeviewSelect>> "messageClick"
    bind $topicWidget <ButtonPress-3> "messagePopup %X %Y %x %y"

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
        saveTopicListToCache
        exit
    }
}

proc renderHtml {w msg} {
    global htmlRenderer

    switch $htmlRenderer {
        "local" {
            set msg [ replaceHtmlEntities $msg ]
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
    upvar #0 topicWidget w

    set msg [ getItemValue $w $item msg ]
    set currentHeader [ getItemValue $w $item header ]
    set currentNick [ getItemValue $w $item nick ]
    set currentPrevNick [ getItemValue $w $item parentNick ]
    set currentTime [ getItemValue $w $item time ]

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
    global topicWidget messageWidget
    global currentHeader currentNick currentPrevNick currentTime

    startWait

    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    foreach item [ $topicWidget children "" ] {
        $topicWidget delete $item
    }

    set currentHeader ""
    set currentNick ""
    set currentPrevNick ""
    set currentTime ""
    renderHtml $messageWidget ""

    set currentTopic $topic
    set err 1
    set errStr ""
    set url "http://$lorUrl/view-message.jsp?msgid=$topic&page=-1"

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

    if [ regexp -- {<div class=msg><h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)(?:<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i>){0,1}</div>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        set topicText $msg
        set topicNick $nick
        set topicHeader [ replaceHtmlEntities $header ]
        saveTopicTextToCache $topic [ replaceHtmlEntities $header ] $topicText $nick $time $approver $approveTime
    } else {
        set topicText "Unable to parse topic text :("
        set topicNick ""
        set topicHeader ""
        saveTopicTextToCache $topic "" $topicText "" "" "" ""
    }
    updateTopicText $topicHeader $topicText
}

proc parsePage {topic data} {
    upvar #0 topicWidget w

    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}(?:&amp;page=\d+){0,1}#(\d+)">[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div>} $message dummy2 parent parentNick id header msg nick time ] {
            if { ! [ $w exists $id ] } {
                $w insert $parent end -id $id -text $nick
                foreach i {nick time msg parent parentNick} {
                    setItemValue $w $id $i [ set $i ]
                }
                setItemValue $w $id header [ replaceHtmlEntities $header ]
                setItemValue $w $id unread 1
                setItemValue $w $id unreadChild 0
                addUnreadChild $w $parent
                updateItemState $w $id
            }
        }
    }
}

proc getItemValue {w item valueName} {
    set val [ $w item $item -values ]
    set pos [ lsearch -exact [ $w cget -columns ] $valueName ]
    return [ lindex $val $pos ]
}

proc setItemValue {w item valueName value} {
    set val [ $w item $item -values ]
    if { $val == "" } {
        set val [ $w cget -columns ]
    }
    set pos [ lsearch -exact [ $w cget -columns ] $valueName ]
    lset val $pos $value
    $w item $item -values $val
}

proc messageClick {} {
    upvar #0 topicWidget w
    global currentMessage

    set item [ $w focus ]
    if { $item != $currentMessage } {
        set currentMessage $item
        updateMessage $item
        if [ getItemValue $w $item unread ] {
            setItemValue $w $item unread 0
            addUnreadChild $w [ getItemValue $w $item parent ] -1
        }
        updateItemState $w $item
    }
}

proc addUnreadChild {w item {count 1}} {
    if { $item != "" } {
        setItemValue $w $item unreadChild [ expr [ getItemValue $w $item unreadChild ] + $count ]
        if { [ getItemValue $w $item parent ] != "" } {
            addUnreadChild $w [ getItemValue $w $item parent ] $count
        }
        updateItemState $w $item
    }
}

proc getItemText {w item} {
    global topicWidget
    if { $w == $topicWidget } {
        set text [ getItemValue $w $item nick ]
        if [ getItemValue $w $item unreadChild ] {
            append text " ([ getItemValue $w $item unreadChild ])"
        }
        return $text
    } else {
        set text [ getItemValue $w $item text ]
        if { [ getItemValue $w $item nick ] != "" } {
            append text " ([ getItemValue $w $item nick ])"
        }
        return $text
    }
}

proc updateItemState {w item} {
    global ignoreList

    set tag "item"
    if [ getItemValue $w $item unread ] {
        append tag "_unread"
    }
    if [ getItemValue $w $item unreadChild ] {
        append tag "_child"
    }
    if { [ lsearch -exact $ignoreList [ getItemValue $w $item nick ] ] != -1 } {
        append tag "_ignored"
    }
    $w item $item -tags [ list $tag ]
    $w item $item -text [ getItemText $w $item ]
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
    global useProxy proxyAutoSelect proxyHost proxyPort proxyUser proxyPassword

    if $useProxy {
        package require autoproxy
        ::autoproxy::init 
        if {! $proxyAutoSelect} {
            ::autoproxy::configure -proxy_host $proxyHost -proxy_port $proxyPort
        }
        if {$proxyUser != ""} {
            ::autoproxy::configure -basic -username $proxyUser -password $proxyPassword
        }
        ::http::config -proxyfilter ::autoproxy::filter
    }

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
    fconfigure $f -encoding utf-8
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
    fconfigure $f -encoding utf-8
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
        array set res [ lindex [ parseMbox [ file join $configDir $threadSubDir [ join [ list $topic ".topic" ] "" ] ] ] 0 ]
        updateTopicText $res(Subject) $res(body)
    }
}

proc saveMessage {topic id header text nick time replyTo replyToId unread} {
    global appName
    global configDir threadSubDir

    set f [ open [ file join $configDir $threadSubDir $topic ] "a" ]
    fconfigure $f -encoding utf-8
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
    upvar #0 topicWidget w

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

            $w insert $parent end -id $id -text $nick
            foreach i {nick header time msg parent parentNick unread} {
                setItemValue $w $id $i [ set $i ]
            }
            setItemValue $w $id unreadChild 0
            if $unread {
                addUnreadChild $w $parent
            }
            updateItemState $w $id
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
    upvar #0 topicWidget w

    foreach id [ $w children $item ] {
        saveMessage $topic $id [ getItemValue $w $id header ] [ getItemValue $w $id msg ] [ getItemValue $w $id nick ] [ getItemValue $w $id time ] [ getItemValue $w $id parentNick ] [ getItemValue $w $id parent ] [ getItemValue $w $id unread ]
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

proc loadConfigFile {fileName} {
    catch {uplevel #0 "source {$fileName}"}
}

proc loadConfig {} {
    global configDir

    loadConfigFile [ file join $configDir "config" ]
    loadConfigFile [ file join $configDir "userConfig" ]
}

proc updateTopicList {{section ""}} {
    global forumGroups newsGroups

    if {$section == "" } {
        updateTopicList news
        updateTopicList forum
        return
    }

    switch -glob -- $section {
        news* {
            if { $section == "news" } {
                foreach {id title} $newsGroups {
                    updateTopicList "news$id"
                }
            } else {
                parseNews [ string trimleft $section "news" ]
            }
        }
        forum* {
            if { $section == "forum" } {
                foreach {id title} $forumGroups {
                    updateTopicList "forum$id"
                }
            } else {
                parseForum [ string trimleft $section "forum" ]
            }
        }
        default {
            #TODO
        }
    }
}

proc parseForum {forum} {
    global lorUrl

    startWait

    set url "http://$lorUrl/group.jsp?group=$forum"
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
    upvar #0 allTopicsWidget w
    global configDir threadSubDir

    foreach item [ $w children "forum$forum" ] {
        set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
        addUnreadChild $w "forum$forum" "-$count"
        $w delete $item
    }
    setItemValue $w "forum$forum" unreadChild 0

    foreach {dummy id header nick} [ regexp -all -inline -- {<tr><td>(?:<img [^>]*> ){0,1}<a href="view-message.jsp\?msgid=(\d+)(?:&amp;lastmod=\d+){0,1}" rev=contents>([^<]*)</a>(?:&nbsp;\([^<]*(?: *<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}&amp;page=\d+">\d+</a> *)+\)){0,1} \(([\w-]+)\)</td><td align=center>(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)</td></tr>} $data ] {
        if { $id != "" } {
            catch {
                $w insert "forum$forum" end -id $id -text [ replaceHtmlEntities $header ]
                setItemValue $w $id text [ replaceHtmlEntities $header ]
                setItemValue $w $id parent "forum$forum"
                setItemValue $w $id nick $nick
                setItemValue $w $id unreadChild 0
                if {! [ file exists [ file join $configDir $threadSubDir "$id.topic" ] ] } {
                    setItemValue $w $id unread 1
                    addUnreadChild $w "forum$forum"
                } else {
                    setItemValue $w $id unread 0
                }
                updateItemState $w $id
            }
        }
    }
    $w see "forum$forum"
}

proc addTopicFromCache {parent id nick text unread} {
    upvar #0 allTopicsWidget w

    if { ! [ $w exists $id ] } {
        $w insert $parent end -id $id
        setItemValue $w $id nick $nick
        setItemValue $w $id text $text
        setItemValue $w $id unread $unread
        setItemValue $w $id unreadChild 0
        setItemValue $w $id parent $parent
        updateItemState $w $id
        if $unread {
            addUnreadChild $w $parent
        }
    }
}

proc loadTopicListFromCache {} {
    global configDir

    catch {source [ file join $configDir "topics" ]}
}

proc saveTopicListToCache {} {
    upvar #0 allTopicsWidget w
    global forumGroups newsGroups
    global configDir

    catch {
        set f [ open [ file join $configDir "topics" ] "w+" ]
        fconfigure $f -encoding utf-8
        foreach {forum title} $forumGroups {
            foreach id [ $w children "forum$forum" ] {
                puts -nonewline $f "addTopicFromCache forum$forum $id [ getItemValue $w $id nick ] "
                puts -nonewline $f [ list [ getItemValue $w $id text ] ]
                puts $f " [ getItemValue $w $id unread ]"
            }
        }
        foreach {group title} $newsGroups {
            foreach id [ $w children "news$group" ] {
                puts -nonewline $f "addTopicFromCache news$group $id [ getItemValue $w $id nick ] "
                puts -nonewline $f [ list [ getItemValue $w $id text ] ]
                puts $f " [ getItemValue $w $id unread ]"
            }
        }
        close $f
    }
}

proc topicClick {} {
    upvar #0 allTopicsWidget w

    set item [ $w focus ]
    if { [ regexp -lineanchor -- {^\d} $item ] } {
        if [ getItemValue $w $item unread ] {
            addUnreadChild $w [ getItemValue $w $item parent ] -1
        }
        setItemValue $w $item unread 0
        updateItemState $w $item
        setTopic $item
    }
}

proc mark {w item type unread} {
    set old [ getItemValue $w $item unread ]
    if {$unread != $old} {
        setItemValue $w $item unread $unread
        addUnreadChild $w [ getItemValue $w $item parent ] [ expr $unread - $old ]
        updateItemState $w $item
        if { $w == $::allTopicsWidget } {
            global configDir threadSubDir

            if { [ regexp -lineanchor {^\d+$} $item ] } {
                if { $unread == "0" } {
                    set f [ open [ file join $configDir $threadSubDir "$item.topic" ] "w" ]
                    close $f
                } else {
                    file delete [ file join $configDir $threadSubDir "$item.topic" ]
                }
            }
        }
    }
    if {$type == "thread"} {
        foreach i [ $w children $item ] {
            mark $w $i $type $unread
        }
    }
}

proc messagePopup {xx yy x y} {
    global messageMenu mouseX mouseY

    set mouseX $x
    set mouseY $y

    tk_popup $messageMenu $xx $yy
}

proc markMessage {thread unread} {
    upvar #0 topicWidget w
    global mouseX mouseY

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        mark $w $item $thread $unread
    }
}

proc topicPopup {xx yy x y} {
    global topicMenu mouseX mouseY

    set mouseX $x
    set mouseY $y

    tk_popup $topicMenu $xx $yy
}

proc markTopic {thread unread} {
    upvar #0 allTopicsWidget w
    global mouseX mouseY

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        mark $w $item $thread $unread
    }
}

proc refreshTopicList {} {
    upvar #0 allTopicsWidget w
    global mouseX mouseY

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        updateTopicList $item
    }
}

proc markAllMessages {unread} {
    upvar #0 topicWidget w

    foreach item [ $w children "" ] {
        mark $w $item thread $unread
    }
}

proc reply {} {
    upvar #0 topicWidget w
    global mouseX mouseY
    global lorUrl
    global currentTopic

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        openUrl "http://$lorUrl/add_comment.jsp?topic=$currentTopic&replyto=$item"
    }
}

proc userInfo {} {
    upvar #0 topicWidget w
    global mouseX mouseY
    global lorUrl
    global currentTopic

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        openUrl "http://$lorUrl/whois.jsp?nick=[ getItemValue $w $item nick ]"
    }
}

proc openMessage {} {
    upvar #0 topicWidget w
    global mouseX mouseY
    global lorUrl
    global currentTopic

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        openUrl "http://$lorUrl/jump-message.jsp?msgid=$currentTopic&cid=$item"
    }
}

proc openUrl {url} {
    global tcl_platform

    if { [ string first Windows $tcl_platform(os) ] != -1 } {
        set prog "start"
    } else {
        set prog "x-www-browser"
    }
    catch {exec $prog $url &}
}

proc parseNews {group} {
    global lorUrl
    upvar #0 allTopicsWidget w

    startWait

    foreach item [ $w children "news$group" ] {
        set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
        addUnreadChild $w "news$group" "-$count"
        $w delete $item
    }

    set url "http://$lorUrl/group.jsp?group=$group"
    set err 0

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            parseNewsPage $group [ ::http::data $token ]
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

proc parseNewsPage {group data} {
    upvar #0 allTopicsWidget w
    global configDir threadSubDir

    foreach {dummy id header nick} [ regexp -all -inline -- {<tr><td>(?:<img [^>]*> ){0,1}<a href="view-message.jsp\?msgid=(\d+)(?:&amp;lastmod=\d+){0,1}" rev=contents>([^<]*)</a>(?:&nbsp;\([^<]*(?: *<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}&amp;page=\d+">\d+</a> *)+\)){0,1} \(([\w-]+)\)</td><td align=center>(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)</td></tr>} $data ] {
        if { $id != "" } {
            catch {
                $w insert "news$group" end -id $id -text [ replaceHtmlEntities $header ]
                setItemValue $w $id text [ replaceHtmlEntities $header ]
                setItemValue $w $id parent "news$group"
                setItemValue $w $id nick $nick
                setItemValue $w $id unreadChild 0
                if {! [ file exists [ file join $configDir $threadSubDir "$id.topic" ] ] } {
                    setItemValue $w $id unread 1
                    addUnreadChild $w "news$group"
                } else {
                    setItemValue $w $id unread 0
                }
                updateItemState $w $id
            }
        }
    }
    $w see "news$group"
}

proc replaceHtmlEntities {text} {
    foreach {re s} {
        "<img [^>]*>" "[image]"
        "<!--.*?-->" ""
        "<br>" "\n"
        "<p>" "\n"
        "</p>" ""
        "<a [^>]*>" ""
        "</a>" ""
        "</{0,1}i>" ""
        "&lt;" "<"
        "&gt;" ">"
        "&amp;" "&"
        "&quot;" "\""
        "\n{3,}" "\n\n" } {
        regsub -all $re $text $s text
    }
    return $text
}

############################################################################
#                                   MAIN                                   #
############################################################################

processArgv
loadConfig

initDirs
initHttp

initMenu
initPopups
initMainWindow

update

loadTopicListFromCache
