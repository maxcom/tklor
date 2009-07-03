# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="Tcl/Tk client for reading linux.org.ru"
HOMEPAGE="http://code.google.com/p/tklor/"
SRC_URI="http://tklor.googlecode.com/files/${PN}_${PV}-1.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh
~sparc ~sparc-fbsd ~x86 ~x86-fbsd"
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
	dobin tkLOR
	insinto /usr/lib/tkLOR
	doins lib/* 
	insinto /usr/share/pixmaps
	doins tklor.xpm
	insinto /usr/share/applications
	doins tklor.desktop
	
	dosym tkLOR /usr/bin/tklor
	dodoc README UPGRADE
	docinto examples
	dodoc config userConfig
}

pkg_postinst() {
	einfo "========== tkLOR successfully installed ==========="
	einfo "     take a look at /usr/share/doc/${P}            "
	einfo "                happy trolling;)                   "
}
