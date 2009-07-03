# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="Tcl/Tk client for reading linux.org.ru"
HOMEPAGE="http://code.google.com/p/tklor/"
SRC_URI="http://tklor.googlecode.com/files/${PN}_${PV}-1.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE=""

DEPEND="|| ( ( dev-tcltk/tile
               >=dev-lang/tcl-8.4
			   >=dev-lang/tk-8.4 )
			 ( >=dev-lang/tcl-8.5_beta1
               >=dev-lang/tk-8.5_beta1 ) )
	    dev-tcltk/tcllib"
RDEPEND=${DEPEND}

src_compile() {
	return 0
}

src_install() {	
	dodir /usr/share/tklor
	cp tkLOR ${D}/usr/share/tklor
	insinto /usr/share/pixmaps
	doins tklor.xpm
	insinto /usr/share/applications
	doins tklor.desktop
	insinto usr/lib/tkLOR
	lib/gaa_lambda.tcl
	lib/gaa_mbox.tcl
	lib/gaa_remoting.tcl
	lib/gaa_tileDialogs.tcl
	lib/gaa_tools.tcl
	lib/lorParser.tcl
	lib/lorBackend.tcl
	lib/pkgIndex.tcl
	
	chmod +x tkLOR
	dobin tkLOR
	dosym ../share/tklor/tkLOR /usr/bin/tklor
	dosym ../share/tklor/tkLOR /usr/bin/tkLOR
	dodoc readme
	docinto examples
	dodoc config userConfig
}

pkg_postinst() {
	einfo "========== tkLOR successfully installed ==========="
	einfo "     take a look at /usr/share/doc/${P}            "
	einfo "                happy trolling;)                   "
}
