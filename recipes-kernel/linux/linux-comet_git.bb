DESCRIPTION = "Mecha Comet Linux Kernel"

require linux-mecha.inc

COMPATIBLE_MACHINE = "(comet-imx8mp|comet-imx95)"
LINUX_VERSION_EXTENSION = "-comet"

SRC_URI += " \
    file://extra.cfg \
"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
