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

package require Tk 8.4
package require tile 0.8
package require http 2.0

set appName "tkLOR"
set appVersion "APP_VERSION"
set appId "$appName $appVersion $tcl_platform(os) $tcl_platform(osVersion) $tcl_platform(machine)"
set appHome "http://code.google.com/p/tklor/"

set configDir [ file join $::env(HOME) ".$appName" ]
set threadSubDir "threads"

set lorUrl "www.linux.org.ru"

set htmlRenderer "local"
if { [ info tclversion ] == "8.4" && ! [catch {package require Iwidgets}] } {
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
set topicTime ""

set useProxy 0
set proxyAutoSelect 0
set proxyHost ""
set proxyPort ""
set proxyAuthorization 0
set proxyUser ""
set proxyPassword ""

set browser ""

set ignoreList ""
set nickToIgnore ""

set messageMenu ""
set topicMenu ""
set topicTextMenu ""
set messageTextMenu ""

set autonomousMode 0
set expandNewMessages 1
set updateOnStart 0

set tileTheme "default"

set findString ""
set findPos ""

set messageTextFont [ font actual system ]

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
    3       Documentation
    4       "Linux General"
    6       OpenSource
    7       Mozilla
    13      RedHat
    26      Java
    37      GNOME
    44      KDE
    196     "GNU's Not Unix"
    213     Security
    2121    "Linux in Russia"
    4228    "Proprietary software"
    6204    "Linux kernel"
    6205    "Hardware and Drivers"
    9406    BSD
    10794   Debian
    10980   "OpenOffice (StarOffice)"
    19103   PDA
    19104   Games
    19105   SCO
    19106   Clusters
    19107   "Ubuntu Linux"
    19108   Slackware
    19110   Apple
}

array set fontPart {
    none ""
    item "-family Sans"
    unread "-weight bold"
    child "-slant italic"
    ignored "-overstrike 1"
}

set options {
    "Global" {
        "Widget theme"  readOnlyCombo   tileTheme   { ttk::style theme names }
        "Start in autonomous mode"  check   autonomousMode ""
        "Update topics list on start"    check   updateOnStart ""
        "Browser"   editableCombo   browser { list "sensible-browser" "opera" "mozilla" "konqueror" "iexplore.exe" }
    }
    "Connection" {
        "Use proxy" check   useProxy ""
        "Proxy auto-config" check   proxyAutoSelect ""
        "Proxy host"    string  proxyHost ""
        "Proxy port"    string  proxyPort ""
        "Proxy autorization"    check   proxyAuthorization ""
        "Proxy user"    string  proxyUser ""
        "Proxy password"    password    proxyPassword ""
    }
    "Reading" {
        "Expand new messages"   check   expandNewMessages   ""
        "Ignore list"   list    ignoreList ""
    }
    "Normal font" {
        "font"  fontPart    fontPart(item) ""
    }
    "Unread font" {
        "font"  fontPart    fontPart(unread) ""
    }
    "Unread childs font" {
        "font"  fontPart    fontPart(child) ""
    }
    "Ignored font" {
        "font"  fontPart    fontPart(ignored) ""
    }
    "Message text(!iwidgets)" {
        "font"  font    messageTextFont ""
    }
}

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc initMenu {} {
    menu .menu -type menubar
    .menu add cascade -label "LOR" -menu .menu.lor
    .menu add cascade -label "Topic" -menu .menu.topic
    .menu add cascade -label "Message" -menu .menu.message
    .menu add cascade -label "Search" -menu .menu.search
    .menu add cascade -label "Help" -menu .menu.help

    set m [ menu .menu.lor -tearoff 0 ]
    $m add command -label "Search new topics" -accelerator "F2" -command updateTopicList
    $m add separator
    $m add checkbutton -label "Autonomous mode" -onvalue 1 -offvalue 0 -variable autonomousMode
    $m add command -label "Options..." -command showOptionsDialog
    $m add separator
    $m add command -label "Clear old topics..." -command clearOldTopics
    $m add separator
    $m add command -label "Exit" -command exitProc

    set m [ menu .menu.topic -tearoff 0 ]
    $m add command -label "Refresh sub-tree" -command {invokeMenuCommand $allTopicsWidget refreshTopicList}
    $m add separator
    $m add command -label "Reply" -command {invokeMenuCommand $allTopicsWidget topicReply}
    $m add cascade -label "Mark" -menu $m.mark

    set mm [ menu $m.mark -tearoff 0 ]
    $mm add command -label "Mark as read" -command {invokeMenuCommand $allTopicsWidget mark message 0}
    $mm add command -label "Mark as unread" -command {invokeMenuCommand $allTopicsWidget mark message 1}
    $mm add command -label "Mark thread as read" -command {invokeMenuCommand $allTopicsWidget mark thread 0}
    $mm add command -label "Mark thread as unread" -command {invokeMenuCommand $allTopicsWidget mark thread 1}

    $m add command -label "User info" -command {invokeMenuCommand $allTopicsWidget topicUserInfo}
    $m add command -label "Ignore user" -command {invokeMenuCommand $allTopicsWidget ignoreUser}
    $m add command -label "Open in browser" -command {invokeMenuCommand $allTopicsWidget topicOpenMessage}
    $m add command -label "Go to next unread" -accelerator n -command {invokeMenuCommand $allTopicsWidget nextUnread}
    $m add separator
    $m add command -label "Move to favorites" -command {invokeMenuCommand $allTopicsWidget addToFavorites}
    $m add command -label "Clear cache" -command {invokeMenuCommand $allTopicsWidget clearTopicCache}
    $m add command -label "Delete" -command {invokeMenuCommand $allTopicsWidget deleteTopic}

    set m [ menu .menu.message -tearoff 0 ]
    $m add command -label "Refresh tree" -accelerator "F5" -command refreshTopic
    $m add separator
    $m add command -label "Reply" -accelerator "Ctrl-R" -command {invokeMenuCommand $topicWidget reply}
    $m add cascade -label "Mark" -menu $m.mark

    set mm [ menu $m.mark -tearoff 0 ]
    $mm add command -label "Mark as read" -command {invokeMenuCommand $topicWidget mark message 0}
    $mm add command -label "Mark as unread" -command {invokeMenuCommand $topicWidget mark message 1}
    $mm add command -label "Mark thread as read" -command {invokeMenuCommand $topicWidget mark thread 0}
    $mm add command -label "Mark thread as unread" -command {invokeMenuCommand $topicWidget mark thread 1}
    $mm add command -label "Mark all as read" -command "markAllMessages 0"
    $mm add command -label "Mark all as unread" -command "markAllMessages 1"

    $m add command -label "User info" -accelerator "Ctrl-I" -command {invokeMenuCommand $topicWidget userInfo}
    $m add command -label "Ignore user" -command {invokeMenuCommand $topicWidget ignoreUser}
    $m add command -label "Open in browser" -accelerator "Ctrl-O" -command {invokeMenuCommand $topicWidget openMessage}
    $m add separator
    $m add command -label "Go to next unread" -accelerator n -command {invokeMenuCommand $topicWidget nextUnread}

    set m [ menu .menu.search -tearoff 0 ]
    $m add command -label "Find..." -accelerator "Ctrl-F" -command find
    $m add command -label "Find next" -accelerator "F3" -command findNext

    set m [ menu .menu.help -tearoff 0 ]
    $m add command -label "Project home" -command {openUrl $appHome}
    $m add command -label "About LOR" -command {openUrl "http://$lorUrl/server.jsp"}
    $m add separator
    $m add command -label "About" -command helpAbout -accelerator "F1"

    .  configure -menu .menu
}

proc initPopups {} {
    global messageMenu topicMenu topicTextMenu messageTextMenu

    set topicMenu [ menu .topicMenu -tearoff 0 ]
    $topicMenu add command -label "Refresh sub-tree" -command {invokeItemCommand $allTopicsWidget refreshTopicList}
    $topicMenu add command -label "Reply" -command {invokeItemCommand $allTopicsWidget topicReply}
    $topicMenu add cascade -label "Mark" -menu $topicMenu.mark

    set mm [ menu $topicMenu.mark -tearoff 0 ]
    $mm add command -label "Mark as read" -command {invokeItemCommand $allTopicsWidget mark message 0}
    $mm add command -label "Mark as unread" -command {invokeItemCommand $allTopicsWidget mark message 1}
    $mm add command -label "Mark thread as read" -command {invokeItemCommand $allTopicsWidget mark thread 0}
    $mm add command -label "Mark thread as unread" -command {invokeItemCommand $allTopicsWidget mark thread 1}

    $topicMenu add command -label "User info" -command {invokeItemCommand $allTopicsWidget topicUserInfo}
    $topicMenu add command -label "Ignore user" -command {invokeItemCommand $allTopicsWidget ignoreUser}
    $topicMenu add command -label "Open in browser" -command {invokeItemCommand $allTopicsWidget topicOpenMessage}
    $topicMenu add separator
    $topicMenu add command -label "Move to favorites" -command {invokeItemCommand $allTopicsWidget addToFavorites}
    $topicMenu add command -label "Clear cache" -command {invokeItemCommand $allTopicsWidget clearTopicCache}
    $topicMenu add command -label "Delete" -command {invokeItemCommand $allTopicsWidget deleteTopic}

    set messageMenu [ menu .messageMenu -tearoff 0 ]
    $messageMenu add command -label "Reply" -command {invokeItemCommand $topicWidget reply}
    $messageMenu add cascade -label "Mark" -menu $messageMenu.mark

    set mm [ menu $messageMenu.mark -tearoff 0 ]
    $mm add command -label "Mark as read" -command {invokeItemCommand $topicWidget mark message 0}
    $mm add command -label "Mark as unread" -command {invokeItemCommand $topicWidget mark message 1}
    $mm add command -label "Mark thread as read" -command {invokeItemCommand $topicWidget mark thread 0}
    $mm add command -label "Mark thread as unread" -command {invokeItemCommand $topicWidget mark thread 1}
    $mm add command -label "Mark all as read" -command "markAllMessages 0"
    $mm add command -label "Mark all as unread" -command "markAllMessages 1"

    $messageMenu add command -label "User info" -command {invokeItemCommand $topicWidget userInfo}
    $messageMenu add command -label "Ignore user" -command {invokeItemCommand $topicWidget ignoreUser}
    $messageMenu add command -label "Open in browser" -command {invokeItemCommand $topicWidget openMessage}

    set m [ menu .topicTextMenu -tearoff 0 ]
    set topicTextMenu $m
    $m add command -label "Copy selection" -command {tk_textCopy $topicTextWidget}
    $m add command -label "Open selection in browser" -command {tk_textCopy $topicTextWidget;openUrl [ clipboard get ]}

    set m [ menu .messageTextMenu -tearoff 0 ]
    set messageTextMenu $m
    $m add command -label "Copy selection" -command {tk_textCopy $messageWidget}
    $m add command -label "Open selection in browser" -command {tk_textCopy $messageWidget;openUrl [ clipboard get ]}
}

proc initAllTopicsTree {} {
    global allTopicsWidget
    global forumGroups newsGroups

    set f [ ttk::frame .allTopicsFrame ]
    set allTopicsWidget [ ttk::treeview $f.allTopicsTree -columns {nick unread unreadChild parent text} -displaycolumns {unreadChild} -yscrollcommand "$f.scroll set" ]

    configureTags $allTopicsWidget
    $allTopicsWidget heading #0 -text "Title" -anchor w
    $allTopicsWidget heading unreadChild -text "Threads" -anchor w
    $allTopicsWidget column #0 -width 250
    $allTopicsWidget column unreadChild -width 30 -stretch 0

    $allTopicsWidget insert "" end -id news -text "News" -values [ list "" 0 0 "" "News" ]
    foreach {id title} $newsGroups {
        $allTopicsWidget insert news end -id "news$id" -text $title -values [ list "" 0 0 "news" $title ]
        updateItemState $allTopicsWidget "news$id"
    }
    updateItemState $allTopicsWidget "news"

    $allTopicsWidget insert "" end -id forum -text "Forum" -values [ list "" 0 0 "" "Forum" ]
    foreach {id title} $forumGroups {
        $allTopicsWidget insert forum end -id "forum$id" -text $title -values [ list "" 0 0 "forum" $title ]
        updateItemState $allTopicsWidget "forum$id"
    }
    updateItemState $allTopicsWidget "forum"

    $allTopicsWidget insert "" end -id favorites -text "Favorites" -values [ list "" 0 0 "" "Favorites" ]
    updateItemState $allTopicsWidget "favorites"

    bind $allTopicsWidget <<TreeviewSelect>> {invokeMenuCommand $allTopicsWidget click}
    bind $allTopicsWidget <ButtonPress-3> {popupMenu $topicMenu %X %Y %x %y}

    bind $allTopicsWidget n {invokeMenuCommand $allTopicsWidget nextUnread}
    bind $allTopicsWidget N {invokeMenuCommand $allTopicsWidget nextUnread}
    bind $allTopicsWidget <Menu> {openContextMenu $allTopicsWidget $topicMenu}

    ttk::scrollbar $f.scroll -command "$allTopicsWidget yview"
    pack $f.scroll -side right -fill y
    pack $allTopicsWidget -expand yes -fill both
    return $f
}

proc initTopicText {} {
    global topicTextWidget
    global htmlRenderer
    global topicNick topicTime
    global messageTextFont

    set mf [ ttk::frame .topicTextFrame ]
    pack [ ttk::label $mf.header -textvariable topicHeader -font "-size 14 -weight bold" ] -fill x

    set width 10

    set f [ ttk::frame $mf.nick ]
    pack [ ttk::label $f.label -text "From: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable topicNick ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.time ]
    pack [ ttk::label $f.label -text "Time: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable topicTime ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.textFrame ]
    switch -exact $htmlRenderer {
        "local" {
            set topicTextWidget [ text $f.msg -state disabled -yscrollcommand "$f.scroll set" -setgrid true -wrap word -height 15 ]
            catch {
                $topicTextWidget configure -font $messageTextFont
            }
            ttk::scrollbar $f.scroll -command "$topicTextWidget yview"
            pack $f.scroll -side right -fill y
            pack $topicTextWidget -expand yes -fill both
        }
        "iwidgets" {
            set topicTextWidget [ iwidgets::scrolledhtml $f.msg -state disabled -linkcommand openUrl ]
            pack $topicTextWidget -expand yes -fill both
        }
    }
    pack $f -expand yes -fill both
    bind $topicTextWidget <ButtonPress-3> {popupMenu $topicTextMenu %X %Y %x %y}

    return $mf
}

proc initTopicTree {} {
    global topicWidget

    set f [ ttk::frame .topicFrame ]
    set topicWidget [ ttk::treeview $f.topicTree -columns {nick header time msg unread unreadChild parent parentNick text} -displaycolumns {header time} -xscrollcommand "$f.scrollx set" -yscrollcommand "$f.scrolly set" ]
    $topicWidget heading #0 -text "Nick" -anchor w
    $topicWidget heading header -text "Title" -anchor w
    $topicWidget heading time -text "Time" -anchor w

    $topicWidget column header -width 1
    $topicWidget column time -width 1

    configureTags $topicWidget

    bind $topicWidget <<TreeviewSelect>> {invokeMenuCommand $topicWidget click}
    bind $topicWidget <ButtonPress-3> {popupMenu $messageMenu %X %Y %x %y}

    bind $topicWidget n {invokeMenuCommand $topicWidget nextUnread}
    bind $topicWidget N {invokeMenuCommand $topicWidget nextUnread}
    bind $topicWidget <Menu> {openContextMenu $topicWidget $messageMenu}

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
    global messageTextFont

    set mf [ ttk::frame .msgFrame ]

    set width 10

    set f [ ttk::frame $mf.header ]
    pack [ ttk::label $f.label -text "Header: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentHeader ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.nick ]
    pack [ ttk::label $f.label -text "From: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentNick ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.prevNick ]
    pack [ ttk::label $f.label -text "To: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentPrevNick ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.time ]
    pack [ ttk::label $f.label -text "Time: " -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentTime ] -side left
    pack $f -fill x

    switch -exact $htmlRenderer {
        "local" {
            set messageWidget [ text $mf.msg -state disabled -yscrollcommand "$mf.scroll set" -setgrid true -wrap word -height 15 ]
            catch {
                $messageWidget configure -font $messageTextFont
            }
            ttk::scrollbar $mf.scroll -command "$messageWidget yview"
            pack $mf.scroll -side right -fill y
            pack $messageWidget -expand yes -fill both
        }
        "iwidgets" {
            set messageWidget [ iwidgets::scrolledhtml $mf.msg -state disabled ]
            pack $messageWidget -expand yes -fill both
        }
    }
    bind $messageWidget <ButtonPress-3> {popupMenu $messageTextMenu %X %Y %x %y}

    return $mf
}

proc initMainWindow {} {
    global appName
    global tileTheme
    global statusBarWidget

    wm protocol . WM_DELETE_WINDOW exitProc
    wm title . $appName

    set statusBarWidget [ ttk::label .statusBar -text "" -relief sunken ]
    pack $statusBarWidget -side bottom -anchor w -fill x

    ttk::panedwindow .horPaned -orient horizontal
    pack .horPaned -fill both -expand 1

    .horPaned add [ initAllTopicsTree ]

    ttk::panedwindow .vertPaned -orient vertical
    .horPaned add .vertPaned

    .vertPaned add [ initTopicText ] -weight 3
    .vertPaned add [ initTopicTree ] -weight 1
    .vertPaned add [ initMessageWidget ] -weight 3

    bind . <F1> helpAbout
    bind . <F2> updateTopicList
    bind . <F3> findNext
    bind . <F5> refreshTopic

    bind . <Control-r> {invokeMenuCommand $topicWidget reply}
    bind . <Control-R> {invokeMenuCommand $topicWidget reply}
    bind . <Control-i> {invokeMenuCommand $topicWidget userInfo}
    bind . <Control-I> {invokeMenuCommand $topicWidget userInfo}
    bind . <Control-o> {invokeMenuCommand $topicWidget openMessage}
    bind . <Control-O> {invokeMenuCommand $topicWidget openMessage}
    bind . <Control-f> find
    bind . <Control-F> find

    ttk::style theme use $tileTheme
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
        saveOptions
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

proc updateTopicText {header msg nick time} {
    global topicTextWidget
    global topicHeader topicNick topicTime

    renderHtml $topicTextWidget $msg
    set topicHeader $header
    set topicNick $nick
    set topicTime $time
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
                set id [ join [ list "item" $a $b $c ] "_" ]
                regsub -all {_none} $id "" id

                $w tag configure $id -font [ join [ list $fontPart(item) $fontPart($a) $fontPart($b) $fontPart($c) ] " " ]
            }
        }
    }
}

proc setTopic {topic} {
    global currentTopic lorUrl appName
    global topicWidget messageWidget
    global currentHeader currentNick currentPrevNick currentTime topicNick topicTime
    global autonomousMode
    global expandNewMessages

    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    startWait "Loading topic..."
    
    if { $topic != $currentTopic } {
        setItemValue $topicWidget "" unreadChild 0

        foreach item [ $topicWidget children "" ] {
            $topicWidget delete $item
        }
        set currentHeader ""
        set currentNick ""
        set currentPrevNick ""
        set currentTime ""
        set topicNick ""
        set topicTime ""
        renderHtml $messageWidget ""
    }

    set currentTopic $topic
    set err 1
    set errStr ""
    set url "http://$lorUrl/view-message.jsp?msgid=$topic&page=-1"

    loadTopicTextFromCache $topic
    loadCachedMessages $topic

    if { ! $autonomousMode } {
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
    }
    focus $topicWidget
    update
    updateWindowTitle
    if { $expandNewMessages == "1" } {
        nextUnread $topicWidget ""
    }
    stopWait
}

proc parseTopicText {topic data} {
    if [ regexp -- {<div class=msg><h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)(?:<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i>){0,1}</div>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        set topicText $msg
        set topicNick $nick
        set topicTime $time
        set topicHeader [ replaceHtmlEntities $header ]
        saveTopicTextToCache $topic [ replaceHtmlEntities $header ] $topicText $nick $time $approver $approveTime
    } else {
        set topicText "Unable to parse topic text :("
        set topicNick ""
        set topicHeader ""
        set topicTime ""
        saveTopicTextToCache $topic "" $topicText "" "" "" ""
    }
    updateTopicText $topicHeader $topicText $topicNick $topicTime
}

proc parsePage {topic data} {
    upvar #0 topicWidget w

    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}(?:&amp;page=\d+){0,1}#(\d+)" *onclick="highLight\(\d+\);">[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div>} $message dummy2 parent parentNick id header msg nick time ] {
            if { ! [ $w exists $id ] } {
                $w insert $parent end -id $id -text $nick
                foreach i {nick time msg parent parentNick} {
                    setItemValue $w $id $i [ set $i ]
                }
                setItemValue $w $id header [ replaceHtmlEntities $header ]
                setItemValue $w $id unread 0
                setItemValue $w $id unreadChild 0
                mark $w $id item 1
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

proc click {w item} {
    global allTopicsWidget
    mark $w $item item 0
    if { $w == $allTopicsWidget } {
        if { [ regexp -lineanchor -- {^\d} $item ] } {
            setTopic $item
        }
    } else {
        global currentMessage

        set currentMessage $item
        updateMessage $item
    }
    updateItemState $w $item

    updateWindowTitle
}

proc addUnreadChild {w item {count 1}} {
    setItemValue $w $item unreadChild [ expr [ getItemValue $w $item unreadChild ] + $count ]
    if { $item != "" } {
        addUnreadChild $w [ getItemValue $w $item parent ] $count
    }
    updateItemState $w $item
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

    if { $item == "" } return

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
    global useProxy proxyAutoSelect proxyHost proxyPort proxyAuthorization proxyUser proxyPassword

    if { $useProxy != "0" } {
        package require autoproxy
        ::autoproxy::init 
        if { $proxyAutoSelect == "0" } {
            ::autoproxy::configure -proxy_host $proxyHost -proxy_port $proxyPort
        }
        if { $proxyAuthorization != "0" } {
            ::autoproxy::configure -basic -username $proxyUser -password $proxyPassword
        }
        ::http::config -proxyfilter ::autoproxy::filter
    } else {
        ::http::config -proxyfilter ""
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

    updateTopicText "" "" "" ""
    catch {
        array set res [ lindex [ parseMbox [ file join $configDir $threadSubDir [ join [ list $topic ".topic" ] "" ] ] ] 0 ]
        updateTopicText $res(Subject) $res(body) $res(From) $res(X-LOR-Time)
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
            setItemValue $w $id unread 0
            mark $w $id item $unread
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
    startWait "Saving topic to cache"
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

proc startWait {{text ""}} {
    global statusBarWidget

    if { $text == "" } {
        set text "Please, wait"
    }

    . configure -cursor clock
    grab $statusBarWidget
    $statusBarWidget configure -text $text
}

proc stopWait {} {
    global statusBarWidget

    grab release $statusBarWidget
    $statusBarWidget configure -text ""
    . configure -cursor ""
}

proc loadConfigFile {fileName} {
    global appName

    if { ![ file exists $fileName ] } {
        return
    }
    if [ catch {
        set f [ open $fileName "r" ]
        fconfigure $f -encoding utf-8
        set data [ read $f ]
        close $f

        uplevel #0 $data
    } err ] {
        tk_messageBox -title "$appName error" -message "Error loading $fileName\n$err" -parent . -type ok -icon error
    }
}

proc loadConfig {} {
    global configDir

    loadConfigFile [ file join $configDir "config" ]
    loadConfigFile [ file join $configDir "userConfig" ]
}

proc updateTopicList {{section ""} {recursive ""}} {
    global forumGroups newsGroups
    global autonomousMode
    global appName

    if { $autonomousMode } {
        if { [ tk_messageBox -title $appName -message "Are you want to go to online mode?" -type yesno -icon question -default yes ] == yes } {
            set autonomousMode 0
        } else {
            return
        }
    }

    if {$recursive == ""} {
        startWait "Updating topics list..."
    }
    if {$section == "" } {
        updateTopicList news 1
        updateTopicList forum 1

        if {$recursive == ""} stopWait
        return
    }

    switch -glob -- $section {
        news* {
            if { $section == "news" } {
                foreach {id title} $newsGroups {
                    updateTopicList "news$id" 1
                }
            } else {
                parseGroup $section [ string trimleft $section "news" ]
            }
        }
        forum* {
            if { $section == "forum" } {
                foreach {id title} $forumGroups {
                    updateTopicList "forum$id" 1
                }
            } else {
                parseGroup $section [ string trimleft $section "forum" ]
            }
        }
        default {
            # No action at this moment
        }
    }
    if {$recursive == ""} stopWait
}

proc parseGroup {parent group} {
    global lorUrl

    set url "http://$lorUrl/group.jsp?group=$group"
    set err 0

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            parseTopicList $parent [ ::http::data $token ]
            set err 0
        } else {
            set errStr [ ::http::code $token ]
        }
        ::http::cleanup $token
    }
    if $err {
        tk_messageBox -title "$appName error" -message "Unable to contact LOR\n$errStr" -parent . -type ok -icon error
    }
}

proc parseTopicList {parent data} {
    upvar #0 allTopicsWidget w
    global configDir threadSubDir

    foreach item [ $w children $parent ] {
        set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
        addUnreadChild $w $parent "-$count"
        $w delete $item
    }
    setItemValue $w $parent unreadChild 0

    foreach {dummy id header nick} [ regexp -all -inline -- {<tr><td>(?:<img [^>]*> ){0,1}<a href="view-message.jsp\?msgid=(\d+)(?:&amp;lastmod=\d+){0,1}" rev=contents>([^<]*)</a>(?:&nbsp;\([^<]*(?: *<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}&amp;page=\d+">\d+</a> *)+\)){0,1} \(([\w-]+)\)</td><td align=center>(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)/(?:(?:<b>\d*</b>)|-)</td></tr>} $data ] {
        if { $id != "" } {
            catch {
                $w insert $parent end -id $id -text [ replaceHtmlEntities $header ]
                setItemValue $w $id text [ replaceHtmlEntities $header ]
                setItemValue $w $id parent $parent
                setItemValue $w $id nick $nick
                setItemValue $w $id unread 0
                setItemValue $w $id unreadChild 0
                mark $w $id item [ expr ! [ file exists [ file join $configDir $threadSubDir "$id.topic" ] ] ]
                updateItemState $w $id
            }
        }
    }
}

proc addTopicFromCache {parent id nick text unread} {
    upvar #0 allTopicsWidget w

    if { ! [ $w exists $id ] } {
        $w insert $parent end -id $id
        setItemValue $w $id nick $nick
        setItemValue $w $id text $text
        setItemValue $w $id unread 0
        setItemValue $w $id unreadChild 0
        setItemValue $w $id parent $parent
        mark $w $id item $unread
        updateItemState $w $id
    }
}

proc loadTopicListFromCache {} {
    global configDir

    loadConfigFile [ file join $configDir "topics" ]
}

proc saveTopicListToCache {} {
    upvar #0 allTopicsWidget w
    global forumGroups newsGroups
    global configDir

    catch {
        set f [ open [ file join $configDir "topics" ] "w+" ]
        fconfigure $f -encoding utf-8
        foreach group {news forum favorites} {
            saveTopicListToCacheRecursive $w $f $group
        }
        close $f
    }
}

proc saveTopicListToCacheRecursive {w f parent} {
    foreach id [ $w children $parent ] {
        puts $f [ list "addTopicFromCache" $parent $id [ getItemValue $w $id nick ] [ getItemValue $w $id text ] [ getItemValue $w $id unread ] ]
        saveTopicListToCacheRecursive $w $f $id
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

proc popupMenu {menu xx yy x y} {
    global mouseX mouseY

    set mouseX $x
    set mouseY $y

    tk_popup $menu $xx $yy
}

proc refreshTopicList {w item} {
    global allTopicsWidget

    if { $w == $allTopicsWidget } {
        updateTopicList $item
    }
}

proc markAllMessages {unread} {
    upvar #0 topicWidget w

    foreach item [ $w children "" ] {
        mark $w $item thread $unread
    }
    updateWindowTitle
}

proc reply {w item} {
    global lorUrl currentTopic
    openUrl "http://$lorUrl/add_comment.jsp?topic=$currentTopic&replyto=$item"
}

proc userInfo {w item} {
    global lorUrl
    openUrl "http://$lorUrl/whois.jsp?nick=[ getItemValue $w $item nick ]"
}

proc openMessage {w item} {
    global lorUrl currentTopic
    openUrl "http://$lorUrl/jump-message.jsp?msgid=$currentTopic&cid=$item"
}

proc topicReply {w item} {
    global lorUrl
    openUrl "http://$lorUrl/comment-message.jsp?msgid=$item"
}

proc topicUserInfo {w item} {
    global lorUrl
    openUrl "http://$lorUrl/whois.jsp?nick=[ getItemValue $w $item nick ]"
}

proc topicOpenMessage {w item} {
    global lorUrl
    openUrl "http://$lorUrl/jump-message.jsp?msgid=$item"
}

proc openUrl {url} {
    global tcl_platform browser

    if { [ string first Windows $tcl_platform(os) ] != -1 && $browser == "" } {
        catch {exec $::env(COMSPEC) /c "start $url" &}
        return
    }

    set prog "sensible-browser"
    if { $browser != "" } {
        set prog $browser
    }
    catch {exec $prog $url &}
}

proc replaceHtmlEntities {text} {
    foreach {re s} {
        "<img [^>]*>" "[image]"
        "<!--.*?-->" ""
        "</{0,1}pre>" ""
        "\n<br>" "\n"
        "<br>\n" "\n"
        "<br>" "\n"
        "<p>" "\n"
        "</p>" ""
        "<a href=\"([^\"]+)\"[^>]*>[^<]*</a>" "\\1"
        "</{0,1}i>" ""
        "</{0,1}(?:u|o)l>" ""
        "<li>" "\n * "
        "</li>" ""
        "&lt;" "<"
        "&gt;" ">"
        "&quot;" "\""
        "&amp;" "\\&"
        "\n{3,}" "\n\n" } {
        regsub -all -nocase -- $re $text $s text
    }
    return $text
}

proc addToFavorites {w item} {
    $w detach $item
    set childs [ $w children "favorites" ]
    lappend childs $item
    set childs [ lsort -decreasing $childs ]
    $w children "favorites" $childs
    if [ getItemValue $w $item unread ] {
        addUnreadChild $w [ getItemValue $w $item parent ] -1
        addUnreadChild $w "favorites"
    }
    setItemValue $w $item parent "favorites"
}

proc deleteTopic {w item} {
    if [ regexp -lineanchor {^\d+$} $item ] {
        $w delete $item
    }
}

proc invokeItemCommand {w command args} {
    global mouseX mouseY

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        eval "$command $w $item $args"
        updateWindowTitle
    }
}

proc invokeMenuCommand {w command args} {
    set item [ $w focus ]
    if { $item != "" } {
        eval "$command $w $item $args"
        updateWindowTitle
    }
}

proc clearTopicCache {w item} {
    global configDir threadSubDir

    if [ regexp -lineanchor {^\d+$} $item ] {
        mark $w $item item 1
        catch {
            file delete [ file join $configDir $threadSubDir $item ]
            file delete [ file join $configDir $threadSubDir "$item.topic" ]
        }
    }
}

proc packOptionsItem {name item type var opt} {
    if { $type != "check" } {
        pack [ ttk::label [ join [ list $name Label ] "" ] -text "$item:" ] -anchor w -fill x
    }
    switch -exact -- $type {
        check {
            pack [ ttk::checkbutton $name -variable $var -text $item ] -anchor w -fill x
        }
        list {
            set f [ ttk::frame $name ]
            set v [ listbox "$f.list" -listvariable $var -selectmode extended -yscrollcommand "$f.scroll set" ]
            pack [ ttk::scrollbar "$f.scroll" -command "$v yview" ] -side right -fill y
            pack $v -anchor w -fill x
            pack $f -anchor w -fill both

            pack [ ttk::button [ join [ list $name Add ] "" ] -text "Add" -command "addListItem $v" ] [ ttk::button [ join [ list $name Remove ] "" ] -text "Remove" -command "removeListItem $v" ] -fill x -side left
        }
        editableCombo {
            pack [ ttk::combobox $name -values $opt -textvariable $var ] -anchor w -fill x
        }
        readOnlyCombo {
            pack [ ttk::combobox $name -values $opt -textvariable $var -state readonly ] -anchor w -fill x
        }
        password {
            pack [ ttk::entry $name -textvariable $var -show * ] -anchor w -fill x
        }
        string -
        default {
            pack [ ttk::entry $name -textvariable $var ] -anchor w -fill x
        }
    }
}

proc showOptionsDialog {} {
    global options optionsTmp
    global appName

    catch {array unset optionsTmp}
    array set optionsTmp ""

    set d .optionsDialog
    catch {destroy $d}
    toplevel $d
    wm title $d "$appName options"
    set notebook [ ttk::notebook $d.notebook ]
    pack $notebook -fill both

    set n 0
    foreach {category optList} $options {
        set page [ ttk::frame "$notebook.page$n" ]

        set i 0
        foreach {item type var opt} $optList {
            set f [ ttk::frame "$page.item$i" -relief raised -borderwidth 1 -padding 1 ]

            if { $type != "font" && $type != "fontPart" } {
                array set optionsTmp [ list "$n.$i" [ set ::$var ] ]
                packOptionsItem $f.value $item $type "optionsTmp($n.$i)" [ eval $opt ]
            } else {
                array set ff [ set ::$var ]
                set names [ array names ff ]
                foreach param {family size weight slant underline overstrike} {
                    if { [ lsearch -exact $names "-$param" ] == -1 } {
                        array set optionsTmp [ list "$n.$i.$param" "" ]
                    } else {
                        array set optionsTmp [ list "$n.$i.$param" [ set "ff(-$param)" ] ]
                    }
                }
                array unset ff

                packOptionsItem $f.family "Family" editableCombo "optionsTmp($n.$i.family)" [ font families ]
                packOptionsItem $f.size "Size" string "optionsTmp($n.$i.size)" ""
                packOptionsItem $f.weight "Weight" readOnlyCombo "optionsTmp($n.$i.weight)" { "" normal bold }
                packOptionsItem $f.slant "Slant" readOnlyCombo "optionsTmp($n.$i.slant)" { "" roman italic }
                packOptionsItem $f.underline "Underline" check "optionsTmp($n.$i.underline)" ""
                packOptionsItem $f.overstrike "Overstrike" check "optionsTmp($n.$i.overstrike)" ""
            }

            pack $f -anchor w -fill x
            incr i
        }
        $notebook add $page -sticky nswe -text $category
        incr n
    }
    set f [ ttk::frame $d.buttonFrame ]
    pack [ ttk::button $f.discard -text "Cancel" -command discardOptions ] [ ttk::button $f.save -text "OK" -command acceptOptions ] -side right
    pack $f -fill x -side bottom
    update

    wm resizable $d 0 0
    centerToParent $d .
    grab $d
}

proc acceptOptions {} {
    global options optionsTmp

    catch {destroy .optionsDialog}

    set n 0
    foreach {category optList} $options {
        set i 0
        foreach {item type var opt} $optList {
            if { $type != "font" && $type != "fontPart" } {
                set ::$var [ set "optionsTmp($n.$i)" ]
            } else {
                set s ""
                foreach param {family size weight slant underline overstrike} {
                    set v [ set "optionsTmp($n.$i.$param)" ]
                    if {$v != ""} {
                        lappend s [ list "-$param" $v ]
                    }
                }
                set res [ join $s ]
                if { $type == "font" && $res == "" } {
                    set res [ font actual system ]
                }
                set ::$var $res
            }
            incr i
        }
        incr n
    }
    array unset optionsTmp

    applyOptions
}

proc applyOptions {} {
    global allTopicsWidget topicWidget
    global tileTheme
    global topicTextWidget messageWidget
    global messageTextFont
    global htmlRenderer

    initHttp

    configureTags $allTopicsWidget
    configureTags $topicWidget
    ttk::style theme use $tileTheme

    if { $htmlRenderer == "local" } {
        $topicTextWidget configure -font $messageTextFont
        $messageWidget configure -font $messageTextFont
    }
}

proc saveOptions {} {
    global options
    global configDir

    set f [ open [ file join $configDir "config" ] "w+" ]
    fconfigure $f -encoding utf-8
    puts $f {# This is autogenerated file. Do not edit it by hands.}
    puts $f {# If you want to make configuration that cannot be changed from GUI,}
    puts $f {# use "$configDir/userConfig" instead of "$configDir/config"(this file).}
    puts $f ""

    foreach {category optList} $options {
        foreach {item type var opt} $optList {
            puts $f "# $category :: $item"
            if [ array exists ::$var ] {
                puts -nonewline $f "array set "
                puts -nonewline $f $var
                puts -nonewline $f " {"
                puts -nonewline $f [ array get ::$var ]
                puts $f "}\n"
            } else {
                puts -nonewline $f "set "
                puts -nonewline $f $var
                puts -nonewline $f " {"
                puts -nonewline $f [ set ::$var ]
                puts $f "}\n"
            }
        }
    }
    close $f
}

proc discardOptions {} {
    global options optionsTmp

    catch {destroy .optionsDialog}
    array unset optionsTmp
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

proc addListItem {w} {
    global nickToIgnore

    set nickToIgnore ""

    inputStringDialog "Ignore list" "Enter nick:" nickToIgnore "$w insert end \$nickToIgnore"
}

proc removeListItem {w} {
    foreach item [ lsort -integer -decreasing [ $w curselection ] ] {
        $w delete $item
    }
}

proc nextUnread {w item} {
    set cur [ processItems $w $item [ list matchUnreadItem $w ] ]
    if { $cur != "" } {
        setFocusedItem $w $cur
        click $w $cur
    }
}

proc matchUnreadItem {w item} {
    return [ expr [ getItemValue $w $item unread ] != "1" ]
}

proc openContextMenu {w menu} {
    set item [ $w focus ]
    if { $item != "" } {
        set bbox [ $w bbox $item ]
        set x [ lindex $bbox 0 ]
        set y [ lindex $bbox 1 ]
        set xx [ expr [ winfo rootx $w ] + $x ]
        set yy [ expr [ winfo rooty $w ] + $y ]
        incr x [ expr [ lindex $bbox 2 ] / 2 ]
        incr y [ expr [ lindex $bbox 3 ] / 2 ]
        popupMenu $menu $xx $yy $x $y
    }
}

proc inputStringDialog {title label var script} {
    set f .inputStringDialog
    set okScript [ join [ list "destroy $f" $script ] ";" ]
    set cancelScript "destroy $f"

    toplevel $f
    wm title $f $title
    pack [ ttk::label $f.label -text $label ] -fill x
    pack [ ttk::entry $f.entry -textvariable $var ] -fill x
    pack [ ttk::button $f.ok -text "OK" -command $okScript ] [ ttk::button $f.cancel -text "Cancel" -command $cancelScript ] -side left
    update
    centerToParent $f .
    grab $f
    focus $f.entry
    bind $f <Escape> $cancelScript
}

proc find {} {
    global findPos
    global topicWidget

    set findPos [ $topicWidget focus ]

    inputStringDialog "Search" "Search regexp:" findString {findNext}
}

proc findNext {} {
    upvar #0 topicWidget w
    global appName
    global findString findPos

    set cur [ processItems $w $findPos [ list matchItemText $w $findString ] ]
    set findPos $cur

    if { $cur != "" } {
        setFocusedItem $w $cur
        click $w $cur
    } else {
        tk_messageBox -title $appName -message "Message not found!" -icon info
    }
}

proc matchItemText {w sub item} {
    return [ expr [ regexp -nocase -- $sub [ getItemValue $w $item msg ] ] == "0" ]
}

proc processItems {w item script} {
    set fromChild 0
    for {set cur $item} 1 {set cur $next} {
        if { !$fromChild } {
            set next [ lindex [ $w children $cur ] 0 ]
        } else {
            set next ""
        }
        set fromChild 0
        if { $next == "" } {
            set next [ $w next $cur ]
            if { $next == "" } {
                set next [ $w parent $cur ]
                set fromChild 1
            }
        }
        if { $next != "" && !$fromChild } {
            if { ![ eval "$script $next" ] } {
                return $next
            }
        }
        if { $next == "" } {
            return ""
        }
    }
}

proc setFocusedItem {w item} {
    $w see $item
    $w focus $item
    $w selection set $item
}

proc updateWindowTitle {} {
    global appName
    global topicWidget
    global topicHeader
    global currentTopic

    set s $appName
    if { $currentTopic != "" } {
        append s ": $topicHeader"
        set k [ getItemValue $topicWidget {} unreadChild ]
        if { $k != "0" } {
            append s " \[ $k new \]"
        }
    }
    wm title . $s
}

proc clearOldTopics {} {
    global configDir threadSubDir appName
    upvar #0 allTopicsWidget w

    set topics ""

    startWait "Searching for obsolete topics..."
    if [ catch {
        foreach fname [ glob -directory [ file join $configDir $threadSubDir ] -types f {{*,*.topic}} ] {
            regsub -lineanchor -nocase {^.*?(\d+)(?:\.topic){0,1}$} $fname {\1} fname
            if { [ lsearch -exact $topics $fname ] == -1 && ! [ $w exists $fname ] } {
                lappend topics $fname
            }
        }
    } ] {
        set topics ""
    }
    stopWait

    set count [ llength $topics ]

    if { $count == "0" } {
        tk_messageBox -type ok -icon info -message "There are no obsolete topics." -title $appName
        return
    } elseif { [ tk_messageBox -type yesno -default no -icon question -message "$count obsolete topic(s) will be deleted.\nDo you want to continue?" -title $appName ] != yes } {
        return
    }

    startWait "Deleting obsolete topics..."
    foreach id $topics {
        catch {
            file delete [ file join $configDir $threadSubDir $id ]
        }
        catch {
            file delete [ file join $configDir $threadSubDir "$id.topic" ]
        }
    }
    stopWait
}

proc ignoreUser {w item} {
    global ignoreList

    set nick [ getItemValue $w $item nick ]
    if { [ lsearch -exact $ignoreList [ getItemValue $w $item nick ] ] == -1 } {
        lappend ignoreList $nick
    }
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

if {! [ file exists [ file join $configDir "config" ] ] } {
    showOptionsDialog
}

if { $updateOnStart == "1" } {
    updateTopicList
}
