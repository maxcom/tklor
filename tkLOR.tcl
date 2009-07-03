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
#    51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA               #
############################################################################

# \
exec wish "$0" "$@"

package require Tk 8.4
package require tile 0.8
package require http 2.0
package require autoproxy
package require htmlparse 1.1
package require struct::stack 1.3

set appName "tkLOR"
set appVersion "APP_VERSION"
set appId "$appName $appVersion $tcl_platform(os) $tcl_platform(osVersion) $tcl_platform(machine)"
set appHome "http://code.google.com/p/tklor/"

set configDir [ file join $::env(HOME) ".$appName" ]
set threadSubDir "threads"

set lorUrl "www.linux.org.ru"

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
set userTagList [ list [ list anonymous JOPA ] ]

set messageMenu ""
set topicMenu ""
set topicTextMenu ""
set messageTextMenu ""

set autonomousMode 0
set expandNewMessages 1
set updateOnStart 0
set doubleClickAllTopics 0

set tileTheme "default"

set findString ""
set findPos ""

set lastId -1
set waitDeep 0

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

array set fontPart {
    none ""
    item "-family Sans"
    unread "-weight bold"
    child "-slant italic"
    ignored "-overstrike 1"
}

array set color {
    htmlFg "black"
    htmlBg "white"
}

set options {
    "Global" {
        "Widget theme"  readOnlyCombo   tileTheme   { ttk::style theme names }
        "Start in autonomous mode"  check   autonomousMode ""
        "Update topics list on start"    check   updateOnStart ""
        "Use double-click to open topic"    check   doubleClickAllTopics ""
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
        "Ignore list"   ignoreList    ignoreList { list "Nick" }
    }
    "User tags" {
        "Tags"  userTagList userTagList { list "Nick" "Tag" }
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
    "Message text" {
        "font"  font    messageTextFont ""
        "Font color"    color   color(htmlFg) ""
        "Background"    color   color(htmlBg) ""
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
    $m add command -label "Tag user..." -command {invokeMenuCommand $allTopicsWidget tagUser}
    $m add command -label "Open in browser" -command {invokeMenuCommand $allTopicsWidget topicOpenMessage}
    $m add command -label "Go to next unread" -accelerator n -command {invokeMenuCommand $allTopicsWidget nextUnread}
    $m add separator
    $m add command -label "Move to favorites..." -command {invokeMenuCommand $allTopicsWidget addToFavorites}
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
    $m add command -label "Tag user..." -command {invokeMenuCommand $topicWidget tagUser}
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
    $topicMenu add command -label "Tag user..." -command {invokeItemCommand $allTopicsWidget tagUser}
    $topicMenu add command -label "Open in browser" -command {invokeItemCommand $allTopicsWidget topicOpenMessage}
    $topicMenu add separator
    $topicMenu add command -label "Move to favorites..." -command {invokeItemCommand $allTopicsWidget addToFavorites}
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
    $messageMenu add command -label "Tag user..." -command {invokeItemCommand $topicWidget tagUser}
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
    global forumGroups

    set f [ ttk::frame .allTopicsFrame -width 250 ]
    set allTopicsWidget [ ttk::treeview $f.allTopicsTree -columns {nick unread unreadChild parent text} -displaycolumns {unreadChild} -yscrollcommand "$f.scroll set" ]

    configureTags $allTopicsWidget
    $allTopicsWidget heading #0 -text "Title" -anchor w
    $allTopicsWidget heading unreadChild -text "Threads" -anchor w
    $allTopicsWidget column #0 -width 220
    $allTopicsWidget column unreadChild -width 30 -stretch 0

    $allTopicsWidget insert "" end -id news -text "News" -values [ list "" 0 0 "" "News" ]
    updateItemState $allTopicsWidget "news"

    $allTopicsWidget insert "" end -id gallery -text "Gallery" -values [ list "" 0 0 "" "Gallery" ]
    updateItemState $allTopicsWidget "gallery"

    $allTopicsWidget insert "" end -id votes -text "Votes" -values [ list "" 0 0 "" "Votes" ]
    updateItemState $allTopicsWidget "votes"

    $allTopicsWidget insert "" end -id forum -text "Forum" -values [ list "" 0 0 "" "Forum" ]
    foreach {id title} $forumGroups {
        $allTopicsWidget insert forum end -id "forum$id" -text $title -values [ list "" 0 0 "forum" $title ]
        updateItemState $allTopicsWidget "forum$id"
    }
    updateItemState $allTopicsWidget "forum"

    $allTopicsWidget insert "" end -id favorites -text "Favorites" -values [ list "" 0 0 "" "Favorites" ]
    updateItemState $allTopicsWidget "favorites"

    ttk::scrollbar $f.scroll -command "$allTopicsWidget yview"
    pack $f.scroll -side right -fill y
    pack $allTopicsWidget -expand yes -fill both
    return $f
}

proc initTopicText {} {
    global topicTextWidget
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
    set topicTextWidget [ text $f.msg -state disabled -yscrollcommand "$f.scroll set" -setgrid true -wrap word -height 5 ]

    ttk::scrollbar $f.scroll -command "$topicTextWidget yview"
    pack $f.scroll -side right -fill y
    pack $topicTextWidget -expand yes -fill both
    pack $f -expand yes -fill both

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

    ttk::scrollbar $f.scrollx -command "$topicWidget xview" -orient horizontal
    ttk::scrollbar $f.scrolly -command "$topicWidget yview"
    grid $topicWidget $f.scrolly -sticky nswe
    grid $f.scrollx x -sticky nswe
    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 0 -weight 1

    return $f
}

proc initMessageWidget {} {
    global messageWidget
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

    set messageWidget [ text $mf.msg -state disabled -yscrollcommand "$mf.scroll set" -setgrid true -wrap word -height 10 ]
    ttk::scrollbar $mf.scroll -command "$messageWidget yview"
    pack $mf.scroll -side right -fill y
    pack $messageWidget -expand yes -fill both

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

    .horPaned add [ initAllTopicsTree ] -weight 0

    ttk::panedwindow .vertPaned -orient vertical
    .horPaned add .vertPaned -weight 1

    .vertPaned add [ initTopicText ] -weight 0
    .vertPaned add [ initTopicTree ] -weight 0
    .vertPaned add [ initMessageWidget ] -weight 1
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
    set msg [ string trim $msg ]
    $w configure -state normal
    $w delete 0.0 end

    foreach tag [ $w tag names ] {
        $w tag delete $tag
    }

    $w tag configure br -background white
    $w tag configure i -font {-slant italic}
    $w tag configure hyperlink
    $w tag bind hyperlink <Enter> "$w configure -cursor hand1"
    $w tag bind hyperlink <Leave> "$w configure -cursor {}"

    set stackId [ join [ list "stack" [ generateId ] ] "" ]
    ::struct::stack $stackId

    ::htmlparse::parse -cmd [ list "renderHtmlTag" $w $stackId ] " $msg"

    $stackId destroy

    $w yview 0.0
    $w configure -state disabled
}

proc renderHtmlTag {w stack tag slash param text} {
    global lorUrl

    set text [ replaceHtmlEntities $text ]
    regsub -lineanchor -- {^[\n\r \t]+} $text {} text
    regsub -lineanchor -- {[\n\r \t]+$} $text { } text
    set tag [ string tolower $tag ]
    set pos [ $w index end-1chars ]
    if { $slash != "/" } {
        switch -exact -- $tag {
            i {
                $stack push [ list $tag $pos ]
            }
            br {
                $w insert end "\n"
            }
            p {
                if { [ $w get 0.0 end ] != "\n" } {
                    $w insert end "\n\n"
                }
                $stack push [ list $tag $pos ]
            }
            li {
                $w insert end "\n* "
            }
            a {
                if [ regexp -- {href="{0,1}([^"> ]+)"{0,1}} $param dummy url ] {
                    if { ![ regexp -lineanchor {^\w+://} $url ] } {
                        set url "http://$lorUrl/$url"
                    }
                    set tagName [ join [ list "link" [ generateId ] ] "" ]
                    $w tag configure $tagName -underline 1 -foreground blue
                    $w tag bind $tagName <ButtonPress-1> [ list "openUrl" $url ]
                    $stack push [ list $tagName $pos ]
                } else {
                    $stack push [ list $tag $pos ]
                }
            }
            img {
                set text {[]}
            }
        }
    } else {
        switch -exact -- $tag {
            a -
            i -
            p {
                catch {
                    set list [ $stack pop ]
                    $w tag add [ lindex $list 0 ] [ lindex $list 1 ] [ $w index end-1chars ]
                    if { $tag == "a" } {
                        $w tag add hyperlink [ lindex $list 1 ] [ $w index end-1chars ]
                    }
                }
                if { $tag == "a" } {
                    $w insert end " "
                }
            }
            tr {
                $w insert end "\n"
            }
            td {
                $w insert end "\t"
            }
        }
    }
    $w insert end $text
}

proc updateTopicText {id header msg nick time} {
    global topicTextWidget
    global allTopicsWidget
    global topicHeader topicNick topicTime

    renderHtml $topicTextWidget $msg
    set topicHeader $header
    set topicNick $nick
    set topicTime $time

    if { [ $allTopicsWidget exists $id ] } {
        setItemValue $allTopicsWidget $id nick $nick
        updateItemState $allTopicsWidget $id
    }
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

    focus $topicWidget
    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    startWait "Loading topic"

    if { $topic != $currentTopic } {
        setItemValue $topicWidget "" unreadChild 0

        clearTreeItemChildrens $topicWidget ""
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
    if [ regexp -- {<div class=msg>(?:<table><tr><td valign=top align=center><a [^>]*><img [^>]*></a></td><td valign=top>){0,1}<h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)(?:<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i>){0,1}</div>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        set topicText $msg
        set topicNick $nick
        set topicTime $time
        set topicHeader [ htmlToText $header ]
        saveTopicTextToCache $topic [ htmlToText $header ] $topicText $nick $time $approver $approveTime
    } else {
        set topicText "Unable to parse topic text :("
        set topicNick ""
        set topicHeader ""
        set topicTime ""
        saveTopicTextToCache $topic "" $topicText "" "" "" ""
    }
    updateTopicText $topic $topicHeader $topicText $topicNick $topicTime
}

proc parsePage {topic data} {
    upvar #0 topicWidget w

    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}(?:&amp;page=\d+){0,1}#(\d+)"[^>]*>[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div>} $message dummy2 parent parentNick id header msg nick time ] {
            if { ! [ $w exists $id ] } {
                $w insert $parent end -id $id -text $nick
                foreach i {nick time msg parent parentNick} {
                    setItemValue $w $id $i [ set $i ]
                }
                setItemValue $w $id header [ htmlToText $header ]
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
    if { ![ string is integer [ getItemValue $w $item unreadChild ] ] } {
        setItemValue $w $item unreadChild 0
    }
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
    global ignoreList userTagList

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

    set text [ getItemText $w $item ]
    foreach i $userTagList {
        if { [ lindex $i 0 ] == [ getItemValue $w $item nick ] } {
            append text [ join [ list " (" [ lindex $i 1 ] ")" ] "" ]
        }
    }
    $w item $item -text $text
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

    updateTopicText "" "" "" "" ""
    catch {
        array set res [ lindex [ parseMbox [ file join $configDir $threadSubDir [ join [ list $topic ".topic" ] "" ] ] ] 0 ]
        updateTopicText $topic $res(Subject) $res(body) $res(From) $res(X-LOR-Time)
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
    global waitDeep

    if { $text == "" } {
        set text "Please, wait..."
    }

    if { $waitDeep == "0" } {
        . configure -cursor watch
        grab $statusBarWidget
        $statusBarWidget configure -text "$text..."
    }
    incr waitDeep
}

proc stopWait {} {
    global statusBarWidget
    global waitDeep

    incr waitDeep -1
    if { $waitDeep == "0" } {
        grab release $statusBarWidget
        $statusBarWidget configure -text ""
        . configure -cursor ""
    }
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

proc updateTopicList {{section ""}} {
    global forumGroups
    global autonomousMode
    global appName

    if { $autonomousMode } {
        if { [ tk_messageBox -title $appName -message "Are you want to go to online mode?" -type yesno -icon question -default yes ] == yes } {
            set autonomousMode 0
        } else {
            return
        }
    }

    startWait "Updating topics list"
    if {$section == "" } {
        updateTopicList news
        updateTopicList gallery
        updateTopicList votes
        updateTopicList forum

        stopWait
        return
    }

    switch -glob -- $section {
        news {
            parseGroup $section 1
        }
        gallery {
            parseGroup $section 3
        }
        votes {
            parseGroup $section 5
        }
        forum {
            foreach {id title} $forumGroups {
                updateTopicList "forum$id"
            }
        }
        forum* {
            parseGroup $section 2 [ string trimleft $section "forum" ]
        }
        default {
            # No action at this moment
        }
    }
    stopWait
}

proc parseGroup {parent section {group ""}} {
    global lorUrl
    global appName

    set url "http://$lorUrl/section-rss.jsp?section=$section"
    if { $group != "" } {
        append url "&group=$group"
    }
    set err 1

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            set w $::allTopicsWidget
            foreach item [ $w children $parent ] {
                set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
                if { $count != "0" } {
                    addUnreadChild $w $parent "-$count"
                }
                $w delete $item
            }
            setItemValue $w $parent unreadChild 0

            parseRss [ ::http::data $token ] [ list "addTopicFromCache" $parent ]
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

proc addTopicFromCache {parent id nick text unread} {
    upvar #0 allTopicsWidget w

    if { ! [ $w exists $id ] } {
        $w insert $parent end -id $id
        $w children $parent [ lsort -decreasing [ $w children $parent ] ]

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
    global forumGroups
    global configDir

    catch {
        set f [ open [ file join $configDir "topics" ] "w+" ]
        fconfigure $f -encoding utf-8
        foreach group {news gallery votes forum favorites} {
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

    switch -regexp $item {
        {^news$} {
            openUrl "http://$lorUrl/add-section.jsp?section=1"
        }
        {^forum$} {
            openUrl "http://$lorUrl/add-section.jsp?section=2"
        }
        {^forum\d+$} {
            openUrl "http://$lorUrl/add.jsp?group=[ string trim $item forum ]"
        }
        {^gallery$} {
            openUrl "http://$lorUrl/add.jsp?group=4962"
        }
        {^votes$} {
            openUrl "http://$lorUrl/add-poll.jsp"
        }
        {^\d+$} {
            openUrl "http://$lorUrl/comment-message.jsp?msgid=$item"
        }
    }
}

proc topicUserInfo {w item} {
    global lorUrl
    openUrl "http://$lorUrl/whois.jsp?nick=[ getItemValue $w $item nick ]"
}

proc topicOpenMessage {w item} {
    global lorUrl

    switch -regexp $item {
        {^news$} {
            openUrl "http://$lorUrl/view-news.jsp?section=1"
        }
        {^forum$} {
            openUrl "http://$lorUrl/view-section.jsp?section=2"
        }
        {^forum\d+$} {
            openUrl "http://$lorUrl/group.jsp?group=[ string trim $item forum ]"
        }
        {^gallery$} {
            openUrl "http://$lorUrl/view-news.jsp?section=3"
        }
        {^votes$} {
            openUrl "http://$lorUrl/group.jsp?group=19387"
        }
        {^\d+$} {
            openUrl "http://$lorUrl/jump-message.jsp?msgid=$item"
        }
    }
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
    return [ ::htmlparse::mapEscapes $text ]
}

proc htmlToText {text} {
    foreach {re s} {
        {<img src="/\w+/\w+/votes\.gif"[^>]*>} "\[\\&\]"
        "<img [^>]*?>" "[image]"
        "<!--.*?-->" ""
        "<tr>" "\n"
        "</tr>" ""
        "</{0,1}table>" ""
        "</{0,1}td(?: colspan=\\d+){0,1}>" " "
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
        "\n{3,}" "\n\n" } {
        regsub -all -nocase -- $re $text $s text
    }
    return [ replaceHtmlEntities $text ]
}

proc addTopicToFavorites {w item category caption} {
    if { $category != "" && $item != $category } {
        set parentSave [ getItemValue $w $item parent ]
        set fromChildsSave [ $w children $parentSave ]
        $w detach $item
        set childs [ $w children $category ]
        set toChildsSave $childs
        lappend childs $item
        set childs [ lsort -decreasing $childs ]
        if [ catch {$w children $category $childs} ] {
            $w children $category $toChildsSave
            $w children $parentSave $fromChildsSave
            return
        }
        if [ getItemValue $w $item unread ] {
            addUnreadChild $w [ getItemValue $w $item parent ] -1
            addUnreadChild $w $category
        }
        setItemValue $w $item parent $category
    }
    setItemValue $w $item text $caption
    updateItemState $w $item
}

proc deleteTopic {w item} {
    if { ![ isCategoryFixed $item ] } {
        $w delete $item
    }
}

proc invokeItemCommand {w command args} {
    global mouseX mouseY

    set item [ $w identify row $mouseX $mouseY ]
    if { $item != "" } {
        eval [ join [ list [ list $command $w $item ] $args ] ]
        updateWindowTitle
    }
}

proc invokeMenuCommand {w command args} {
    set item [ $w focus ]
    if { $item != "" } {
        eval [ join [ list [ list $command $w $item ] $args ] ]
        updateWindowTitle
    }
}

proc clearTopicCache {w item} {
    global configDir threadSubDir

    if [ regexp -lineanchor {^\d+$} $item ] {
        mark $w $item item 1
        catch {
            file delete [ file join $configDir $threadSubDir $item ]
        }
        catch {
            file delete [ file join $configDir $threadSubDir "$item.topic" ]
        }
    }
}

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
            pack $v -anchor w -fill x
            pack $ff -anchor w -fill both
            pack $f -anchor w -fill both
            pack [ buttonBox $name \
                [ list -text "Add..." -command [ concat $addScript [ list $v ] ] ] \
                [ list -text "Modify..." -command [ concat $modifyScript [ list $v ] ] ] \
                [ list -text "Remove" -command "removeListItem $v" ]
            ] -fill x -side bottom
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
            pack [ ttk::button $name -text $val -command [ list chooseColor $w $name ] ] -anchor w -fill x
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

proc showOptionsDialog {} {
    global options
    global appName

    set d .optionsDialog
    catch {destroy $d}
    toplevel $d
    wm title $d "$appName options"
    set notebook [ ttk::notebook $d.notebook ]
    pack $notebook -fill both

    set n 0
    set okList ""
    foreach {category optList} $options {
        set page [ ttk::frame "$notebook.page$n" ]

        set o ""
        foreach {item type var opt} $optList {
            lappend o $item $type [ set ::$var ] $opt
        }

        lappend okList [ list \
            lambda {optList page ws} {
                set vals [ fetchOptionsFrameValues $optList $page $ws ]
                for {set i 0} {$i < [ llength $vals ]} {incr i} {
                    set var [ lindex $optList [ expr $i*4+2 ] ]
                    set ::$var [ lindex $vals $i ]
                }
                applyOptions
            } $optList $page [ generateOptionsFrame $d $o $page ] \
        ]

        $notebook add $page -sticky nswe -text $category
        incr n
    }
    lappend okList [ list "destroy" $d ]
    set okScript [ join $okList ";" ]
    set cancelScript [ list "destroy" $d ]

    set f [ ttk::frame $d.buttonFrame ]
    pack [ buttonBox $f \
        [ list -text "OK" -command $okScript ] \
        [ list -text "Cancel" -command $cancelScript ] \
    ] -fill x
    pack $f -fill x -side bottom
    update

    wm resizable $d 0 0
    wm protocol $d WM_DELETE_WINDOW $cancelScript
    centerToParent $d .
    grab $d
    bind $d <Return> $okScript
    bind $d <Escape> $cancelScript
}

proc applyOptions {} {
    global allTopicsWidget topicWidget
    global tileTheme
    global topicTextWidget messageWidget
    global messageTextFont
    global color

    initHttp

    configureTags $allTopicsWidget
    configureTags $topicWidget

    ttk::style theme use $tileTheme

    catch {$topicTextWidget configure -font $messageTextFont}
    catch {$topicTextWidget configure -foreground $color(htmlFg) -background $color(htmlBg)}

    catch {$messageWidget configure -font $messageTextFont}
    catch {$messageWidget configure -foreground $color(htmlFg) -background $color(htmlBg)}

    initBindings
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
                puts $f [ list "array" "set" $var [ array get ::$var ] ]
            } else {
                puts $f [ list "set" $var [ set ::$var ] ]
            }
            puts $f ""
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

proc addIgnoreListItem {w} {
    inputStringDialog "Ignore list" "Enter nick:" [ list $w "insert" "{}" "end" "-text" ]
}

proc modifyIgnoreListItem {w} {
    if { [ $w focus ] == "" } {
        addIgnoreListItem $w
    } else {
        inputStringDialog "Ignore list" "Enter nick:" [ list $w "item" "\[ $w focus \]" "-text" ] [ $w item [ $w focus ] -text ]
    }
}

proc removeListItem {w} {
    foreach item [ $w selection ] {
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

proc inputStringDialog {title label script {val ""}} {
    set f [ join [ list .inputStringDialog [ generateId ] ] "" ]

    toplevel $f
    wm title $f $title
    pack [ ttk::label $f.label -text $label ] -fill x
    pack [ ttk::entry $f.entry ] -fill x
    $f.entry insert end $val
    $f.entry selection range 0 end

    set okScript [ join \
        [ list \
            [ list "eval" [ join [ concat $script [ list "\[ $f.entry get \]" ] ] ] ] \
            [ list "destroy" "$f" ] \
        ] ";" \
    ]
    set cancelScript [ list "destroy" $f ]

    pack [ buttonBox $f \
        [ list -text "OK" -command $okScript ] \
        [ list -text "Cancel" -command $cancelScript ] \
    ] -side bottom -fill x

    update
    wm resizable $f 1 0
    centerToParent $f .
    grab $f
    focus $f.entry
    wm protocol $f WM_DELETE_WINDOW $cancelScript
    bind $f.entry <Return> $okScript
    bind $f <Escape> $cancelScript
}

proc find {} {
    global findPos findString
    global topicWidget

    set findPos [ $topicWidget focus ]

    inputStringDialog "Search" "Search regexp:" "findFirst" $findString
}

proc findFirst {str} {
    global findString
    set findString $str
    findNext
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
            if { ![ eval [ join [ list [ concat $script [ list $next ] ] ] ] ] } {
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

    startWait "Searching for obsolete topics"
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

    startWait "Deleting obsolete topics"
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

proc showFavoritesTree {title name script parent} {
    set f [ join [ list ".favoritesTreeDialog" [ generateId ] ] "" ]
    toplevel $f
    wm title $f $title

    pack [ ttk::label $f.label -text "Item name: " ] -fill x
    set nameWidget [ ttk::entry $f.itemName ]
    pack $nameWidget -fill x
    $nameWidget insert end $name

    pack [ ttk::label $f.categoryLabel -text "Category: " ] -fill x
    set categoryWidget [ ttk::treeview $f.category ]
    $categoryWidget heading #0 -text "Title" -anchor w
    pack $categoryWidget -fill both -expand yes

    fillCategoryWidget $categoryWidget $parent

    set okScript [ join \
        [ list \
            [ list "eval" [ join [ concat $script [ list "\[ $categoryWidget focus \]" "\[ $nameWidget get \]" ] ] ] ] \
            [ list "destroy" "$f" ] \
        ] ";" \
    ]
    set cancelScript "destroy $f"
    set newCategoryScript [ list showFavoritesTree "Select new category name and location" "New category" [ list "createCategory" "$categoryWidget" $f ] "\[ $categoryWidget focus \]" ]

    pack [ buttonBox $f \
        [ list -text "New category..." -command $newCategoryScript ] \
        [ list -text "OK" -command $okScript ] \
        [ list -text "Cancel" -command $cancelScript ] \
    ] -side bottom -fill x

    update
    centerToParent $f .
    grab $f
    focus $nameWidget
    wm protocol $f WM_DELETE_WINDOW $cancelScript
    bind $f.itemName <Return> $okScript
    bind $f.category <Return> $okScript
    bind $f <Escape> $cancelScript
}

proc generateId {} {
    global lastId

    incr lastId
    return $lastId
}

proc copyFavoritesCategory {from to item} {
    if { ![ regexp -lineanchor {^\d+$} $item ] } {
        $to insert [ getItemValue $from $item parent ] end -id $item -text [ getItemValue $from $item text ]
    }
    return 1
}

proc addToFavorites {w id} {
    global allTopicsWidget

    if { ![ isCategoryFixed $id ] } {
        showFavoritesTree {Select category and topic text} [ getItemValue $w $id text ] [ list addTopicToFavorites $allTopicsWidget $id ] [ getItemValue $allTopicsWidget $id parent  ]
    }
}

proc createCategory {categoryWidget parentWidget parent name} {
    upvar #0 allTopicsWidget w

    set id "category"
    while { [ $w exists $id ] } {
        set id [ join [ list "category" [ generateId ] ] "" ]
    }

    $w insert $parent end -id $id -text $name
    setItemValue $w $id text $name
    setItemValue $w $id parent $parent
    setItemValue $w $id nick ""
    setItemValue $w $id unread 0
    setItemValue $w $id unreadChild 0
    updateItemState $w $id

    clearTreeItemChildrens $categoryWidget ""
    fillCategoryWidget $categoryWidget $parentWidget
    setFocusedItem $categoryWidget $id
}

proc fillCategoryWidget {categoryWidget parent} {
    global allTopicsWidget

    $categoryWidget insert {} end -id favorites -text Favorites
    processItems $allTopicsWidget "favorites" [ list copyFavoritesCategory $allTopicsWidget $categoryWidget ]
    if [ catch {setFocusedItem $categoryWidget $parent} ] {
        setFocusedItem $categoryWidget "favorites"
    }
}

proc clearTreeItemChildrens {w parent} {
    foreach item [ $w children $parent ] {
        $w delete $item
    }
}

proc buttonBox {parent args} {
    set f [ ttk::frame $parent.buttonBox ]
    set b ""
    set i 0
    foreach p $args {
        set b [ concat [ eval [ concat [ list "ttk::button" "$f.button$i" ] $p ] ] $b ]
        incr i
    }
    eval "pack $b -side right"
    return $f
}

proc isCategoryFixed {id} {
    return [ expr {
        $id == "" || \
        $id == "news" || \
        $id == "gallery" || \
        $id == "votes" || \
        [ regexp -lineanchor {^forum\d*$} $id ] || \
        $id == "favorites" \
    } ]
}

proc parseRss {data script} {
    global configDir threadSubDir

    #decoding binary data
    set data [ encoding convertfrom "utf-8" $data ]

    foreach {dummy1 item} [ regexp -all -inline -- {<item>(.*?)</item>} $data ] {
        array set v {
            title ""
            link ""
            guid ""
            pubDate ""
            description ""
        }
        foreach {dummy2 tag content} [ regexp -all -inline -- {<(\w+)>([^<]*)</\w+>} $item ] {
            array set v [ list $tag $content ]
        }
        if { ![ regexp -lineanchor {msgid=(\d+)$} $v(link) dummy3 id ] } {
            puts $dummy3
            continue
        }
        set header [ htmlToText [ replaceHtmlEntities $v(title) ] ]
        set msg $v(description)
        # at this moment nick field are not present in RSS feed
        set nick ""
        set msg [ string trim [ replaceHtmlEntities $msg ] ]
        eval [ concat $script [ list $id $nick $header [ expr ! [ file exists [ file join $configDir $threadSubDir "$id.topic" ] ] ] ] ]
    }
}

proc initBindings {} {
    global allTopicsWidget topicWidget
    global topicTextWidget messageWidget
    global doubleClickAllTopics

    foreach i {<<TreeviewSelect>> <Double-Button-1> <Return>} {
        bind $allTopicsWidget $i ""
    }

    if { $doubleClickAllTopics == "0" } {
        bind $allTopicsWidget <<TreeviewSelect>> {invokeMenuCommand $allTopicsWidget click}
    } else {
        bind $allTopicsWidget <Double-Button-1> {invokeMenuCommand $allTopicsWidget click}
        bind $allTopicsWidget <Return> {invokeMenuCommand $allTopicsWidget click}
    }
    bind $allTopicsWidget <ButtonPress-3> {popupMenu $topicMenu %X %Y %x %y}
    bind $allTopicsWidget n {invokeMenuCommand $allTopicsWidget nextUnread}
    bind $allTopicsWidget N {invokeMenuCommand $allTopicsWidget nextUnread}
    bind $allTopicsWidget <Menu> {openContextMenu $allTopicsWidget $topicMenu}

    bind $topicTextWidget <ButtonPress-3> {popupMenu $topicTextMenu %X %Y %x %y}

    bind $topicWidget <<TreeviewSelect>> {invokeMenuCommand $topicWidget click}
    bind $topicWidget <ButtonPress-3> {popupMenu $messageMenu %X %Y %x %y}

    bind $topicWidget n {invokeMenuCommand $topicWidget nextUnread}
    bind $topicWidget N {invokeMenuCommand $topicWidget nextUnread}
    bind $topicWidget <Menu> {openContextMenu $topicWidget $messageMenu}

    bind $messageWidget <ButtonPress-3> {popupMenu $messageTextMenu %X %Y %x %y}

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
}

proc chooseColor {parent w} {
    set color [ tk_chooseColor -initialcolor [ $w cget -text ] -parent $parent ]
    if { $color != "" } {
        $w configure -text $color
    }
}

proc tagUser {w item} {
    global userTagList

    set nick [ getItemValue $w $item nick ]
    for {set i 0} {$i < [ llength $userTagList ]} {incr i} {
        set item [ lindex $userTagList $i ]
        if { [ lindex $item 0 ] == $nick } {
            onePageOptionsDialog "Modify user tag" [ list \
                "Nick"  string nick $nick "" \
                "Tag"   string tag  [ lindex $item 1 ] "" \
            ] [ list \
                lambda {w pos vals} {
                    global userTagList
                    array set arr $vals
                    lset userTagList $pos [ list $arr(nick) $arr(tag) ]
                    array unset arr
                } $w $i \
            ]
            return
        }
    }
    onePageOptionsDialog "Add user tag" [ list \
        "Nick"  string nick $nick "" \
        "Tag"   string tag  "" "" \
    ] [ list \
        lambda {w vals} {
            global userTagList
            array set arr $vals
            lappend userTagList [ list $arr(nick) $arr(tag) ]
            array unset arr
        } $w \
    ]
}

proc addUserTagListItem {w} {
    onePageOptionsDialog "Add user tag" {
        "Nick"  string nick "" ""
        "Tag"   string tag  "" ""
    } [ list \
        lambda {w vals} {
            array set arr $vals
            $w insert {} end -text $arr(nick) -values $arr(tag)
            array unset arr
        } $w \
    ]
}

proc modifyUserTagListItem {w} {
    set id [ $w focus ]
    if { $id == "" } {
        addUserTagListItem $w
    } else {
        onePageOptionsDialog "Modify user tag" [ list \
            "Nick"  string nick [ $w item $id -text ] "" \
            "Tag"   string tag  [ lindex [ $w item $id -values ] 0 ] "" \
        ] [ list \
            lambda {w id vals} {
                array set arr $vals
                $w item $id -text $arr(nick) -values $arr(tag)
                array unset arr
            } $w $id \
        ]
    }
}

proc generateOptionsFrame {d optList page} {
    set ws ""
    set i 0

    foreach {item type val opt} $optList {
        set f [ ttk::frame "$page.item$i" -padding 1 ]
        lappend ws $f

        switch -exact -- $type {
            font -
            fontPart {
                array set ff $val
                set names [ array names ff ]
                foreach param {family size weight slant underline overstrike} {
                    if { [ lsearch -exact $names "-$param" ] == -1 } {
                        array set ff [ list "-$param" "" ]
                    }
                }
                generateOptionsFrame $d [ list \
                    "Family" editableCombo $ff(-family) { font families } \
                    "Size" string $ff(-size) "" \
                    "Weight" readOnlyCombo $ff(-weight) { list "" normal bold } \
                    "Slant" readOnlyCombo $ff(-slant) { list "" roman italic } \
                    "Underline" check $ff(-underline) "" \
                    "Overstrike" check $ff(-overstrike) "" \
                ] $f
                array unset ff
            }
            ignoreList {
                packOptionsItem $d $f.value $item "list" $val [ list [ eval $opt ] "addIgnoreListItem" "modifyIgnoreListItem" ]
            }
            userTagList {
                packOptionsItem $d $f.value $item "list" $val [ list [ eval $opt ] "addUserTagListItem" "modifyUserTagListItem" ]
            }
            default {
                packOptionsItem $d $f.value $item $type $val [ eval $opt ]
            }
        }

        pack $f -anchor w -fill x
        incr i
    }
    return $ws
}

proc fetchOptionsFrameValues {optList page ws} {
    set result ""
    set i 0
    foreach {item type var opt} $optList {
        switch -exact -- $type {
            font -
            fontPart {
                set s ""
                set j 0
                set v [ lindex $ws $i ]

                foreach {param t} {
                    family editableCombo
                    size string
                    weight readOnlyCombo
                    slant readOnlyCombo
                    underline check
                    overstrike check} {
                    set p [ getOptionsItemValue "$v.item$j.value" $t ]
                    if { $p != "" } {
                        lappend s [ list "-$param" $p ]
                    }
                    incr j
                }
                set res [ join $s ]
                if { $type == "font" && $res == "" } {
                    set res [ font actual system ]
                }
                lappend result $res
            }
            ignoreList -
            userTagList {
                lappend result [ getOptionsItemValue [ lindex $ws $i ].value "list" ]
            }
            default {
                lappend result [ getOptionsItemValue [ lindex $ws $i ].value $type ]
            }
        }
        incr i
    }
    return $result
}

proc onePageOptionsDialog {title optList script} {
    set d [ join [ list ".onePageOptionsDialog" [ generateId ] ] "" ]
    toplevel $d
    wm title $d $title
    set page [ ttk::frame $d.optFrame ]
    pack $page -fill both

    set n 0
    set okList ""
    set genList ""
    set fetchList ""
    foreach {item type var value opt} $optList {
        lappend genList $item $type $value $opt
        lappend fetchList $item $type $var $opt
    }
    lappend okList [ list \
        lambda {optList page ws script} {
            set vals [ fetchOptionsFrameValues $optList $page $ws ]
            set var ""
            for {set i 0} {$i < [ llength $vals ]} {incr i} {
                lappend var [ lindex $optList [ expr $i*4+2 ] ] [ lindex $vals $i ]
            }
            eval [ concat $script [ list $var ] ]
        } $fetchList $page [ generateOptionsFrame $d $genList $page ] $script \
    ]

    lappend okList [ list "destroy" $d ]
    set okScript [ join $okList ";" ]
    set cancelScript [ list "destroy" $d ]

    set f [ ttk::frame $d.buttonFrame ]
    pack [ buttonBox $f \
        [ list -text "OK" -command $okScript ] \
        [ list -text "Cancel" -command $cancelScript ] \
    ] -fill x
    pack $f -fill x -side bottom
    update

    wm resizable $d 0 0
    wm protocol $d WM_DELETE_WINDOW $cancelScript
    centerToParent $d .
    grab $d
    bind $d <Return> $okScript
    bind $d <Escape> $cancelScript
}

proc lambdaLowlevel {paramsVar scriptVar argsVar} {
    set params [ uplevel [ list set $paramsVar ] ]
    set script [ uplevel [ list set $scriptVar ] ]
    set args [ uplevel [ list set $argsVar ] ]
    uplevel [ list unset $paramsVar $scriptVar $argsVar ]
    for {set i 0} {$i < [ llength $params ]} {incr i} {
        uplevel [ list set [ lindex $params $i ] [ lindex $args $i ] ]
    }
    uplevel [ list eval $script ]
}

proc lambda {params script args} {
    if { [ llength $params ] != [ llength $args ] } {
        error "Arguments count mismatch!"
    }
    lambdaLowlevel params script args
}

############################################################################
#                                   MAIN                                   #
############################################################################

processArgv
loadConfig

initDirs

initMenu
initPopups
initMainWindow

applyOptions

update

loadTopicListFromCache

if {! [ file exists [ file join $configDir "config" ] ] } {
    showOptionsDialog
}

if { $updateOnStart == "1" } {
    updateTopicList
}
