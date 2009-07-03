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

package provide lorParser 1.1

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
    getMessageUrl

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

    set err 1
    set errStr ""
    set url "$lorUrl/view-message.jsp?msgid=$topic&page=-1"

    ::http::geturl $url -command [ ::gaa::lambda::lambda {topicTextCommand messageCommand onError onComplete token} {
        if [ catch {
            if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
                ::lor::parseTopicText [ ::http::data $token ] $topicTextCommand
                ::lor::parsePage [ ::http::data $token ] $messageCommand
            } else {
                error [ ::http::code $token ]
            }
        } err ] {
            eval [ concat $onError [ list $err ] ]
        }
        ::http::cleanup $token
        eval $onComplete
    } $topicTextCommand $messageCommand $onError $onComplete ]
}

proc parseTopicText {data command} {
    set nick ""
    set header "Unable to parse"
    set msg "Unable to parse topic text :("
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
            error "$section is not valid LOR object ID!"
        }
    }
}

proc parseGroup {command section {group ""}} {
    variable lorUrl

    set url "$lorUrl/section-rss.jsp?section=$section"
    if { $group != "" } {
        append url "&group=$group"
    }
    set err 1

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

    if { [ catch { set token [ ::http::geturl $url ] } errStr ] == 0 } {
        if { [ ::http::status $token ] == "ok" && [ ::http::ncode $token ] == 200 } {
            #decoding binary data
            set data [ encoding convertfrom "utf-8" [ ::http::data $token ] ]

            parseRss $data $processRssItem
            set err 0
        } else {
            set errStr [ ::http::code $token ]
        }
        ::http::cleanup $token
    }
    if $err {
        error $errStr
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

}
