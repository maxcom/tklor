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

package provide lorParser 1.3

package require Tcl 8.4
package require http 2.0
package require gaa_lambda 1.2
package require htmlparse 1.1
package require struct::tree 2.0

namespace eval lor {

namespace export \
    parseTopic \
    getTopicList \
    topicReply \
    messageReply \
    userInfo \
    getTopicUrl \
    getMessageUrl \
    login

variable forumGroups {
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
    19390   Club
}

variable lorUrl "http://www.linux.org.ru"
variable id 0

proc parseTopic {topic topicTextCommand messageCommand lastId} {
    variable lorUrl
    variable id

    set url "$lorUrl/view-message.jsp?msgid=$topic&page="

    set page 10000
    set maxPage ""
    if [ catch {
        set token [ ::http::geturl "$url$page" ]
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            set data [ ::http::data $token ]
            parseTopicText $data $topicTextCommand
            set maxPage [ parseMaxPageNumber $data ]
        } else {
            set err [ ::http::code $token ]
            ::http::cleanup $token
            error $err
        }
        ::http::cleanup $token
    } err ] {
        error $err $::errorInfo
    }

#TODO: set To: for all messages (if not present, set to topic's From:)
    set tree [ struct::tree ]
    if [ catch {
        for {set page $maxPage} {$page >= 0} {incr page -1} {
            set token [ ::http::geturl "$url$page" ]
            if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
                set minId [ parsePage [ ::http::data $token ] [ lambda::closure {tree lastId} {id nick header time msg parent parentNick} {
                    if { $id <= $lastId } {
                        return
                    }
                    if { $parent == "" } {
                        set p root
                    } else {
                        set p $parent
                    }
                    if { ![ $tree exists $p ] } {
                        $tree insert root end $p
                        $tree set $p valid 0
                    }
                    eval [ concat [ list $tree insert $p end ] [ lsort -increasing -integer [ concat [ list $id ] [ $tree children $p ] ] ] ]
                    $tree set $id valid 1
                    $tree set $id args [ list $id $nick $header $time $msg $parent $parentNick ]
                } ] ]
                if { $minId <= $lastId} {
                    break
                }
            } else {
                set err [ ::http::code $token ]
                ::http::cleanup $token
                error $err
            }
            ::http::cleanup $token
        }
    } err ] {
        set errInfo $::errorInfo
        $tree destroy
        error $err $errInfo
    }

    $tree walk root item {
        if { $item != "root" } {
            if { [ $tree get $item valid ] } {
                uplevel #0 [ concat $messageCommand [ $tree get $item args ] ]
            } elseif { $item > $lastId } {
                foreach c [ $tree children $item ] {
                    $tree set $c valid 0
                }
            }
        }
    }
    $tree destroy
}

proc parseMaxPageNumber {data} {
    if [ regexp -- {<div class="pageinfo">.*page=(\d+).>\d+</a>\].*</div>} $data dummy page ] {
        return $page
    } else {
        return 0
    }
}

proc parseTopicText {data command} {
    if [ regexp -- {<div class=msg>(?:<table><tr><td valign=top align=center><a [^>]*><img [^>]*></a></td><td valign=top>){0,1}<h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>(?:<s>){0,1}([\w-]+)(?:</s>){0,1} +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)(?:<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i>){0,1}</div>.*?<table class=nav>} $data dummy header msg nick time approver approveTime ] {
        uplevel #0 [ concat $command [ list $nick $header $msg $time $approver $approveTime ] ]
    } else {
        error "Unable to parse topic text"
    }
}

proc parsePage {data command} {
    set minId 99999999
    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- \
{(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}(?:&amp;page=\d+){0,1}#(\d+)"[^>]*>[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*?)<div class=sign>(?:<s>){0,1}([\w-]+)(?:</s>){0,1} +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div>} \
$message dummy2 parent parentNick id header msg nick time ] {
            if { $id < $minId} {
                set minId $id
            }
            uplevel #0 [ concat $command [ list $id $nick $header $time $msg $parent $parentNick ] ]
        }
    }
    return $minId
}

proc getTopicList {section command} {
    switch -regexp $section {
        {^news$} {
            parseGroup $command 1
        }
        {^news\d+$} {
            parseGroup $command 1 [ string trimleft $section "news" ]
        }
        {^gallery$} {
            parseGroup $command 3
        }
        {^votes$} {
            parseGroup $command 5
        }
        {^forum$} {
            parseGroup $command 2
        }
        {^forum\d+$} {
            parseGroup $command 2 [ string trimleft $section "forum" ]
        }
        default {
            error "Unknown section ID: $section"
        }
    }
}

proc parseGroup {command section {group ""}} {
    variable lorUrl

    set url "$lorUrl/section-rss.jsp?section=$section"
    if { $group != "" } {
        append url "&group=$group"
    }

    ::lambda::defclosure processRssItem {command} {item} {
        array set v {
            author ""
            title ""
            link ""
            guid ""
            pubDate ""
            description ""
        }
        array set v $item
        if { ![ regexp -lineanchor {msgid=(\d+)$} $v(link) dummy3 id ] } {
            return
        }
        set header $v(title)
        set msg $v(description)
        set date $v(pubDate)
        set nick $v(author)
        uplevel #0 [ concat $command [ list $id $nick $header $date $msg ] ]
    }

    if [ catch {
            set token [ ::http::geturl $url ]
            if { [ ::http::status $token ] == "ok" &&
                    [ ::http::ncode $token ] == 200 } {
                #decoding binary data
                set data \
                    [ encoding convertfrom "utf-8" [ ::http::data $token ] ]
                parseRss $data $processRssItem
            } else {
                set err [ ::http::code $token ]
                ::http::cleanup $token
                error $err
            }
            ::http::cleanup $token
    } err ] {
        error $err $::errorInfo
    }
}

proc parseRss {data script} {
    foreach {dummy1 item} [ regexp -all -inline -- {<item>(.*?)</item>} $data ] {
        set v ""
        foreach {dummy2 tag content} [ regexp -all -inline -- {<([\w-]+)>([^<]*)</[\w-]+>} $item ] {
            lappend v $tag [ ::htmlparse::mapEscapes $content ]
        }
        eval [ concat $script [ list $v ] ]
    }
}

proc topicReply {item} {
    variable lorUrl

    switch -regexp $item {
        {^news$} {
            return "$lorUrl/add-section.jsp?section=1"
        }
        {^forum$} {
            return "$lorUrl/add-section.jsp?section=2"
        }
        {^forum\d+$} {
            return "$lorUrl/add.jsp?group=[ string trim $item forum ]"
        }
        {^gallery$} {
            return "$lorUrl/add.jsp?group=4962"
        }
        {^votes$} {
            return "$lorUrl/add-poll.jsp"
        }
        {^\d+$} {
            return "$lorUrl/comment-message.jsp?msgid=$item"
        }
    }
}

proc messageReply {item topic} {
    variable lorUrl

    return "$lorUrl/add_comment.jsp?topic=$topic&replyto=$item"
}

proc userInfo {nick} {
    variable lorUrl

    return "$lorUrl/whois.jsp?nick=$nick"
}

proc getTopicUrl {item} {
    variable lorUrl

    switch -regexp $item {
        {^news$} {
            return "$lorUrl/view-news.jsp?section=1"
        }
        {^forum$} {
            return "$lorUrl/view-section.jsp?section=2"
        }
        {^forum\d+$} {
            return "$lorUrl/group.jsp?group=[ string trim $item forum ]"
        }
        {^gallery$} {
            return "$lorUrl/view-news.jsp?section=3"
        }
        {^votes$} {
            return "$lorUrl/group.jsp?group=19387"
        }
        {^\d+$} {
            return "$lorUrl/jump-message.jsp?msgid=$item"
        }
    }
}

proc getMessageUrl {item topic} {
    variable lorUrl

    return "$lorUrl/jump-message.jsp?msgid=$topic&cid=$item"
}

proc startSession {} {
    variable lorUrl

    set url "$lorUrl/server.jsp"
    set token [ ::http::geturl $url ]
    if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
        upvar #0 $token state
        array set meta $state(meta)
        ::http::cleanup $token
        if [ regexp -lineanchor {^JSESSIONID=(\w+);} $meta(Set-Cookie) dummy session ] {
            return $session
        } else {
            error "Unable to start LOR session!"
        }
    } else {
        set err [ ::http::code $token ]
        ::http::cleanup $token
        error $err
    }
}

proc login {user password} {
    variable lorUrl

    set url "$lorUrl/login.jsp"

    if [ catch {
        set token [ ::http::geturl $url \
            -query [ ::http::formatQuery "nick" $user "passwd" $password ] \
            -headers [ list "JSESSIONID" [ startSession ] ] \
        ]

        # Yes, ::http::ncode must be 302 :)
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 302 } {
            upvar #0 $token state

            set cookies ""
            foreach {key value} $state(meta) {
                if { $key == "Set-Cookie" && \
                    [ regexp -lineanchor {^(\w+)=(\w+); (?:Expires=[^;]+; ){0,1}Path=/$} $value dummy id val ] } {
                    lappend cookies $id $val
                }
            }
            ::http::cleanup $token
        } else {
            set err [ ::http::code $token ]
            ::http::cleanup $token
            error $err
        }
    } err ] {
        error $err
    }
    return $cookies
}

proc postMessage {topic message title text preformattedText autoUrl onError onComplete} {
    variable lorUrl
#move to params
    variable cookies
    variable loggedIn

    if { !$loggedIn } {
        eval [ concat $onError [ list $topic $message $title $text $preformattedText $autoUrl "You must be logged in before sending messages" ] ]
        eval $onComplete

        return
    }

    array set param $cookies
    if $preformattedText {
        set mode "pre"
    } else {
        set mode "quot"
    }

    set url "$lorUrl/add_comment.jsp?topic=$topic"
    set s ""
    foreach {name value} $cookies {
        lappend s "$name=$value"
    }
    set headers [ list "Cookie" [ join $s "; " ] ]

    set queryList [ list \
        "topic"     $topic \
        "title"     $title \
        "msg"       $text \
        "mode"      $mode \
        "autourl"   $autoUrl \
        "texttype"  0 \
    ]
    if [ catch {lappend queryList "session" $param(JSESSIONID)} err ] {
        eval [ concat $onError [ list $topic $message $title $text $preformattedText $autoUrl $err "$::errorInfo\ncookies=$cookies" ] ]
        eval $onComplete

        return
    }
    if { $message != "" } {
        lappend queryList "replyto" $message
        append url "&replyto=$message"
    }

    if [ catch {::http::geturl $url \
        -headers $headers \
        -query [ eval [ concat ::http::formatQuery $queryList ] ] \
        -command [ ::lambda::closure {onError onComplete} {token} {
            if [ catch {
                # here 302 too :)
                if { [ ::http::status $token ] != "ok" || [ ::http::ncode $token ] != 302 } {
                    error [ ::http::code $token ]
                }
            } err ] {
                eval [ concat $onError [ list $err [ ::http::data $token ] ] ]
            }
            catch {::http::cleanup $token}
            eval $onComplete
        } ]
    } err ] {
        eval [ concat $onError [ list $topic $message $title $text $preformattedText $autoUrl $err $::errorInfo ] ]
        eval $onComplete
    }
}

}
