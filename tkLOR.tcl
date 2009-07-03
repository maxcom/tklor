#!/bin/sh
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

# \
exec wish "$0" "$@"

package require Tcl 8.4
package require Tk 8.4
package require tile 0.8
package require htmlparse 1.1
package require struct::stack 1.3
package require msgcat 1.3

namespace import ::msgcat::*

set appName "tkLOR"
# will be set by backend callback method
set backendId ""

set appVersion "APP_VERSION"
set appId "$appName $appVersion $tcl_platform(os) $tcl_platform(osVersion) $tcl_platform(machine)"
set appHome "http://code.google.com/p/tklor/"
set bugzillaURL "http://code.google.com/p/tklor/issues/list"

set xdg_config_home ""
catch {set xdg_config_home $::env(XDG_CONFIG_HOME)}
if { $xdg_config_home == "" } {
    set xdg_config_home [ file join $::env(HOME) ".config" ]
}
set configDir [ file join $xdg_config_home $appName ]

set xdg_cache_home ""
catch {set xdg_cache_home $::env(XDG_CACHE_HOME)}
if { $xdg_cache_home == "" } {
    set xdg_cache_home [ file join $::env(HOME) ".cache" ]
}
set cacheDir [ file join $xdg_cache_home $appName ]

set wishPath [ auto_execok wish ]

if {[ string first Windows $tcl_platform(os) ] == -1} {
    set libDir "/usr/lib/tkLOR"
} else {
    set libDir ".\\lib"
}

############################################################################
#                                 VARIABLES                                #
############################################################################

set messageTextWidget ""
set topicTree ""
set messageTree ""
set horPane ""
set tasksWidget ""

set currentHeader ""
set currentNick ""
set currentTopic ""
set currentMessage ""

set topicHeader ""

set lorLogin ""
set lorPassword ""
set useProxy 0
set proxyAutoSelect 0
set proxyHost ""
set proxyPort ""
set proxyAuthorization 0
set proxyUser ""
set proxyPassword ""

set browser ""

set ignoreList ""
set userTagList {{maxcom "project coordinator"} {anonymous "spirit of LOR"}}

set messageMenu ""
set topicMenu ""
set messageTextMenu ""

set autonomousMode 0
set expandNewMessages 1
set updateOnStart 0
set doubleClickAllTopics 0
set markIgnoredMessagesAsRead 0
set threadListSize 20
set perspectiveAutoSwitch 0
set currentPerspective navigation
set navigationSashPos 50
set readingSashPos 20

set colorList {{tklor blue foreground}}
set colorCount [ llength $colorList ]

set tileTheme "default"

set findString ""
set findPos ""

set messageTextFont [ font actual system ]
set messageTextMonospaceFont "-family Courier"
set messageTextQuoteFont "-slant italic"

set forumVisibleGroups {126 1339 1340 1342 4066 4068 7300 8403 8404 9326 10161 19109}

set tasksWidgetVisible 0

set debug 0

set backendStarted 0

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
    "Global options" {
        "Widget theme"  readOnlyCombo   tileTheme   { ttk::style theme names }
        "Autonomous mode"   hidden  autonomousMode ""
        "Update topics list on start"    check   updateOnStart ""
        "Use double-click to open topic"    check   doubleClickAllTopics ""
        "Browser"   editableCombo   browser { list "sensible-browser" "opera" "mozilla" "konqueror" "iexplore.exe" }
        "Thread history size"   string  threadListSize ""
        "Expand new messages"   check   expandNewMessages   ""
        "Mark messages from ignored users as read"  check   markIgnoredMessagesAsRead ""
        "Auto-switch perspective"   check   perspectiveAutoSwitch ""
        "Current perspective"   hidden  currentPerspective ""
        "Sash position(navigation), %" string navigationSashPos ""
        "Sash position(reading), %" string readingSashPos ""
    }
    "Connection" {
        "LOR login" string  lorLogin ""
        "LOR password"  password    lorPassword ""
        "Use proxy" check   useProxy ""
        "Proxy auto-config" check   proxyAutoSelect ""
        "Proxy host"    string  proxyHost ""
        "Proxy port"    string  proxyPort ""
        "Proxy autorization"    check   proxyAuthorization ""
        "Proxy user"    string  proxyUser ""
        "Proxy password"    password    proxyPassword ""
    }
    "Ignored users" {
        "Ignore list"   list    ignoreList { list [ list "Nick" ] "addIgnoreListItem" "modifyIgnoreListItem" }
    }
    "User tags" {
        "Tags"  list    userTagList { list [ list "Nick" "Tag" ] "addUserTagListItem" "modifyUserTagListItem" }
    }
    "Colors" {
        "Message colors"    list    colorList { list [ list "Regexp" "Color" "Element" ] "addColorListItem" "modifyColorListItem" }
    }
    "Fonts" {
        "Normal font"  font    fontPart(item) ""
        "Unread font"  font    fontPart(unread) ""
        "Unread childs font"  font    fontPart(child) ""
        "Ignored font"  font    fontPart(ignored) ""
    }
    "Message text" {
        "Normal font"       font    messageTextFont ""
        "Monospace font"    font    messageTextMonospaceFont ""
        "Quote font"        font    messageTextQuoteFont ""
        "Message font color"        color   color(htmlFg) ""
        "Message background"        color   color(htmlBg) ""
    }
    "Forum groups" {
        "Visible forum groups"  selectList  forumVisibleGroups  {set lor::forumGroups}
    }
}

############################################################################
#                                 FUNCTIONS                                #
############################################################################

proc initMenu {} {
    global topicTree messageTree
    global messageMenu topicMenu messageTextMenu

    menu .menu -tearoff 0
    .menu add cascade -label [ mc "LOR" ] -menu .menu.lor -underline 0
    .menu add cascade -label [ mc "View" ] -menu .menu.view -underline 0
    .menu add cascade -label [ mc "Topic" ] -menu .menu.topic -underline 0
    .menu add cascade -label [ mc "Message" ] -menu .menu.message -underline 0
    .menu add cascade -label [ mc "Search" ] -menu .menu.search -underline 0
    .menu add cascade -label [ mc "Help" ] -menu .menu.help -underline 0

    set m [ menu .menu.lor -tearoff 0 ]
    $m add command -label [ mc "Search new topics" ] -accelerator "F2" -command updateTopicList
    $m add separator
    $m add checkbutton -label [ mc "Autonomous mode" ] -onvalue 1 -offvalue 0 -variable autonomousMode
    $m add command -label [ mc "Options..." ] -command showOptionsDialog
    $m add separator
    $m add command -label [ mc "Clear old topics..." ] -command clearOldTopics
    $m add separator
    $m add command -label [ mc "Exit" ] -accelerator "Alt-F4" -command exitProc

    set m [ menu .menu.view -tearoff 0 ]
    $m add radiobutton -label [ mc "Navigation perspective" ] -accelerator "Ctrl-Z" -command {setPerspective navigation -force} -value navigation -variable currentPerspective
    $m add radiobutton -label [ mc "Reading perspective" ] -accelerator "Ctrl-X" -command {setPerspective reading -force} -value reading -variable currentPerspective
    $m add separator
    $m add checkbutton -label [ mc "Auto switch" ] -onvalue 1 -offvalue 0 -variable perspectiveAutoSwitch

    set menuTopic [ menu .menu.topic -tearoff 0 ]
    set topicMenu [ menu .topicMenu -tearoff 0 ]
    set menuMessage [ menu .menu.message -tearoff 0 ]
    set messageMenu [ menu .messageMenu -tearoff 0 ]

    set m $menuMessage
    $m add command -label [ mc "Refresh messages" ] -accelerator "F5" -command refreshTopic
    $m add separator

    foreach {m invoke} [ list \
        $menuTopic invokeMenuCommand \
        $topicMenu invokeItemCommand ] {

        $m add command -label [ mc "Refresh sub-tree" ] -command [ list $invoke $topicTree refreshTopicSubList ] -accelerator "F4"
        $m add separator
    }

    set m $menuTopic
    $m add command -label [ mc "Add topic..." ] -command addTopic
    $m add separator

    foreach {m w invoke} [ list \
        $menuTopic $topicTree invokeMenuCommand \
        $topicMenu $topicTree invokeItemCommand \
        $menuMessage $messageTree invokeMenuCommand \
        $messageMenu $messageTree invokeItemCommand ] {

        $m add command -label [ mc "Reply" ] -accelerator "Ctrl-R" -command [ list $invoke $w reply ]
        $m add command -label [ mc "Open in browser" ] -accelerator "Ctrl-O" -command [ list $invoke $w openMessage ]
        $m add command -label [ mc "Go to next unread" ] -accelerator n -command [ list $invoke $w nextUnread ]
        $m add cascade -label [ mc "Mark" ] -menu $m.mark

        set mm [ menu $m.mark -tearoff 0 ]
        $mm add command -label [ mc "Mark as read" ] -command [ list $invoke $w mark message 0 ] -accelerator "M"
        $mm add command -label [ mc "Mark as unread" ] -command [ list $invoke $w mark message 1 ] -accelerator "U"
        $mm add command -label [ mc "Mark thread as read" ] -command [ list $invoke $w mark thread 0 ] -accelerator "Ctrl-M"
        $mm add command -label [ mc "Mark thread as unread" ] -command [ list $invoke $w mark thread 1 ] -accelerator "Ctrl-U"

        $mm add command -label [ mc "Mark all as read" ] -command [ list markAllMessages $w 0 ] -accelerator "Ctrl-Alt-M"
        $mm add command -label [ mc "Mark all as unread" ] -command [ list markAllMessages $w 1 ] -accelerator "Ctrl-Alt-U"

        $m add cascade -label [ mc "User" ] -menu $m.user

        set mm [ menu $m.user -tearoff 0 ]
        $mm add command -label [ mc "User info" ] -accelerator "Ctrl-I" -command [ list $invoke $w userInfo ]
        $mm add command -label [ mc "Ignore user" ] -command [ list $invoke $w ignoreUser ]
        $mm add command -label [ mc "Tag user..." ] -command [ list $invoke $w tagUser . ]
    }
    foreach {m invoke} [ list \
        $menuTopic invokeMenuCommand \
        $topicMenu invokeItemCommand ] {

        $m add separator
        $m add command -label [ mc "Move to favorites..." ] -command [ list $invoke $topicTree addToFavorites ]
        $m add command -label [ mc "Clear cache" ] -command [ list $invoke $topicTree clearTopicCache ]
        $m add command -label [ mc "Delete" ] -command [ list $invoke $topicTree deleteTopic ]
    }

    set m [ menu .menu.search -tearoff 0 ]
    $m add command -label [ mc "Find..." ] -accelerator "Ctrl-F" -command find
    $m add command -label [ mc "Find next" ] -accelerator "F3" -command findNext

    set m [ menu .menu.help -tearoff 0 ]
    $m add command -label [ mc "Project home" ] -command {openUrl $appHome}
    $m add command -label [ mc "Report bug" ] -command {openUrl $bugzillaURL}
    $m add command -label [ mc "About LOR" ] -command {openUrl "$::lor::lorUrl/server.jsp"}
    $m add separator
    $m add command -label [ mc "About" ] -command helpAbout -accelerator "F1"

    .  configure -menu .menu

    set m [ menu .messageTextMenu -tearoff 0 ]
    set messageTextMenu $m
    $m add command -label [ mc "Copy selection" ] -command {tk_textCopy $messageTextWidget}
    $m add command -label [ mc "Open selection in browser" ] -command {tk_textCopy $messageTextWidget;openUrl [ clipboard get ]}
}

proc initTopicTree {} {
    upvar #0 topicTree w
    global forumVisibleGroups

    set f [ ttk::frame .topicTreeFrame -width 250 -relief sunken ]
    set w [ ttk::treeview $f.w -columns {nick unread unreadChild parent text} -displaycolumns {unreadChild} -yscrollcommand "$f.scroll set" ]

    configureTags $w
    $w heading #0 -text [ mc "Title" ] -anchor w
    $w heading unreadChild -text [ mc "Threads" ] -anchor w
    $w column #0 -width 220
    $w column unreadChild -width 30 -stretch 0

    $w insert "" end -id news -text [ mc "News" ] -values [ list "" 0 0 "" [ mc "News" ] ]
    updateItemState $w "news"

    $w insert "" end -id gallery -text [ mc "Gallery" ] -values [ list "" 0 0 "" [ mc "Gallery" ] ]
    updateItemState $w "gallery"

    $w insert "" end -id votes -text [ mc "Votes" ] -values [ list "" 0 0 "" [ mc "Votes" ] ]
    updateItemState $w "votes"

    $w insert "" end -id forum -text [ mc "Forum" ] -values [ list "" 0 0 "" [ mc "Forum" ] ]
    foreach {id title} $::lor::forumGroups {
        if { [ lsearch $forumVisibleGroups $id ] != -1 } {
            $w insert forum end -id "forum$id" -text $title -values [ list "" 0 0 "forum" $title ]
            updateItemState $w "forum$id"
        }
    }
    sortChildrens $w "forum"
    updateItemState $w "forum"

    $w insert "" end -id favorites -text [ mc "Favorites" ] -values [ list "" 0 0 "" [ mc "Favorites" ] ]
    updateItemState $w "favorites"

    ttk::scrollbar $f.scroll -command "$w yview"
    pack $f.scroll -side right -fill y
    pack $w -expand yes -fill both
    return $f
}

proc initMessageTree {} {
    upvar #0 messageTree w

    set f [ ttk::frame .messageTreeFrame -relief sunken ]
    set w [ ttk::treeview $f.w -columns {nick header time msg unread unreadChild parent parentNick text} -displaycolumns {header time} -xscrollcommand "$f.scrollx set" -yscrollcommand "$f.scrolly set" ]
    $w heading #0 -text [ mc "Nick" ] -anchor w
    $w heading header -text [ mc "Header" ] -anchor w
    $w heading time -text [ mc "Time" ] -anchor w

    $w column header -width 1
    $w column time -width 1

    configureTags $w

    ttk::scrollbar $f.scrollx -command "$w xview" -orient horizontal
    ttk::scrollbar $f.scrolly -command "$w yview"
    grid $w $f.scrolly -sticky nswe
    grid $f.scrollx x -sticky nswe
    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 0 -weight 1

    return $f
}

proc initMessageWidget {} {
    global messageTextWidget
    global currentHeader currentNick currentPrevNick currentTime
    global messageTextFont

    set mf [ ttk::frame .msgFrame -relief sunken ]

    set width 10

    set f [ ttk::frame $mf.header ]
    pack [ ttk::label $f.label -text [ mc "Header: " ] -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentHeader ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.nick ]
    pack [ ttk::label $f.label -text [ mc "From: " ] -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentNick ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.prevNick ]
    pack [ ttk::label $f.label -text [ mc "To: " ] -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentPrevNick ] -side left
    pack $f -fill x

    set f [ ttk::frame $mf.time ]
    pack [ ttk::label $f.label -text [ mc "Time: " ] -width $width -anchor w ] [ ttk::label $f.entry -textvariable currentTime ] -side left
    pack $f -fill x

    set messageTextWidget [ text $mf.msg -state disabled -yscrollcommand "$mf.scroll set" -setgrid true -wrap word -height 10 ]
    ttk::scrollbar $mf.scroll -command "$messageTextWidget yview"
    pack $mf.scroll -side right -fill y
    pack $messageTextWidget -expand yes -fill both

    return $mf
}

proc initMainWindow {} {
    global appName
    global tileTheme
    global statusBarWidget
    global horPane

    wm protocol . WM_DELETE_WINDOW exitProc
    wm title . $appName

    set horPane [ ttk::panedwindow .horPaned -orient horizontal ]
    grid .horPaned -sticky nwse

    .horPaned add [ initTopicTree ] -weight 0

    ttk::panedwindow .vertPaned -orient vertical
    .horPaned add .vertPaned -weight 1

    .vertPaned add [ initMessageTree ] -weight 0
    .vertPaned add [ initMessageWidget ] -weight 1

    set statusBarWidget [ ttk::frame .statusBar -relief sunken -padding 1 ]
    grid \
        [ ttk::label $statusBarWidget.text -text "" ] \
        [ ttk::progressbar $statusBarWidget.progress -mode indeterminate -orient horizontal ] \
        [ ttk::button $statusBarWidget.button -text "^" -command toggleTaskList -width 1 ] \
        -sticky nswe
    $statusBarWidget.progress state disabled
    grid columnconfigure $statusBarWidget 0 -weight 1

    grid $statusBarWidget -sticky nswe

    grid columnconfigure . 0 -weight 1
    grid rowconfigure . 0 -weight 1
}

proc helpAbout {} {
    global appName appVersion

    tk_messageBox \
        -title [ mc "About %s" $appName ] \
        -message [ mc "%s %s\nClient for reading linux.org.ru written on Tcl/Tk/Tile.\nCopyright (c) 2008 Alexander Galanin (gaa at linux.org.ru)\nLicense: GPLv3" $appName $appVersion ] \
        -parent . \
        -type ok
}

proc exitProc {} {
    global appName
    global currentTopic
    global backendId

    saveTopicToCache $currentTopic
    saveTopicListToCache
    saveOptions
    catch {remoting::sendRemote -async $backendId exit}

    exit
}

proc renderHtml {w msg} {
    global messageTextMonospaceFont messageTextQuoteFont

    set msg [ string trim $msg ]
    $w configure -state normal
    $w delete 0.0 end

    foreach tag [ $w tag names ] {
        $w tag delete $tag
    }

    $w tag configure br -background white
    $w tag configure i -font $messageTextQuoteFont
    $w tag configure hyperlink
    $w tag configure pre -font $messageTextMonospaceFont

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
    set text [ ::htmlparse::mapEscapes $text ]
    regsub -lineanchor -- {^[\n\r \t]+} $text {} text
    regsub -lineanchor -- {[\n\r \t]+$} $text { } text
    set tag [ string tolower $tag ]
    set pos [ $w index end-1chars ]
    if { $slash != "/" } {
        switch -exact -- $tag {
            pre -
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
                        set url "$::lor::lorUrl/$url"
                    }
                    set tagName [ join [ list "link" [ generateId ] ] "" ]
                    $w tag configure $tagName -underline 1 -foreground blue
                    set url [ ::htmlparse::mapEscapes $url ]
                    regsub -all -- {%} $url {%%} url
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
            pre -
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

proc updateTopicText {id header nick} {
    global topicHeader
    global topicTree

    set topicHeader $header

    if { [ $topicTree exists $id ] } {
        setItemValue $topicTree $id nick $nick
        updateItemState $topicTree $id
    }
}

proc updateMessage {item} {
    global messageTextWidget
    global currentHeader currentNick currentPrevNick currentTime
    upvar #0 messageTree w

    set msg [ getItemValue $w $item msg ]
    set currentHeader [ getItemValue $w $item header ]
    set currentNick [ getItemValue $w $item nick ]
    set currentPrevNick [ getItemValue $w $item parentNick ]
    set currentTime [ getItemValue $w $item time ]

    renderHtml $messageTextWidget $msg
}

proc configureTags {w} {
    global fontPart
    global colorList
    global colorCount

    foreach a { none unread } {
        foreach b { none child } {
            foreach c { none ignored } {
                set id [ join [ list "item" $a $b $c ] "_" ]
                regsub -all {_none} $id "" id

                $w tag configure $id -font [ join [ list $fontPart(item) $fontPart($a) $fontPart($b) $fontPart($c) ] " " ]
            }
        }
    }

    for {set i 0} {$i < $colorCount} {incr i} {
        $w tag configure "color$i" -foreground "" -background ""
    }
    for {set i 0} {$i < [ llength $colorList ]} {incr i} {
        set color [ lindex [ lindex $colorList $i ] 1 ]
        set mode [ lindex [ lindex $colorList $i ] 2 ]
        if { $mode == "foreground" } {
            $w tag configure "color$i" -foreground $color -background ""
        } else {
            $w tag configure "color$i" -background $color -foreground ""
        }
    }
}

proc setTopic {topic} {
    global currentTopic appName
    global messageTree messageTextWidget
    global currentHeader currentNick currentPrevNick currentTime
    global autonomousMode
    global expandNewMessages
    global backendId

    stopAllTasks getMessageList
    update

    setPerspective reading
    focus $messageTree
    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    if { $topic != $currentTopic } {
        setItemValue $messageTree "" unreadChild 0

        clearTreeItemChildrens $messageTree ""
        foreach item {currentHeader currentNick currentPrevNick currentTime} {
            set $item ""
        }
        renderHtml $messageTextWidget ""

        set currentTopic $topic

        loadTopicTextFromCache $topic
        setFocusedItem $messageTree "topic"
        loadCachedMessages $topic
    }
    if { ! $autonomousMode } {
        defCallbackLambda processText {topic nick header text time approver approveTime} {
            if [ tkLor::taskManager::isTaskStopped getMessageList ] {
                return
            }
            saveTopicTextToCache $topic $header $text $nick $time $approver $approveTime
            set header [ htmlToText $header ]
            updateTopicText $topic $header $nick
            insertMessage topic $nick $header $time $text {} {} 1 force
        } $topic
        defCallbackLambda processMessage {w id nick header time msg parent parentNick} {
            global appName

            if [ tkLor::taskManager::isTaskStopped getMessageList ] {
                return
            }
            if [ catch {
                if { $parent == "" } {
                    set parent "topic"
                    set parentNick [ getItemValue $w "topic" nick ]
                }
                if { ![ $w exists $id ] } {
                    update
                    insertMessage $id $nick $header $time $msg $parent $parentNick 1
                }
            } err ] {
                errorProc [ mc "Error while inserting item %s:\n%s" $id $err ] $::errorInfo
            }
        } $messageTree
        defCallbackLambda finish {messageTree expandNewMessages} {
            if [ tkLor::taskManager::isTaskStopped getMessageList ] {
                taskCompleted getMessageList
                return
            }
            focus $messageTree
            update
            updateWindowTitle
            if { $expandNewMessages == "1" } {
                nextUnread $messageTree ""
                focus $messageTree
            }
            taskCompleted getMessageList
        } $messageTree $expandNewMessages

        addTask getMessageList remoting::sendRemote -async $backendId [ list lor::parseTopic $topic $processText $processMessage errorProcCallback $finish ]
    }
}

proc insertMessage {id nick header time msg parent parentNick unread {force ""}} {
    upvar #0 messageTree w
    global markIgnoredMessagesAsRead

    if [ $w exists $id ] {
        if { $force == ""} {
            return
        }
        set unread 0
    } else {
        $w insert $parent end -id $id -text $nick
        setItemValue $w $id unreadChild 0
    }
    foreach i {nick time msg parent parentNick} {
        setItemValue $w $id $i [ set $i ]
    }
    setItemValue $w $id header [ htmlToText $header ]
    setItemValue $w $id unread 0
    if { $unread && ( ![ isUserIgnored $nick ] || $markIgnoredMessagesAsRead != "1" ) } {
        mark $w $id item 1
    }
    updateItemState $w $id
    if { $id == "topic" } {
        $w item $id -open 1
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
    global topicTree
    mark $w $item item 0
    if { $w == $topicTree } {
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
    global messageTree
    if { $w == $messageTree } {
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
    global userTagList
    global colorList

    if { $item == "" } return

    set tag "item"
    if [ getItemValue $w $item unread ] {
        append tag "_unread"
    }
    if [ getItemValue $w $item unreadChild ] {
        append tag "_child"
    }
    if [ isUserIgnored [ getItemValue $w $item nick ] ] {
        append tag "_ignored"
    }
    set tagList [ list $tag ]

    if { $w == $::topicTree } {
        set text [ getItemValue $w $item text ]
    } else {
        set text [ getItemValue $w $item msg ]
    }
    for {set i 0} {$i < [ llength $colorList ] } {incr i} {
        set re [ lindex [ lindex $colorList $i ] 0 ]
        if [ regexp -nocase -lineanchor -- $re $text ] {
            lappend tagList "color$i"
        }
    }

    $w item $item -tags $tagList

    set text [ getItemText $w $item ]
    foreach i $userTagList {
        if { [ lindex $i 0 ] == [ getItemValue $w $item nick ] } {
            append text [ join [ list " (" [ lindex $i 1 ] ")" ] "" ]
        }
    }
    $w item $item -text $text
}

proc addTopic {} {
    deflambda processTopicAddition {str} {
        global topicTree
        set id ""
        regexp {msgid=(\d+)} $str dummy id
        regexp -lineanchor {^(\d+)$} $str dummy id
        if { $id != "" } {
            if { ![ $topicTree exists $id ] } {
                addTopicFromCache "favorites" $id "" $str 1
                showFavoritesTree [ mc "Select category and topic text" ] $str [ list addTopicToFavorites $topicTree $id ] "favorites" .
            } else {
                setFocusedItem $topicTree $id
            }
        }
    }
    inputStringDialog \
        -title [ mc "Add topic" ] \
        -label [ mc "Enter topic ID or URL" ] \
        -script $processTopicAddition \
        -parent .
}

proc refreshTopic {} {
    global currentTopic

    if { $currentTopic != "" } {
        setTopic $currentTopic
    }
}

proc initDirs {} {
    global configDir cacheDir

    file mkdir $configDir
    file mkdir $cacheDir
}

proc saveTopicTextToCache {topic header text nick time approver approveTime} {
    global configDir cacheDir

    set fname [ file join $cacheDir [ join [ list $topic ".topic" ] "" ] ]
    set letter ""
    lappend letter "From" $nick
    lappend letter "Subject" $header
    lappend letter "X-LOR-Time" $time
    lappend letter "X-LOR-Unread" 0
    lappend letter "X-LOR-Approver" $approver
    lappend letter "X-LOR-Approve-Time" $approveTime
    lappend letter "body" $text
    ::gaa::mbox::writeToFile $fname [ list $letter ] -encoding utf-8
}

proc loadTopicTextFromCache {topic} {
    global cacheDir

    updateTopicText "" "" ""
    catch {
        set fname [ file join $cacheDir [ join [ list $topic ".topic" ] "" ] ]
        deflambda script {topic letter} {
            array set res $letter
            updateTopicText $topic $res(Subject) $res(From)
            insertMessage "topic" $res(From) $res(Subject) $res(X-LOR-Time) $res(body) "" "" 0
        } $topic
        ::gaa::mbox::parseFile $fname $script -encoding utf-8
    }
}

proc saveMessage {topic id header text nick time replyTo replyToId unread} {
    global cacheDir

    set fname [ file join $cacheDir $topic ]
    set letter ""
    lappend letter "From" $nick
    lappend letter "Subject" $header
    lappend letter "X-LOR-Time" $time
    lappend letter "X-LOR-Id" $id
    lappend letter "X-LOR-Unread" $unread
    if { $replyTo != "" } {
        lappend letter "To" $replyTo
        lappend letter "X-LOR-ReplyTo-Id" $replyToId
    }
    lappend letter "body" $text
    ::gaa::mbox::writeToFile $fname [ list $letter ] -append -encoding utf-8
}

proc loadCachedMessages {topic} {
    global cacheDir
    upvar #0 messageTree w

    set fname [ file join $cacheDir $topic ]
    deflambda processLetter {letter} {
        array set res $letter
        catch {
            if { [ lsearch -exact [ array names res ] "To" ] != -1 } {
                set parentNick $res(To)
                set parent $res(X-LOR-ReplyTo-Id)
            } else {
                set parentNick ""
                set parent ""
            }
            #for all items without parent it assumed to "topic"
            if { $parent == "" } {
                set parent "topic"
            }
            insertMessage $res(X-LOR-Id) $res(From) $res(Subject) $res(X-LOR-Time) $res(body) $parent $parentNick $res(X-LOR-Unread)
        }
        array unset res
    }
    catch {
        ::gaa::mbox::parseFile $fname $processLetter -encoding utf-8
    }
}

proc clearDiskCache {topic} {
    global cacheDir

    set f [ open [ file join $cacheDir $topic ] "w+" ]
    close $f
}

proc saveTopicRecursive {topic item} {
    upvar #0 messageTree w

    foreach id [ $w children $item ] {
        saveMessage $topic $id [ getItemValue $w $id header ] [ getItemValue $w $id msg ] [ getItemValue $w $id nick ] [ getItemValue $w $id time ] [ getItemValue $w $id parentNick ] [ getItemValue $w $id parent ] [ getItemValue $w $id unread ]
        saveTopicRecursive $topic $id
    }
}

proc saveTopicToCache {topic} {
    global messageTree

    if { $topic != "" && [ $messageTree exists "topic" ] } {
        clearDiskCache $topic
        saveTopicRecursive $topic "topic"
    }
}

proc processArgv {} {
    global argv

    foreach arg $argv {
        if [ regexp -lineanchor -- {^-(.+)=(.*)$} $arg dummy param value ] {
            uplevel #0 "set {$param} {$value}"
        }
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
        errorProc [ mc "Error loading file %s\n%s" $fileName $err ] $::errorInfo
    }
}

proc loadConfig {} {
    global configDir
    global libDir
    global colorList
    global colorCount

    loadConfigFile [ file join $configDir "config" ]
    loadConfigFile [ file join $configDir "userConfig" ]

    set colorCount [ llength $colorList ]

    ::msgcat::mcload [ file join $libDir msgs ]
}

proc updateTopicList {{section ""}} {
    global autonomousMode
    global appName
    global topicTree
    global forumVisibleGroups
    global backendId

    if { $autonomousMode } {
        if { [ tk_messageBox -title $appName -message [ mc "Are you want to go to online mode?" ] -type yesno -icon question -default yes ] == yes } {
            set autonomousMode 0
            login
        } else {
            return
        }
    }

    if [ regexp -lineanchor -- {^\d+$} $section ] {
        return
    }

    if { $section == "favorites" } {
        return
    }

    if { $section == "" } {
        updateTopicList news
        updateTopicList gallery
        updateTopicList votes
        updateTopicList forum

        return
    }
    if { $section == "forum" } {
        foreach id $forumVisibleGroups {
            updateTopicList "forum$id"
        }
        return
    }

    defCallbackLambda processTopic {parent id nick header} {
        global cacheDir

        set header [ htmlToText $header ]
        update
        if [ tkLor::taskManager::isTaskStopped getTopicList ] {
            return
        }
        addTopicFromCache $parent $id $nick $header [ expr ! [ file exists [ file join $cacheDir "$id.topic" ] ] ]
    } $section

    defCallbackLambda onComplete {section} {
        upvar #0 topicTree w
        global threadListSize

        foreach item [ lrange [ $w children $section ] $threadListSize end ] {
            set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
            if { $count != "0" } {
                addUnreadChild $w $section "-$count"
            }
            $w delete $item
        }
        taskCompleted getTopicList
    } $section

    addTask getTopicList remoting::sendRemote -async $backendId [ list lor::getTopicList $section $processTopic errorProcCallback $onComplete ]
}

proc addTopicFromCache {parent id nick text unread} {
    upvar #0 topicTree w

    if { ! [ $w exists $id ] } {
        $w insert $parent end -id $id
        sortChildrens $w $parent

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
    global cacheDir

    loadConfigFile [ file join $cacheDir "topics" ]
}

proc saveTopicListToCache {} {
    upvar #0 topicTree w
    global cacheDir

    catch {
        set f [ open [ file join $cacheDir "topics" ] "w+" ]
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
    global cacheDir

    set old [ getItemValue $w $item unread ]
    if {$unread != $old} {
        setItemValue $w $item unread $unread
        addUnreadChild $w [ getItemValue $w $item parent ] [ expr $unread - $old ]
        updateItemState $w $item
        if { $w == $::topicTree } {
            if { [ regexp -lineanchor {^\d+$} $item ] } {
                if { $unread == "0" } {
                    set f [ open [ file join $cacheDir "$item.topic" ] "w" ]
                    close $f
                } else {
                    file delete [ file join $cacheDir "$item.topic" ]
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

proc refreshTopicSubList {w item} {
    global topicTree

    if { $w == $topicTree && $item != "" } {
        updateTopicList $item
    }
}

proc markAllMessages {w unread} {
    foreach item [ $w children "" ] {
        mark $w $item thread $unread
    }
    updateWindowTitle
}

proc reply {w item} {
    global topicTree
    global currentTopic

    if { $w == $topicTree } {
        openUrl [ ::lor::topicReply $item ]
    } else {
        if { $item == "topic" } {
             openUrl [ ::lor::topicReply $currentTopic ]
        } else {
            openUrl [ ::lor::messageReply $item $currentTopic ]
        }
    }
}

proc userInfo {w item} {
    openUrl [ ::lor::userInfo [ getItemValue $w $item nick ] ]
}

proc openMessage {w item} {
    global topicTree
    global currentTopic

    if { $w == $topicTree } {
        openUrl [ ::lor::getTopicUrl $item ]
    } else {
        if { $item == "topic" } {
            openUrl [ ::lor::getTopicUrl $currentTopic ]
        } else {
            openUrl [ ::lor::getMessageUrl $item $currentTopic ]
        }
    }
}

proc openUrl {url} {
    global tcl_platform browser

    update

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
    return [ ::htmlparse::mapEscapes $text ]
}

proc addTopicToFavorites {w item category caption} {
    if { $category == "" } {
        set category "favorites"
    }
    if { $item != $category } {
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
        set s [ expr [ getItemValue $w $item unreadChild ]+[ getItemValue $w $item unread ] ]
        if {$s > 0} {
            addUnreadChild $w [ getItemValue $w $item parent ] -$s
        }
        $w delete $item
        $w focus [ lindex [ $w children {} ] 0 ]
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
    global cacheDir

    if [ regexp -lineanchor {^\d+$} $item ] {
        mark $w $item item 1
        catch {
            file delete [ file join $cacheDir $item ]
        }
        catch {
            file delete [ file join $cacheDir "$item.topic" ]
        }
    }
}

proc showOptionsDialog {} {
    global appName
    global options

    set opts ""
    foreach {category optList} $options {
        set sub ""
        foreach {item type var opt} $optList {
            if {$type != "hidden"} {
                lappend sub [ mc $item ] $type $var [ set ::$var ] $opt
            }
        }
        lappend opts [ mc $category ]
        lappend opts $sub
    }

    tabbedOptionsDialog \
        -title [ mc "%s options" $appName ] \
        -options $opts \
        -pageScript [ lambda {opts} {
            foreach {var val} $opts {
                set ::$var $val
            }
        } ] \
        -script {applyOptions;saveOptions} \
        -parent .
}

proc applyOptions {} {
    global topicTree messageTree
    global tileTheme
    global messageTextWidget
    global messageTextFont
    global color
    global colorList
    global colorCount

    configureTags $topicTree
    configureTags $messageTree

    ttk::style theme use $tileTheme

    catch {$messageTextWidget configure -font $messageTextFont}
    catch {$messageTextWidget configure -foreground $color(htmlFg) -background $color(htmlBg)}

    initBindings

    set colorCount [ llength $colorList ]

    updateForumGroups
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
            puts $f [ list "set" $var [ set ::$var ] ]
            puts $f ""
        }
    }
    close $f
}

proc addIgnoreListItem {w parent} {
    inputStringDialog \
        -title [ mc "Ignore list" ] \
        -label [ mc "Enter nick" ] \
        -script [ list $w "insert" "" "end" "-text" ] \
        -parent $parent
}

proc modifyIgnoreListItem {w parent} {
    if { [ $w focus ] == "" } {
        addIgnoreListItem $w $parent
    } else {
        inputStringDialog \
            -title [ mc "Ignore list" ] \
            -label [ mc "Enter nick" ] \
            -script [ lambda {w text} {
                $w item [ $w focus ] -text $text
            } $w ] \
            -default [ $w item [ $w focus ] -text ] \
            -parent $parent
    }
}

proc nextUnread {w item} {
    set cur [ processItems $w $item [ lambda {w item} {
        return [ expr [ getItemValue $w $item unread ] != "1" ]
    } $w ] ]
    if { $cur != "" } {
        setFocusedItem $w $cur
        click $w $cur
    }
}

proc openContextMenu {w menu} {
    set item [ $w focus ]
    if { $item != "" } {
        set bbox [ $w bbox $item ]
        set x [ lindex $bbox 0 ]
        set y [ lindex $bbox 1 ]
        set xx 0
        set yy 0
        catch {
            set xx [ expr [ winfo rootx $w ] + $x ]
            set yy [ expr [ winfo rooty $w ] + $y ]
            incr x [ expr [ lindex $bbox 2 ] / 2 ]
            incr y [ expr [ lindex $bbox 3 ] / 2 ]
        }
        popupMenu $menu $xx $yy $x $y
    }
}

proc find {} {
    global findPos findString
    global messageTree

    set findPos [ $messageTree focus ]

    inputStringDialog \
        -title [ mc "Search" ] \
        -label [ mc "Search regexp" ] \
        -script [ lambda {str} {
                global findString
                set findString $str
                findNext
            } ] \
        -default $findString \
        -parent .
}

proc findNext {} {
    upvar #0 messageTree w
    global appName
    global findString findPos

    if { ![$w exists $findPos] } {
        set findPos ""
    }
    set cur [ processItems $w $findPos [ lambda {w findString item} {
        return [ expr [ regexp -nocase -- $findString [ getItemValue $w $item msg ] ] == "0" ]
    } $w $findString ] ]
    set findPos $cur

    if { $cur != "" } {
        setFocusedItem $w $cur
        click $w $cur
    }
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
            if { ![ eval [ concat $script [ list $next ] ] ] } {
                return $next
            }
        }
        if { $next == "" } {
            return ""
        }
    }
}

proc setFocusedItem {w item} {
    if [ $w exists $item ] {
        $w see $item
        $w focus $item
        $w selection set $item
    }
}

proc updateWindowTitle {} {
    global appName
    global messageTree
    global topicHeader
    global currentTopic

    set s $appName
    if { $currentTopic != "" } {
        append s ": $topicHeader"
        set k [ getItemValue $messageTree {} unreadChild ]
        if { $k != "0" } {
            append s [ mc " \[ %s new \]" $k ]
        }
    }
    wm title . $s
}

proc clearOldTopics {} {
    global cacheDir appName
    upvar #0 topicTree w

    set topics ""

    if [ catch {
        foreach fname [ glob -directory $cacheDir -types f {[0-9]*} {[0-9]*.topic} ] {
            regsub -lineanchor -nocase {^.*?(\d+)(?:\.topic){0,1}$} $fname {\1} fname
            if { [ lsearch -exact $topics $fname ] == -1 && ! [ $w exists $fname ] } {
                lappend topics $fname
            }
        }
    } ] {
        set topics ""
    }

    set count [ llength $topics ]

    if { $count == "0" } {
        tk_messageBox -type ok -icon info -message [ mc "There are no obsolete topics." ] -title $appName
        return
    } elseif { [ tk_messageBox -type yesno -default no -icon question -message [ mc "%s obsolete topic(s) will be deleted.\nDo you want to continue?" $count ] -title $appName ] != yes } {
        return
    }

    set f [ toplevel .obsoleteTopicsRemovingWindow -class Dialog ]
    update
    wm title $f $appName
    wm withdraw $f
    wm resizable $f 1 0
    wm protocol $f WM_DELETE_WINDOW { }
    wm transient $f .
    pack [ ttk::label $f.label -text [ mc "Deleting obsolete topics. Please wait..." ] ] -fill x -expand yes
    pack [ ttk::progressbar $f.p -maximum [ llength $topics ] -value 0 -orient horizontal -mode determinate -length 400 ] -fill x -expand yes
    wm deiconify $f
    grab $f

    set count 0
    set dir $cacheDir
    foreach id $topics {
        catch {
            file delete [ file join $dir $id ]
        }
        catch {
            file delete [ file join $dir "$id.topic" ]
        }
        incr count
        $f.p step
        update
    }
    grab release $f
    wm withdraw $f
    destroy $f
}

proc ignoreUser {w item} {
    global ignoreList

    set nick [ getItemValue $w $item nick ]
    if { ![ isUserIgnored [ getItemValue $w $item nick ] ] } {
        lappend ignoreList $nick
    }
}

proc showFavoritesTree {title name script parent parentWindow} {
    set f [ join [ list ".favoritesTreeDialog" [ generateId ] ] "" ]
    toplevel $f -class Dialog
    wm withdraw $f
    wm title $f $title

    pack [ ttk::label $f.label -text [ mc "Item name: " ] ] -fill x
    set nameWidget [ ttk::entry $f.itemName ]
    pack $nameWidget -fill x
    $nameWidget insert end $name

    pack [ ttk::label $f.categoryLabel -text [ mc "Category: " ] ] -fill x
    set categoryWidget [ ttk::treeview $f.category ]
    $categoryWidget heading #0 -text [ mc "Title" ] -anchor w
    pack $categoryWidget -fill both -expand yes

    fillCategoryWidget $categoryWidget $parent

    set okScript [ join \
        [ list \
            [ lambda {script categoryWidget nameWidget} {
                eval [ concat \
                    $script \
                    [ list \
                        [ $categoryWidget focus ] \
                        [ $nameWidget get ]
                    ] \
                ]
            } $script $categoryWidget $nameWidget ] \
            [ list "destroy" "$f" ] \
        ] ";" \
    ]
    set cancelScript "destroy $f"
    set newCategoryScript [ lambda {f categoryWidget parent} {
            showFavoritesTree [ mc "Select new category name and location" ] [ mc "New category" ] [ list "createCategory" $categoryWidget $f ] [ $categoryWidget focus ] $parent
        } $f $categoryWidget $parentWindow \
    ]

    pack [ buttonBox $f \
        [ list -text [ mc "New category..." ] -command $newCategoryScript ] \
        [ list -text [ mc "OK" ] -command $okScript ] \
        [ list -text [ mc "Cancel" ] -command $cancelScript ] \
    ] -side bottom -fill x

    wm deiconify $f
    wm transient $f $parentWindow
    update
    focus $nameWidget
    wm protocol $f WM_DELETE_WINDOW $cancelScript
    wm transient $f $parentWindow
    bind $f.itemName <Return> $okScript
    bind $f.category <Return> $okScript
    bind $f <Escape> $cancelScript
}

proc addToFavorites {w id} {
    global topicTree

    if { ![ isCategoryFixed $id ] } {
        showFavoritesTree [ mc "Select category and topic text" ] [ getItemValue $w $id text ] [ list addTopicToFavorites $topicTree $id ] [ getItemValue $topicTree $id parent ] .
    }
}

proc createCategory {categoryWidget parentWidget parent name} {
    upvar #0 topicTree w

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
    global topicTree

    $categoryWidget insert {} end -id favorites -text [ mc "Favorites" ]
    processItems $topicTree "favorites" [ lambda {from to item} {
        if { ![ regexp -lineanchor {^\d+$} $item ] } {
            $to insert [ getItemValue $from $item parent ] end -id $item -text [ getItemValue $from $item text ]
        }
        return 1
    } $topicTree $categoryWidget ]
    if [ catch {setFocusedItem $categoryWidget $parent} ] {
        setFocusedItem $categoryWidget "favorites"
    }
}

proc clearTreeItemChildrens {w parent} {
    foreach item [ $w children $parent ] {
        $w delete $item
    }
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

proc initBindings {} {
    global topicTree messageTree
    global messageTextWidget
    global doubleClickAllTopics

    foreach i {<<TreeviewSelect>> <Double-Button-1> <Return>} {
        bind $topicTree $i ""
    }

    if { $doubleClickAllTopics == "0" } {
        bind $topicTree <<TreeviewSelect>> {
            invokeMenuCommand $topicTree click
            setPerspective reading
        }
    } else {
        bind $topicTree <Double-Button-1> {invokeMenuCommand $topicTree click}
        bind $topicTree <Return> {invokeMenuCommand $topicTree click}
        bind $topicTree <Button-1> {setPerspective navigation}
    }
    bind $topicTree <ButtonPress-3> {popupMenu $topicMenu %X %Y %x %y}
    bind $topicTree <Menu> {openContextMenu $topicTree $topicMenu}

    bind $messageTree <<TreeviewSelect>> {
        invokeMenuCommand $messageTree click
        setPerspective reading
    }
    bind $messageTree <ButtonPress-3> {popupMenu $messageMenu %X %Y %x %y}
    bind $messageTree <Menu> {openContextMenu $messageTree $messageMenu}

    bind $messageTextWidget <ButtonPress-3> {popupMenu $messageTextMenu %X %Y %x %y}

    foreach w [ list $topicTree $messageTree ] {
        bind $w <Home> [ list $w yview moveto 0 ]
        bind $w <End> [ list $w yview moveto 1 ]

        bind $w n [ list invokeMenuCommand $w nextUnread ]
        bind $w N [ list invokeMenuCommand $w nextUnread ]

        bind $w <Control-r> [ list invokeMenuCommand $w reply ]
        bind $w <Control-R> [ list invokeMenuCommand $w reply ]
        bind $w <Control-i> [ list invokeMenuCommand $w userInfo ]
        bind $w <Control-I> [ list invokeMenuCommand $w userInfo ]
        bind $w <Control-o> [ list invokeMenuCommand $w openMessage ]
        bind $w <Control-O> [ list invokeMenuCommand $w openMessage ]

        bind $w <m> [ list invokeMenuCommand $w mark message 0 ]
        bind $w <u> [ list invokeMenuCommand $w mark message 1 ]

        bind $w <Control-m> [ list invokeMenuCommand $w mark thread 0 ]
        bind $w <Control-u> [ list invokeMenuCommand $w mark thread 1 ]

        bind $w <Control-Alt-m> [ list markAllMessages $w 0 ]
        bind $w <Control-Alt-u> [ list markAllMessages $w 1 ]
    }

    bind . <F1> helpAbout
    bind . <F2> updateTopicList
    bind . <F3> findNext
    bind . <F5> refreshTopic

    bind $topicTree <F4> [ list invokeMenuCommand $topicTree refreshTopicSubList ]

    bind . <Control-f> find
    bind . <Control-F> find

    bind . <Control-z> {setPerspective navigation -force}
    bind . <Control-Z> {setPerspective navigation -force}
    bind . <Control-x> {setPerspective reading -force}
    bind . <Control-X> {setPerspective reading -force}
}

proc tagUser {w item parent} {
    global userTagList

    set nick [ getItemValue $w $item nick ]
    for {set i 0} {$i < [ llength $userTagList ]} {incr i} {
        set item [ lindex $userTagList $i ]
        if { [ lindex $item 0 ] == $nick } {
            onePageOptionsDialog \
                -title [ mc "Modify user tag" ] \
                -options [ list \
                    [ mc "Nick" ] string nick $nick "" \
                    [ mc "Tag"  ] string tag  [ lindex $item 1 ] "" \
                ] \
                -script [ lambda {w pos vals} {
                    global userTagList
                    array set arr $vals
                    lset userTagList $pos [ list $arr(nick) $arr(tag) ]
                    array unset arr
                } $w $i ] \
                -parent $parent
            return
        }
    }
    onePageOptionsDialog \
        -title [ mc "Add user tag" ] \
        -options [ list \
            [ mc "Nick" ] string nick $nick "" \
            [ mc "Tag"  ] string tag  "" "" \
        ] \
        -script [ lambda {w vals} {
            global userTagList
            array set arr $vals
            lappend userTagList [ list $arr(nick) $arr(tag) ]
            array unset arr
        } $w ] \
        -parent $parent
}

proc addUserTagListItem {w parent} {
    onePageOptionsDialog \
        -title [ mc "Add user tag" ] \
        -options [ list \
            [ mc "Nick" ] string nick "" "" \
            [ mc "Tag"  ] string tag  "" "" \
        ] \
        -script [ lambda {w vals} {
            array set arr $vals
            $w insert {} end -text $arr(nick) -values [ list $arr(tag) ]
            array unset arr
        } $w ] \
        -parent $parent
}

proc modifyUserTagListItem {w parent} {
    set id [ $w focus ]
    if { $id == "" } {
        addUserTagListItem $w $parent
    } else {
        onePageOptionsDialog \
            -title [ mc "Modify user tag" ] \
            -options [ list \
                [ mc "Nick" ] string nick [ $w item $id -text ] "" \
                [ mc "Tag"  ] string tag  [ lindex [ $w item $id -values ] 0 ] "" \
            ] \
            -script [ lambda {w id vals} {
                array set arr $vals
                $w item $id -text $arr(nick) -values [ list $arr(tag) ]
                array unset arr
            } $w $id ] \
            -parent $parent
    }
}

proc isUserIgnored {nick} {
    global ignoreList

    return [ expr { [ lsearch -exact $ignoreList $nick ] != -1 } ]
}

proc addColorListItem {w parent} {
    onePageOptionsDialog \
        -title [ mc "Add color regexp" ] \
        -options [ list \
            [ mc "Regexp" ] string regexp  "" "" \
            [ mc "Color" ] color color    "red" "" \
            [ mc "Element" ] readOnlyCombo element "foreground" { list foreground background } \
        ] \
        -script [ lambda {w vals} {
            array set arr $vals
            $w insert {} end -text $arr(regexp) -values [ list $arr(color) $arr(element) ]
            array unset arr
        } $w ] \
        -parent $parent
}

proc modifyColorListItem {w parent} {
    set id [ $w focus ]
    if { $id == "" } {
        addColorListItem $w $parent
    } else {
        onePageOptionsDialog \
            -title [ mc "Modify color regexp" ] \
            -options [ list \
                [ mc "Regexp" ] string regexp  [ $w item $id -text ] "" \
                [ mc "Color" ] color color    [ lindex [ $w item $id -values ] 0 ] "" \
                [ mc "Element" ] readOnlyCombo element [ lindex [ $w item $id -values ] 1 ] { list foreground background } \
            ] \
            -script [ lambda {w id vals} {
                array set arr $vals
                $w item $id -text $arr(regexp) -values [ list $arr(color) $arr(element) ]
                array unset arr
            } $w $id ] \
            -parent $parent
    }
}

proc loadAppLibs {} {
    global libDir
    global auto_path

    lappend auto_path $libDir

    package require gaa_lambda 1.1
    package require gaa_tileDialogs 1.2
    package require gaa_tools 1.0
    package require gaa_mbox 1.0
    package require gaa_remoting 2.0
    package require lorParser 1.1
    package require tkLor_taskManager 1.0
    package require gaa_logger 1.0

    namespace import ::gaa::lambda::*
    namespace import ::gaa::tileDialogs::*
    namespace import ::gaa::tools::*
    namespace import tkLor::taskManager::*
}

proc setPerspective {mode {force ""}} {
    global horPane
    global perspectiveAutoSwitch
    global currentPerspective
    global topicTree messageTree

    if { $force == "" && $perspectiveAutoSwitch == "0" } {
        return
    }
    set currentPerspective $mode
    upvar #0 [ join [ list $mode "SashPos" ] "" ] pos
    set w ''
    switch -exact -- $mode {
        navigation {
            set w $topicTree
        }
        reading {
            set w $messageTree
        }
    }
    focus $w
    if { [ $w focus ] == "" } {
        $w focus [ lindex [ $w children {} ] 0 ]
    }
    $horPane sashpos 0 [ expr [ winfo width . ] * $pos / 100 ]
}

proc showWindow {} {
    wm withdraw .
    wm deiconify .
}

proc errorProc {err {extInfo ""}} {
    global appName

    logger::log $err
    if {$extInfo != ""} {
        logger::log "Extended info: $extInfo"
    }
    tk_messageBox -title [ mc "%s error" $appName ] -message $err -parent . -type ok -icon error
}

proc sortChildrens {w parent} {
    $w children $parent [ lsort -decreasing [ $w children $parent ] ]
}

proc updateForumGroups {} {
    upvar #0 topicTree w
    global forumVisibleGroups

    foreach {id title} $::lor::forumGroups {
        if { [ lsearch $forumVisibleGroups $id ] != -1 } {
            # if forum group must be visible ...
            if { ! [ $w exists "forum$id" ] } {
                $w insert forum end \
                    -id "forum$id" \
                    -text $title \
                    -values [ list "" 0 0 "forum" $title ]
                updateItemState $w "forum$id"
            }
        } else {
            # if forum group must be hidden ...
            if { [ $w exists "forum$id" ] } {
                clearTreeItemChildrens $w "forum$id"
                $w delete "forum$id"
            }
        }
    }
    sortChildrens $w "forum"
    updateItemState $w "forum"
}

proc runBackend {} {
    global backend configDir libDir appId wishPath debug
    global backendId

    exec $wishPath [ file join $libDir lorBackend.tcl ] -configDir $configDir -libDir $libDir -appId $appId -debug $debug &

    tkwait variable backendId
    logger::log "backend id: $::backendId"
}

proc defCallbackLambda {name params script args} {
    global appName

    uplevel [ list set $name \
        [ concat \
            [ list ::gaa::lambda::lambdaProc {params script args} {
                remoting::sendRemote tkLOR [ concat [ list lambdaProc $params $script ] $args ]
            } $params $script ] \
            $args \
        ] \
    ]
}

proc initTasksWindow {} {
    global tasksWidget
    global appName

    set tasksWidget [ toplevel .tasksWidget -class Dialog ]
    wm withdraw $tasksWidget
    wm title $tasksWidget [ mc "%s: running tasks" $appName ]
    wm protocol $tasksWidget WM_DELETE_WINDOW toggleTaskList

    bind $tasksWidget <Escape> toggleTaskList

    set w [ ttk::treeview $tasksWidget.list -columns {count} ]
    $w heading #0 -text [ mc "Category" ] -anchor w
    $w heading count -text [ mc "Count" ] -anchor w
    $w column count -width 30
    pack $w -fill both -expand 1

    deflambda stopScript {w} {
        foreach item [ $w selection ] {
            stopTask $item
        }
    } $w
    deflambda stopAllScript {w} {
        foreach item [ $w selection ] {
            stopAllTasks $item
        }
    } $w
    pack [ buttonBox $tasksWidget \
        [ list -text [ mc "Stop" ] -command $stopScript ] \
        [ list -text [ mc "Stop all" ] -command $stopAllScript ] \
    ] -fill x -side bottom -expand 1
}

proc toggleTaskList {} {
    global tasksWidget
    global tasksWidgetVisible

    if { $tasksWidgetVisible == 1 } {
        wm withdraw $tasksWidget
    } else {
        wm transient $tasksWidget .
        wm deiconify $tasksWidget
    }
    set tasksWidgetVisible [ expr 1 - $tasksWidgetVisible ]
}

proc updateTaskList {} {
    global tasksWidget
    global statusBarWidget
    set w $tasksWidget.list

    array set categoriesMap [ list \
        getMessageList [ mc "Getting messages" ] \
        getTopicList   [ mc "Getting topics list" ] \
        postMessage    [ mc "Message posting" ] \
    ]
    set total 0
    set nonEmptyCategory ""
    foreach category {getMessageList getTopicList postMessage} {
        set count [ getTasksCount $category ]
        incr total $count

        if { $count == 0 } {
            if [ $w exists $category ] {
                $w delete $category
            }
        } else {
            set nonEmptyCategory $category
            if [ $w exists $category ] {
                $w delete $category
            }
            $w insert {} end -id $category -text $categoriesMap($category) -values [ list $count ]
        }
    }
    if { $total != 0 } {
        if { $total == 1 } {
            $statusBarWidget.text configure -text $categoriesMap($nonEmptyCategory)
        } else {
            $statusBarWidget.text configure -text [ mc "%s operations running" $total ]
        }
        $statusBarWidget.progress state !disabled
        $statusBarWidget.progress start
    } else {
        $statusBarWidget.text configure -text ""
        $statusBarWidget.progress stop
        $statusBarWidget.progress state disabled
    }
    array unset categoriesMap
}

proc bgerror {msg} {
    logger::log "bgerror: $msg"
    logger::log "bgerror extended info: $::errorInfo"
}

proc openLoginWindow {} {
    global backendId
    global autonomousMode
    global appName

    set f [ toplevel .loginWindow -class Dialog ]
    update
    wm title $f $appName
    wm withdraw $f
    wm resizable $f 1 0
    wm protocol $f WM_DELETE_WINDOW { }
    pack [ ttk::label $f.label -text [ mc "Logging in. Please wait..." ] ] -fill x -expand yes
    pack [ ttk::progressbar $f.p -value 0 -orient horizontal -mode indeterminate -length 400 ] -fill x -expand yes
    wm transient $f .
    wm deiconify $f
    update
    grab $f
    $f.p start
}

proc closeLoginWindow {} {
    set f .loginWindow

    grab release $f
    wm withdraw $f
    destroy $f
}

proc loginCallback {loggedIn} {
    global autonomousMode appName

    closeLoginWindow
    if { ! $loggedIn } {
        if { [ tk_messageBox -title $appName -message [ mc "Login failed" ] -icon warning -parent . -type retrycancel ] == "cancel" } {
            set autonomousMode 1
        } else {
            login
        }
    }
}

proc login {} {
    global lorLogin lorPassword
    global backendId

    if { ![ remoting::sendRemote $backendId lor::isLoggedIn ] } {
        openLoginWindow
        remoting::sendRemote -async $backendId login $lorLogin $lorPassword
    }
}

proc logout {} {
    global backendId

    remoting::sendRemote -async $backendId lor::logout
}

############################################################################
#                                   MAIN                                   #
############################################################################

processArgv

initDirs
loadAppLibs
loadConfig

if {$debug != "0"} {
    logger::configure $appName
}

if { [ remoting::startServer $appName ] != $appName } {
    remoting::sendRemote -async $appName {showWindow}
    exit
}

initMainWindow
initTasksWindow
initMenu

update

runBackend

applyOptions
setUpdateHandler updateTaskList

update

loadTopicListFromCache

if {! [ file exists [ file join $configDir "config" ] ] } {
    showOptionsDialog
}

if { ! $autonomousMode } {
    login
}

if { $updateOnStart == "1" } {
    updateTopicList
}

setPerspective $currentPerspective
