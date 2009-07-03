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

MY_UPDATED=0

pkg_setup() {
	if has_version '<www-client/tklor-1.0.0' ; then
	echo
		ewarn "Upgrading from pre-1.0 tkLOR version"
		ewarn "Please read the upgrade notes after installation"
		MY_UPDATED=1
	fi
}


src_compile() {
	return 0
}

src_install() {	
	dobin tkLOR
	insinto /usr/lib/tkLOR
	doins lib/* 
	insinto /usr/lib/tkLOR/msgs
	doins lib/msgs/*

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
	if [[ "${MY_UPDATED}" -eq "1" ]] ; then
		echo
		ewarn "=============== tkLOR upgrade notes ==============="
		ewarn "Since version 1.0.0 tkLOR uses the new config files location"
		ewarn "Read /usr/share/doc/${P}/UPGRADE.bz2 for update instructions"
	fi
}
