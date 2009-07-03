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

set tclshPath [ auto_execok "tclsh" ]

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

set currentSubject ""
set currentNick ""
set currentTopic ""
set currentMessage ""
set lastId 0

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

# Mail queues
set draft ""
set sent ""
set outcoming ""

# dirty hack: at current moment tile does not provide interface to get current theme
if [ catch {set tileTheme $::ttk::currentTheme} ] {
    set tileTheme "default"
}

set findString ""
set findPos ""

set messageTextFont [ font actual system ]
set messageTextMonospaceFont "-family Courier"
set messageTextQuoteFont "-slant italic"

set forumVisibleGroups {126 1339 1340 1342 4066 4068 7300 8403 8404 9326 10161 19109 19390}

set tasksWidgetVisible 0

set loadTaskId ""
set deliverTaskId ""

set loggedIn 0

set rightViewState "UNKNOWN"

set debug 0

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
    .menu add cascade \
        -label [ mc "LOR" ] \
        -menu .menu.lor \
        -underline 0
    .menu add cascade \
        -label [ mc "View" ] \
        -menu .menu.view \
        -underline 0
    .menu add cascade \
        -label [ mc "Topic" ] \
        -menu .menu.topic \
        -underline 0 \
        -state disabled
    .menu add cascade \
        -label [ mc "Message" ] \
        -menu .menu.message \
        -underline 0 \
        -state disabled
    .menu add cascade \
        -label [ mc "Search" ] \
        -menu .menu.search \
        -underline 0 \
        -state disabled
    .menu add cascade \
        -label [ mc "Help" ] \
        -menu .menu.help \
        -underline 0

    set m [ menu .menu.lor -tearoff 0 ]
    $m add command \
        -label [ mc "Add topic..." ] \
        -command addTopic
    $m add command \
        -label [ mc "Search new topics" ] \
        -accelerator "F2" \
        -command updateTopicList
    $m add command \
        -label [ mc "Clear old topics..." ] \
        -command clearOldTopics
    $m add separator
    $m add checkbutton \
        -label [ mc "Autonomous mode" ] \
        -variable autonomousMode
    $m add command \
        -label [ mc "Send queued messages" ] \
        -command startDelivery
    $m add separator
    $m add command \
        -label [ mc "Options..." ] \
        -command showOptionsDialog
    $m add separator
    $m add command \
        -label [ mc "Exit" ] \
        -accelerator "Alt-F4" \
        -command exitProc

    set m [ menu .menu.view -tearoff 0 ]
    $m add radiobutton \
        -label [ mc "Navigation perspective" ] \
        -accelerator "Ctrl-Z" \
        -command {setPerspective navigation -force} \
        -value navigation \
        -variable currentPerspective
    $m add radiobutton \
        -label [ mc "Reading perspective" ] \
        -accelerator "Ctrl-X" \
        -command {setPerspective reading -force} \
        -value reading \
        -variable currentPerspective
    $m add separator
    $m add checkbutton \
        -label [ mc "Auto switch" ] \
        -variable perspectiveAutoSwitch

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

    foreach {m invoke} [ list \
        $menuMessage invokeMenuCommand \
        $messageMenu invokeItemCommand ] {
        
        $m add separator
        $m add command \
            -label [ mc "Edit" ] \
            -accelerator "Ctrl-E" \
            -command [ list $invoke $messageTree edit ]
        $m add command \
            -label [ mc "Delete" ] \
            -command [ list $invoke $messageTree deleteMessage ]
    }
}

proc initTopicTree {} {
    upvar #0 topicTree w
    global forumVisibleGroups

    set f [ ttk::frame .topicTreeFrame -width 250 -relief sunken ]
    set w [ ttk::treeview $f.w -columns {nick unread unreadChild text msg} -displaycolumns {nick unreadChild} -yscrollcommand "$f.scroll set" ]

    configureTags $w
    $w heading #0 -text [ mc "Title" ] -anchor w
    $w heading nick -text [ mc "Nick" ] -anchor w
    $w heading unreadChild -text [ mc "Threads" ] -anchor w
    $w column #0 -width 220
    $w column nick -width 60
    $w column unreadChild -width 30 -stretch 0

    $w insert {} end -id messages -text [ mc "Local folders" ] -values [ list "" 0 0 [ mc "Local folders" ] ]
    $w insert messages end -id draft -text [ mc "Draft" ] -values [ list "" 0 0 [ mc "Draft" ] ]
    updateItemState $w draft
    $w insert messages end -id outcoming -text [ mc "Outcoming" ] -values [ list "" 0 0 [ mc "Outcoming" ] ]
    updateItemState $w outcoming
    $w insert messages end -id sent -text [ mc "Sent" ] -values [ list "" 0 0 [ mc "Sent" ] ]
    updateItemState $w sent

    $w insert "" end -id news -text [ mc "News" ] -values [ list "" 0 0 [ mc "News" ] ]
    $w insert "" end -id gallery -text [ mc "Gallery" ] -values [ list "" 0 0 [ mc "Gallery" ] ]
    $w insert "" end -id votes -text [ mc "Votes" ] -values [ list "" 0 0 [ mc "Votes" ] ]

    $w insert "" end -id forum -text [ mc "Forum" ] -values [ list "" 0 0 [ mc "Forum" ] ]
    foreach {id title} $::lor::forumGroups {
        if { [ lsearch $forumVisibleGroups $id ] != -1 } {
            $w insert forum end -id "forum$id" -text $title -values [ list "" 0 0  $title ]
            updateItemState $w "forum$id"
        }
    }
    sortChildrens $w "forum"

    $w insert "" end -id favorites -text [ mc "Favorites" ] -values [ list "" 0 0 [ mc "Favorites" ] ]

    foreach item [ $w children "" ] {
        updateItemState $w $item
    }

    ttk::scrollbar $f.scroll -command "$w yview"
    pack $f.scroll -side right -fill y
    pack $w -expand yes -fill both
    return $f
}

proc initMessageTree {} {
    upvar #0 messageTree w

    set f [ ttk::frame .messageTreeFrame -relief sunken ]
    set w [ ttk::treeview $f.w -columns {nick header time msg unread unreadChild text} -displaycolumns {header time} -xscrollcommand "$f.scrollx set" -yscrollcommand "$f.scrolly set" ]
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
    global currentSubject currentNick currentPrevNick currentTime
    global messageTextFont

    set mf [ ttk::frame .msgFrame -relief sunken ]
    set f [ ttk::frame $mf.labels ]

    foreach {var label} [ list \
        currentSubject   [ mc "Subject: " ] \
        currentNick     [ mc "From: " ] \
        currentPrevNick [ mc "To: " ] \
        currentTime     [ mc "Time: " ] \
    ] {
        grid \
            [ ttk::label $f.${var}Label -text $label -anchor w ] \
            [ ttk::label $f.${var}Text -textvariable $var ] \
            -sticky nswe
    }
    grid columnconfigure $f 1 -weight 1
    grid $f -sticky nswe

    set f [ ttk::frame $mf.text ]
    set messageTextWidget [ text $f.msg -state disabled -yscrollcommand "$f.scroll set" -setgrid true -wrap word -height 10 ]
    ttk::scrollbar $f.scroll -command "$messageTextWidget yview"

    grid $messageTextWidget $f.scroll -sticky nswe
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1
    grid $f -sticky nswe

    grid columnconfigure $mf 0 -weight 1
    grid rowconfigure $mf 1 -weight 1

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

    messageBox \
        -title [ mc "About %s" $appName ] \
        -message [ mc "%s %s" $appName $appVersion ] \
        -detail [ mc "Client for reading linux.org.ru written on Tcl/Tk/Tile.\nCopyright (c) 2008 Alexander Galanin (gaa at linux.org.ru)\nLicense: GPLv3" ] \
        -parent . \
        -type ok
}

proc exitProc {} {
    global appName
    global currentTopic

    set total [ expr [ llength [ ::taskManager::getTasks ] ] / 2 ]
    if { $total != 0 } {
        if { [ messageBox \
            -message [ mc "There are %s running tasks" $total ] \
            -detail  [ mc "Are you want to exit and stop it?" ] \
            -type yesno \
            -icon question \
        ] == "yes" } {
            stopAllTasks
        } else {
            return
        }
    }

    saveTopicToCache $currentTopic
    saveTopicListToCache
    saveMessageQueuesToCache
    saveOptions

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

    set stackId [ ::struct::stack ]

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

#TODO: move htmlToText for Subject into lorBackend (v1.2)
proc showMessageInMainWindow {msg} {
    global messageTextWidget
    global currentSubject currentNick currentPrevNick currentTime

    array set letter $msg
    set currentSubject [ ::htmlparse::mapEscapes $letter(Subject) ]
    set currentNick $letter(From)
    if [ info exists letter(To) ] {
    	set currentPrevNick $letter(To)
    } else {
	set currentPrevNick ""
    }
    set currentTime $letter(X-LOR-Time)

    renderHtml $messageTextWidget $letter(body)
    array unset letter
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
    global appName
    global messageTree messageTextWidget
    global currentTopic currentSubject currentNick currentPrevNick currentTime
    global expandNewMessages
    global loadTaskId
    global lastId

    if { $loadTaskId != "" } {
        catch {
            ::taskManager::stopTask $loadTaskId
        }
        set loadTaskId ""
    }
    update

    setPerspective reading
    focus $messageTree
    if { $currentTopic != "" } {
        saveTopicToCache $currentTopic
    }

    if { $topic == "sent" || $topic == "draft" || $topic == "outcoming" } {
        set currentTopic $topic
        renderHtml $messageTextWidget ""
        clearTreeItemChildrens $messageTree ""
        showMessageQueue $topic
        return
    }
    if { $topic != $currentTopic } {
        setItemValue $messageTree "" unreadChild 0

        clearTreeItemChildrens $messageTree ""
        foreach item {currentSubject currentNick currentPrevNick currentTime} {
            set $item ""
        }
        set lastId 0
        set currentTopic $topic

        set loadTaskId [ loadTopicFromCache $topic [ closure {topic} {} {
            global loadTaskId autonomousMode lastId
            upvar #0 messageTree w
            set loadTaskId ""
            if { $autonomousMode && ! [ $w exists "topic" ] } {
                goOnline
            }
            getNewMessages $topic
        } ] ]
    } else {
        getNewMessages $topic
    }
}

proc getNewMessages {topic} {
    global autonomousMode
    global lastId
    if { $autonomousMode } {
        return
    }

    set parser [ ::mbox::initParser [ list insertMessage 0 ] ]
    set onerror [ list errorProc [ mc "Error while getting messages" ] ]
    defclosure oncomplete {parser onerror} {} {
        global loadTaskId expandNewMessages messageTree

        if [ catch {
            ::mbox::closeParser $parser
        } err ] {
            lappend onerror $err $::errorInfo
            uplevel #0 $onerror
        }
        set loadTaskId ""
        focus $messageTree
        updateWindowTitle
        if { $expandNewMessages == "1" } {
            nextUnread $messageTree ""
            focus $messageTree
        }
    }

    set loadTaskId [ callPlugin get [ list $topic -last $lastId ] \
        -title [ mc "Getting new messages" ] \
        -onoutput [ list ::mbox::parseLine $parser ] \
        -oncomplete $oncomplete \
        -onerror $onerror \
    ]
}

proc insertMessage {replace letter} {
    upvar #0 messageTree w
    global markIgnoredMessagesAsRead
    global lastId

    array set res $letter
    set nick $res(From)
    set time $res(X-LOR-Time)
    set msg $letter
    set header [ ::htmlparse::mapEscapes $res(Subject) ]
    if [ info exists res(To) ]  {
        set id $res(X-LOR-Id)
        if [ info exists res(X-LOR-ReplyTo-Id) ] {
            set parent $res(X-LOR-ReplyTo-Id)
        } else {
            set parent "topic"
        }
        if { $res(To) == "" } {
            set parent "topic"
        }
    } else {
        set id "topic"
        set parent ""
    }
    if [ info exists res(X-LOR-Unread) ] {
        set unread $res(X-LOR-Unread)
    } else {
        set unread 1
    }
    array unset res
    if [ $w exists $id ] {
        if { !$replace && $id != "topic" } {
            return
        }
        set unread [ getItemValue $w $id unread ]
    } else {
        $w insert $parent end -id $id -text $nick
        setItemValue $w $id unreadChild 0
    }
    foreach i {nick time msg} {
        setItemValue $w $id $i [ set $i ]
    }
    setItemValue $w $id header $header
    setItemValue $w $id unread 0
    if { $unread && ( ![ isUserIgnored $nick ] || $markIgnoredMessagesAsRead != "1" ) } {
        mark $w $id item 1
    }
    updateItemState $w $id
    if { $id == "topic" } {
        $w item $id -open 1
        set ::topicHeader $header
#TODO: найти более удачное место
        saveTopicTextToCache $::currentTopic $letter
    }
    if { [ string is integer $id ] && $id > $lastId } {
        set lastId $id
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
    global messageMenu
    mark $w $item item 0
    if { [ getItemValue $w $item msg ] != "" } {
        showMessageInMainWindow [ getItemValue $w $item msg ]
    }
    if { $w == $topicTree } {
        if [ regexp -lineanchor -- {^\d} $item ] {
            set ::rightViewState MESSAGE
        } elseif {  $item == "sent" || 
                    $item == "draft" || 
                    $item == "outcoming" } {
            set ::rightViewState LOCAL
        } else {
            updateItemState $w $item
            return
        }
        setTopic $item
    } else {
        global currentMessage

        set currentMessage $item
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
        addUnreadChild $w [ $w parent $item ] $count
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
        return [ getItemValue $w $item text ]
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
        if { $w != $::topicTree } {
        foreach i $userTagList {
            if { [ lindex $i 0 ] == [ getItemValue $w $item nick ] } {
                append text [ join [ list " (" [ lindex $i 1 ] ")" ] "" ]
            }
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
    global autonomousMode

    if { $currentTopic != "" } {
        if $autonomousMode {
            goOnline
        }
        setTopic $currentTopic
    }
}

proc initDirs {} {
    global configDir cacheDir

    file mkdir $configDir
    file mkdir $cacheDir
}

proc saveTopicTextToCache {topic letter} {
    global cacheDir

    set fname [ file join $cacheDir "$topic.topic" ]
    ::mbox::writeToFile $fname [ list $letter ] -encoding utf-8
}

proc loadTopicFromCache {topic oncomplete} {
    global cacheDir
    global messageTree
    global topicHeader

    set topicHeader ""
    set fname [ file join $cacheDir "$topic.topic" ]
    defclosure script {topic} {letter} {
        global topicHeader

        array set res $letter
        set topicHeader \
            "[ ::htmlparse::mapEscapes $res(Subject) ]\($res(From)\)"
        array unset res
        insertMessage 1 $letter
    }

    if { ![ file exists $fname ] } {
        uplevel #0 $oncomplete
        return
    }
    set onerr [ list errorProc [ mc "Error while loading topic %s" $topic ] ]
    if [ catch {
        ::mbox::parseFile $fname $script -sync 1
    } err ] {
        eval [ concat $onerr [ list $err $::errorInfo ] ]
        return
    }
    if { ! [ $messageTree exists "topic" ] } {
        # Topic text are not loaded. Ignoring this error silently...
        uplevel #0 $oncomplete
        return
    }

    setFocusedItem $messageTree "topic"
    update 
    set fname [ file join $cacheDir $topic ]
    if { ![ file exists $fname ] } {
        uplevel #0 $oncomplete
        return
    }
    return [ loadMessagesFromFile \
        $fname \
        $topic \
        $oncomplete \
        -title [ mc "Loading topic %s" $topic ] \
        -cat \
        -onerror $onerr \
    ]
}

proc loadMessagesFromFile {fileName topic oncomplete args} {
    upvar #0 messageTree w

    deflambda processLetter {letter} {
        after idle [ list insertMessage 0 $letter ]
    }
    set id [ ::mbox::initParser $processLetter ]
    set arg [ list \
        -onoutput [ list ::mbox::parseLine $id ] \
        -oncomplete [ join [ list \
            [ list ::mbox::closeParser $id ] \
            update \
            $oncomplete \
        ] ";" ] \
    ]
    return [ eval \
        [ concat [ list ::taskManager::addTask $fileName ] $arg $args ] \
    ]
}

proc saveMessage {id stream} {
    upvar #0 messageTree w

    set newLetter ""
    foreach {key val} [ getItemValue $w $id msg ] {
        if { $key != "X-LOR-Unread" } {
            lappend newLetter $key $val
        }
    }
    lappend newLetter "X-LOR-Unread" [ getItemValue $w $id unread ]
    ::mbox::writeToStream $stream $newLetter
}

proc saveTopicRecursive {stream item} {
    upvar #0 messageTree w

    foreach id [ $w children $item ] {
        saveMessage $id $stream
        saveTopicRecursive $stream $id
    }
}

proc saveTopicToCache {topic} {
    global messageTree
    global cacheDir

    if { $topic != "" && [ $messageTree exists "topic" ] } {
        set fname [ file join $cacheDir $topic ]
        set stream [ open $fname "w" ]
        fconfigure $stream -encoding "utf-8"
        if [ catch {
            saveTopicRecursive $stream "topic"
        } err ] {
            set errInfo $::errorInfo
            catch {close $stream}
            error $err $errInfo
        }
        close $stream
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
        errorProc [ mc "Error loading file %s" $fileName ] $err $::errorInfo
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

    if { $autonomousMode } {
        goOnline
        if { $autonomousMode } {
            return
        }
    }

#TODO: remove all occurences of section from here, do all work in plugin
    if [ regexp -lineanchor -- {^\d+$} $section ] {
        return
    }

    if { [ lsearch -exact {favorites messages sent outcoming draft} $section ] != -1 } {
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

    defclosure fun {section} {letter} {
        global cacheDir

        array set lt $letter
        set header [ ::htmlparse::mapEscapes $lt(Subject) ]
        set id $lt(X-LOR-Id)
        addTopicFromCache $section $id $lt(From) $header \
            [ expr ! [ file exists [ file join $cacheDir "$id.topic" ] ] ] \
            $letter \
            tobegin
    }
    set onerror [ list errorProc [ mc "Fetching topics list failed" ] ]
    set parser [ ::mbox::initParser $fun ]
    defclosure oncomplete {parser section onerror} {} {
        upvar #0 topicTree w
        global threadListSize

        set isError 0
        if [ catch {
            ::mbox::closeParser $parser
        } err ] {
            set errInfo $::errorInfo
            set isError 1
        }

        foreach item [ lrange [ $w children $section ] $threadListSize end ] {
            set count [ expr [ getItemValue $w $item unreadChild ] + [ getItemValue $w $item unread ] ]
            if { $count != "0" } {
                addUnreadChild $w $section "-$count"
            }
            $w delete $item
        }
        if $isError {
            lappend onerror $err $errInfo
            uplevel #0 $onerror
        }
    }
    set category [ getItemValue $topicTree $section text ]
    callPlugin list [ list $section ] \
        -title [ mc "Fetching new topics in category %s" $category ] \
        -onoutput [ list ::mbox::parseLine $parser ] \
        -oncomplete $oncomplete \
        -onerror $onerror
}

#TODO: remove extra parameters(v 1.2+)
#TODO: set all values by one command
proc addTopicFromCache {parent id nick text unread {msg ""} {tobegin ""}} {
    upvar #0 topicTree w

    if { ! [ $w exists $id ] } {
        if { $tobegin != "" } {
            set pos 0
        } else {
            set pos end
        }
        $w insert $parent $pos -id $id

        setItemValue $w $id nick $nick
        setItemValue $w $id text $text
        setItemValue $w $id unread 0
        setItemValue $w $id unreadChild 0
        if { $msg != "" } {
            setItemValue $w $id msg $msg
        } else {
            setItemValue $w $id msg {From "" To "" X-LOR-Time "" Subject "" body ""}
        }
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
        addUnreadChild $w [ $w parent $item ] [ expr $unread - $old ]
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
    if { $w == $::topicTree } {
        openUrl [ ::lor::topicReply $item ]
        return
    }
    if { $::rightViewState != "MESSAGE" } {
        return
    }
    global currentTopic
    if { $item == "topic" } {
        set msgId $currentTopic
    } else {
        set msgId "$currentTopic.$item"
    }
    ::mailEditor::editMessage \
        [ mc "Compose message" ] \
        [ ::mailUtils::makeReplyToMessage \
            [ getItemValue $w $item msg ] \
            $::lorLogin \
            [ list \
                "User-Agent" $::appId \
                "Message-ID" $msgId \
            ] \
        ] \
        [ list \
            outcoming   [ mc "Send" ] \
            draft       [ mc "Save" ] \
        ] \
        outcoming \
        putMailToQueue
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

proc addTopicToFavorites {w item category caption} {
    if { $category == "" } {
        set category "favorites"
    }
    if { $item != $category } {
        set parentSave [ $w parent $item ]
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
            addUnreadChild $w [ $w parent $item ] -1
            addUnreadChild $w $category
        }
    }
    setItemValue $w $item text $caption
    updateItemState $w $item
}

proc deleteTopic {w item} {
    if { ![ isCategoryFixed $item ] } {
        set s [ expr [ getItemValue $w $item unreadChild ]+[ getItemValue $w $item unread ] ]
        if {$s > 0} {
            addUnreadChild $w [ $w parent $item ] -$s
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

    ttk::setTheme $tileTheme
    catch {
    array set color [ list \
        htmlFg  [ ttk::style lookup . -foreground ] \
        htmlBg  [ ttk::style lookup Cell -background ] \
    ]
    }

    option add *Text.font $messageTextFont
    option add *Text.foreground $color(htmlFg)
    option add *Text.background $color(htmlBg)
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
            puts $f "# [ mc $category ] :: [ mc $item ]"
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
            -script [ closure {w} {text} {
                $w item [ $w focus ] -text $text
            } ] \
            -default [ $w item [ $w focus ] -text ] \
            -parent $parent
    }
}

proc nextUnread {w item} {
    set cur [ processItems $w $item [ closure {w} {item} {
        return [ expr [ getItemValue $w $item unread ] != "1" ]
    } ] ]
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
    set cur [ processItems $w $findPos [ closure {w findString} {item} {
        return [ expr [ regexp -nocase -- $findString [ getItemValue $w $item msg ] ] == "0" ]
    } ] ]
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
    if [ regexp {^\d+$} $currentTopic ] {
        append s ": $topicHeader"
        set k [ getItemValue $messageTree {} unreadChild ]
        if { $k != "0" } {
            append s [ mc " \[ %s new \]" $k ]
        }
    } elseif { $currentTopic != "" } {
        append s ": [ getItemValue $::topicTree $currentTopic text ]"
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
        messageBox \
            -type ok \
            -icon info \
            -message [ mc "There are no obsolete topics." ]
        return
    } elseif { [ messageBox \
        -type yesno \
        -default no \
        -icon question \
        -message [ mc "%s obsolete topic(s) will be deleted" $count ] \
        -detail [ mc "Do you want to continue?" ] \
    ] != yes } {
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

#TODO: must be only one window. new items addition must be performed via context menu
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
            [ closure {script categoryWidget nameWidget} {} {
                eval [ concat \
                    $script \
                    [ list \
                        [ $categoryWidget focus ] \
                        [ $nameWidget get ]
                    ] \
                ]
            } ] \
            [ list "destroy" "$f" ] \
        ] ";" \
    ]
    set cancelScript "destroy $f"
    set newCategoryScript [ closure {f categoryWidget parent} {} {
            showFavoritesTree [ mc "Select new category name and location" ] [ mc "New category" ] [ list "createCategory" $categoryWidget $f ] [ $categoryWidget focus ] $parent
        } \
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
    set from $topicTree
    set to $categoryWidget
    processItems $topicTree "favorites" [ closure {from to} {item} {
        if { ![ regexp -lineanchor {^\d+$} $item ] } {
            $to insert [ $from parent $item ] end -id $item -text [ getItemValue $from $item text ]
        }
        return 1
    } ]
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
        bind $w <Control-e> [ list invokeMenuCommand $w edit ]
        bind $w <Control-i> [ list invokeMenuCommand $w userInfo ]
        bind $w <Control-o> [ list invokeMenuCommand $w openMessage ]

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
    bind . <Alt-F4> exitProc

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
                -script [ closure {w i} {vals} {
                    global userTagList
                    array set arr $vals
                    lset userTagList $i [ list $arr(nick) $arr(tag) ]
                    array unset arr
                } ] \
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
        -script [ closure {w} {vals} {
            global userTagList
            array set arr $vals
            lappend userTagList [ list $arr(nick) $arr(tag) ]
            array unset arr
        } ] \
        -parent $parent
}

proc addUserTagListItem {w parent} {
    onePageOptionsDialog \
        -title [ mc "Add user tag" ] \
        -options [ list \
            [ mc "Nick" ] string nick "" "" \
            [ mc "Tag"  ] string tag  "" "" \
        ] \
        -script [ closure {w} {vals} {
            array set arr $vals
            $w insert {} end -text $arr(nick) -values [ list $arr(tag) ]
            array unset arr
        } ] \
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
            -script [ closure {w id} {vals} {
                array set arr $vals
                $w item $id -text $arr(nick) -values [ list $arr(tag) ]
                array unset arr
            } ] \
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
        -script [ lambda {w} {vals} {
            array set arr $vals
            $w insert {} end -text $arr(regexp) -values [ list $arr(color) $arr(element) ]
            array unset arr
        } ] \
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
            -script [ closure {w id} {vals} {
                array set arr $vals
                $w item $id -text $arr(regexp) -values [ list $arr(color) $arr(element) ]
                array unset arr
            } ] \
            -parent $parent
    }
}

proc loadAppLibs {} {
    global libDir
    global auto_path

    lappend auto_path $libDir

    package require gaa_lambda 1.2
    package require gaa_tileDialogs 1.2
    package require gaa_tools 1.0
    package require gaa_mbox 1.1
    package require lorParser 1.2
    package require tkLor_taskManager 1.1
    package require gui_mailEditor 1.0
    package require mailUtils 1.0

    namespace import ::lambda::*
    namespace import ::gaa::tileDialogs::*
    namespace import ::gaa::tools::*
}

proc setPerspective {mode {force ""}} {
    global horPane
    global perspectiveAutoSwitch
    global currentPerspective
    global topicTree messageTree

    if { $mode == "navigation" } {
        .menu entryconfigure 2 -state normal
        .menu entryconfigure 3 -state disabled
        .menu entryconfigure 4 -state disabled
    } elseif { $mode == "reading" } {
        .menu entryconfigure 2 -state disabled
        .menu entryconfigure 3 -state normal
        .menu entryconfigure 4 -state normal

        if { $::rightViewState == "LOCAL" } {
            set st normal
        } else {
            set st disabled
        }
        foreach {m a b c} [ list \
            .menu.message   8 9 2 \
            $::messageMenu  6 7 0 \
        ] {
            foreach i [ list $a $b ] {
                $m entryconfigure $i -state $st
            }
            if { $st == "normal" } {
                $m entryconfigure $c -state disabled
            } else {
                $m entryconfigure $c -state normal
            }
        }
    }
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

proc errorProc {title err {extInfo ""}} {
    global appName
    global debug

    puts stderr "$err $extInfo"
    if $debug {
        append err "\n$extInfo"
    }
    messageBox \
        -title [ mc "%s error" $appName ] \
        -message "$title" \
        -detail "$err" \
        -parent . \
        -type ok \
        -icon error
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

proc initTasksWindow {} {
    global tasksWidget
    global appName

    set tasksWidget [ toplevel .tasksWidget -class Dialog ]
    wm withdraw $tasksWidget
    wm title $tasksWidget [ mc "%s: running tasks" $appName ]
    wm protocol $tasksWidget WM_DELETE_WINDOW toggleTaskList

    bind $tasksWidget <Escape> toggleTaskList

    set w [ ttk::treeview $tasksWidget.list -show tree ]
    grid $w -sticky nswe

    defclosure stopScript {w} {} {
        foreach item [ $w selection ] {
            ::taskManager::stopTask $item
        }
    }
    grid [ buttonBox $tasksWidget \
        [ list -text [ mc "Stop" ] -command $stopScript ] \
        [ list -text [ mc "Stop all" ] -command stopAllTasks ] \
    ] -sticky nswe
    grid columnconfigure $tasksWidget 0 -weight 1 -minsize 300
    grid rowconfigure $tasksWidget 0 -weight 1
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

    set tasks [ ::taskManager::getTasks ]
    set total [ expr [ llength $tasks ] / 2 ]
    if { $total >= 1 } {
        set nonEmptyCategory [ lindex $tasks 1 ]
    } else {
        set nonEmptyCategory ""
    }
    $w delete [ $w children {} ]
    foreach {id title} $tasks {
        $w insert {} end -id $id -text $title
    }
    if { $total != 0 } {
        if { $total == 1 } {
            $statusBarWidget.text configure -text $nonEmptyCategory
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
}

proc bgerror {msg} {
    global appName

    errorProc [ mc "%s error" $appName ] $msg $::errorInfo
}

proc loginCallback {str} {
    global loginCookie loggedIn

    set loginCookie $str
    set loggedIn 1
}

proc login {oncomplete} {
    global lorLogin lorPassword

    set f [ callPlugin login {} \
        -title [ mc "Logging in" ] \
        -mode "r+" \
        -onoutput loginCallback \
        -onerror [ list errorProc [ mc "Login failed" ] ] \
        -oncomplete $oncomplete \
    ]
    puts $f "login: $lorLogin"
    puts $f "password: $lorPassword"
    puts $f ""
}

proc logout {} {
    global loggedIn

    set loggedIn 0
}

proc goOnline {} {
    global appName autonomousMode

    if $autonomousMode {
        if { [ messageBox \
            -message [ mc "Are you want to go to online mode?" ] \
            -type yesno \
            -icon question \
            -default yes \
        ] == yes } {
            set autonomousMode 0
        }
    }
}

proc putMailToQueue {queueName newLetter} {
    upvar #0 $queueName queue
    global autonomousMode

    lappend queue $newLetter
    if { $queueName == "outcoming" && !$autonomousMode } {
        startDelivery
    }
}

proc messageBox {args} {
    global tcl_version appName

    array set opts [ list -title $appName ]
    array set opts $args
    if { $tcl_version <= 8.4 && [ info exists opts(-detail) ] } {
        if [ info exists opts(-message) ] {
            set msg $opts(-message)
        } else {
            set msg ""
        }
        append msg "\n$opts(-detail)"
        set opts(-message) $msg
        array unset opts -detail
    }
    set optsList [ array get opts ]
    array unset opts
    return [ eval [ concat tk_messageBox $optsList ] ]
}

proc callPlugin {action arg args} {
    global libDir
    global tclshPath
    global appId
    global useProxy proxyAutoSelect proxyHost proxyPort proxyAuthorization
    global proxyUser proxyPassword
    global debug

    set command [ concat \
        [ list $tclshPath "$libDir/lorBackend.tcl" "-$action" ] \
        $arg \
    ]
    foreach {var key} {
            appId           useragent
            proxyHost       proxyhost
            proxyPort       proxyport
            proxyUser       proxyuser
            proxyPassword   proxypassword
            libDir          libDir} {
        lappend command "-$key" [ set $var ]
    }
    foreach {var key} {
            useProxy            useproxy
            proxyAutoSelect     autoproxy
            proxyAuthorization  proxyauth
            debug               debug} {
        if [ set $var ] {
            lappend command "-$key"
        }
    }
    return [ eval [ concat [ list taskManager::addTask $command ] $args ] ]
}

proc stopAllTasks {} {
    foreach {id title} [ ::taskManager::getTasks ] {
        ::taskManager::stopTask $id
    }
}

proc loadMessageQueuesFromCache {} {
    global cacheDir

#TODO: do it asynchronously
    foreach q {sent draft outcoming} {
        set fname [ file join $cacheDir $q ]
        ::mbox::parseFile $fname [ closure {q} {letter} {
            upvar #0 $q queue
            lappend queue $letter
        } ] -sync 1
    }
}

proc saveMessageQueuesToCache {} {
    global cacheDir

    foreach q {sent draft outcoming} {
        set fname [ file join $cacheDir $q ]
        set f [ open $fname "w+" ]
        fconfigure $f -encoding "utf-8"
        foreach letter [ set ::$q ] {
            ::mbox::writeToStream $f $letter
        }
        close $f
    }
}

proc showMessageQueue {queue} {
    upvar #0 $queue q

    set i 0
    foreach letter $q {
        array set cur $letter
        set cur(X-LOR-Id) $i
        set cur(X-LOR-ReplyTo-Id) ""
        set cur(X-LOR-Unread) 0
        insertMessage 0 [ array get cur ]
        array unset cur
        incr i
    }
    catch {
        $::messageTree focus 0
    }
}

#TODO: do via tablelist
proc deleteMessage {w item} {
    global currentTopic
    upvar #0 $currentTopic q

    set q [ lreplace $q $item $item ]
    clearTreeItemChildrens $w ""
    showMessageQueue $currentTopic
}

proc edit {w item} {
    if { $::rightViewState != "LOCAL" } {
        return
    }
    ::mailEditor::editMessage \
        [ mc "Compose message" ] \
        [ getItemValue $w $item msg ] \
        [ list \
            outcoming   [ mc "Send" ] \
            draft       [ mc "Save" ] \
        ] \
        outcoming \
        putMailToQueue
}

proc startDelivery {} {
    global autonomousMode
    global deliverTaskId
    global loginCookie loggedIn

    if $autonomousMode {
        goOnline
        if $autonomousMode {
            return
        }
    }

    if { !$loggedIn } {
        login startDelivery
        return
    }

    if { $deliverTaskId != "" } {
        return
    }

    global outcoming
    if { [ llength $outcoming ] < 1 } {
        return
    }
    set letter [ lindex $outcoming 0 ]
    array set msg $letter
    if [ info exists msg(Subject) ] {
        set subject $msg(Subject)
    } else {
        set subject "<no subject>"
    }
    array unset msg
    set deliverTaskId [ callPlugin send {} \
        -title [ mc "Sending message '%s'" $subject ] \
        -mode "r+" \
        -oncomplete [ lambda {} {
            global outcoming sent

            lappend sent [ lindex $outcoming 0 ]
            set outcoming [ lreplace $outcoming 0 0 ]

            set ::deliverTaskId ""
            after idle startDelivery
        } ] \
        -onerror [ closure {subject} {err} {
            set ::deliverTaskId ""
            errorProc [ mc "Error while sending '%s'" $subject ] $err
        } ] \
    ]
    puts $deliverTaskId $loginCookie
    puts $deliverTaskId ""
    ::mbox::writeToStream $deliverTaskId $letter

#TODO: remove stubbed message
    ::mbox::writeToStream $deliverTaskId {From stub body ""}
}

############################################################################
#                                   MAIN                                   #
############################################################################

processArgv

initDirs
loadAppLibs
loadConfig

if { [ tk appname $appName ] != $appName } {
    send -async $appName {showWindow}
    exit 1
}

initMainWindow
initTasksWindow
initMenu

update

applyOptions
::taskManager::setUpdateHandler updateTaskList

update

loadTopicListFromCache
loadMessageQueuesFromCache

if {! [ file exists [ file join $configDir "config" ] ] } {
    showOptionsDialog
}

if { $updateOnStart == "1" } {
    updateTopicList
}

setPerspective $currentPerspective

