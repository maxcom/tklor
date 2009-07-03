# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils

DESCRIPTION="LOR aggregator"
HOMEPAGE="http://tklor.googlecode.com/"
MYPV="0.6.0"
SRC_URI="http://tklor.googlecode.com/files/${PN}_${MYPV}-1.tar.gz"
	
IUSE=""

DEPEND=">=dev-lang/tcl-8.5_beta1
	>=dev-lang/tk-8.5_beta1"

LICENSE="GPL-2"
KEYWORDS="~alpha ~amd64 sparc x86 ~x86"
SLOT="0"

src_compile() {
	# dont run make, because the Makefile is broken with all=install
	echo -n
}

src_install() {
	
	cd ${WORKDIR}/${PN}-${MYPV} || die "cd failed!"
	dodir /usr/share/tklor
	cp tkLOR ${D}/usr/share/tklor
	dodir /usr/share/tklor/examples
	cp config userConfig ${D}/usr/share/tklor/examples
	insinto /usr/share/pixmaps
	doins tklor.xpm
	insinto /usr/share/applications
	doins tklor.desktop
	

	cat <<-EOF > tkLOR
	#!/bin/sh
	exec wish /usr/share/tklor/tkLOR -name tklor
	EOF
	chmod +x tkLOR
	dobin tkLOR
	dosym tkLOR /usr/bin/tklor
	dodoc readme
}

pkg_postinst() {
	einfo "========== tkLOR successfully installed ==========="
	einfo "     take a look at /usr/share/tklor/examples      "
	einfo "          and  /usr/share/doc/tkor-0.6             "
	einfo "                happy trolling;)                   "
}
