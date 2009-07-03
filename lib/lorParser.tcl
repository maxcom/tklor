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

package provide lorParser 1.2

package require Tcl 8.4
package require http 2.0
package require gaa_lambda 1.0
package require htmlparse 1.1

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
}

variable lorUrl "http://www.linux.org.ru"

proc parseTopic {topic topicTextCommand messageCommand onError onComplete} {
    variable lorUrl

    set url "$lorUrl/view-message.jsp?msgid=$topic&page=-1"

    if [ catch {::http::geturl $url -command [ ::gaa::lambda::lambda {topicTextCommand messageCommand onError onComplete token} {
            if [ catch {
                if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
                    ::lor::parseTopicText [ ::http::data $token ] $topicTextCommand
                    ::lor::parsePage [ ::http::data $token ] $messageCommand
                } else {
                    error [ ::http::code $token ]
                }
            } err ] {
                eval [ concat $onError [ list $err $::errorInfo ] ]
            }
            catch {::http::cleanup $token}
            eval $onComplete
        } $topicTextCommand $messageCommand $onError $onComplete ]
    } err ] {
        eval [ concat $onError [ list $err $::errorInfo ] ]
        eval $onComplete
    }
}

proc parseTopicText {data command} {
    set nick ""
    set header "Unable to parse topic header"
    set msg "Oops, something goes wrong :("
    set time ""
    set approver ""
    set approveTime ""
    regexp -- {<div class=msg>(?:<table><tr><td valign=top align=center><a [^>]*><img [^>]*></a></td><td valign=top>){0,1}<h1><a name=\d+>([^<]+)</a></h1>(.*?)<div class=sign>([\w-]+) +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)(?:<br><i>[^ ]+ ([\w-]+) \(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) ([^<]+)</i>){0,1}</div>.*?<table class=nav>} $data dummy header msg nick time approver approveTime
    eval [ concat $command [ list $nick $header $msg $time $approver $approveTime ] ]
}

proc parsePage {data command} {
    foreach {dummy1 message} [ regexp -all -inline -- {(?:<!-- \d+ -->.*(<div class=title>.*?</div></div>))+?} $data ] {
        if [ regexp -- {(?:<div class=title>[^<]+<a href="view-message.jsp\?msgid=\d+(?:&amp;lastmod=\d+){0,1}(?:&amp;page=\d+){0,1}#(\d+)"[^>]*>[^<]*</a> \w+ ([\w-]+) [^<]+</div>){0,1}<div class=msg id=(\d+)><h2>([^<]+)</h2>(.*?)<div class=sign>(?:<s>){0,1}([\w-]+)(?:</s>){0,1} +(?:<img [^>]+>)* ?\(<a href="whois.jsp\?nick=[\w-]+">\*</a>\) \(([^)]+)\)</div>} $message dummy2 parent parentNick id header msg nick time ] {
            eval [ concat $command [ list $id $nick $header $time $msg $parent $parentNick ] ]
        }
    }
}

proc getTopicList {section command onError onComplete} {
    switch -regexp $section {
        {^news$} {
            parseGroup $command 1 "" $onError $onComplete
        }
        {^news\d+$} {
            parseGroup $command 1 [ string trimleft $section "news" ] $onError $onComplete
        }
        {^gallery$} {
            parseGroup $command 3 "" $onError $onComplete
        }
        {^votes$} {
            parseGroup $command 5 "" $onError $onComplete
        }
        {^forum$} {
            parseGroup $command 2 "" $onError $onComplete
        }
        {^forum\d+$} {
            parseGroup $command 2 [ string trimleft $section "forum" ] $onError $onComplete
        }
        default {
            # simply ignore it
            eval $onComplete
        }
    }
}

proc parseGroup {command section group onError onComplete} {
    variable lorUrl

    set url "$lorUrl/section-rss.jsp?section=$section"
    if { $group != "" } {
        append url "&group=$group"
    }

    ::gaa::lambda::deflambda processRssItem {command item} {
        array set v {
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
        # at this moment nick field are not present in RSS feed
        set nick ""
        eval [ concat $command [ list $id $nick $header ] ]
    } $command

    if { [ catch { ::http::geturl $url -command [ ::gaa::lambda::lambda {processRssItem onError onComplete token} {
            if [ catch {
                if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
                    #decoding binary data
                    set data [ encoding convertfrom "utf-8" [ ::http::data $token ] ]
                    ::lor::parseRss $data $processRssItem
                } else {
                    error [ ::http::code $token ]
                }
            } err ] {
                eval [ concat $onError [ list $err $::errorInfo ] ]
            }
            catch {::http::cleanup $token}
            eval $onComplete
        } $processRssItem $onError $onComplete ]
    } err ] } {
        eval [ concat $onError [ list $err $::errorInfo ] ]
        eval $onComplete
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
        -command [ ::gaa::lambda::lambda {onError onComplete token} {
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
        } $onError $onComplete ]
    } err ] {
        eval [ concat $onError [ list $topic $message $title $text $preformattedText $autoUrl $err $::errorInfo ] ]
        eval $onComplete
    }
}

}
