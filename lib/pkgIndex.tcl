# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded gaa_lambda 1.0 [list source [file join $dir gaa_lambda.tcl]]
package ifneeded gaa_tileDialogs 1.0 [list source [file join $dir gaa_tileDialogs.tcl]]
package ifneeded gaa_tools 1.0 [list source [file join $dir gaa_tools.tcl]]
package ifneeded gaa_mbox 1.0 [list source [file join $dir gaa_mbox.tcl]]
package ifneeded lorParser 1.0 [list source [file join $dir lorParser.tcl]]
