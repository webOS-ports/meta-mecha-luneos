# ${BPN}, and SRC_URI only.
#
# The base recipe's do_install:append already installs sensord-${MACHINE}.conf
# out of UNPACKDIR and symlinks primaryuse.conf at it, so a bbappend that also
# installed the file - or installed it as sensord.conf - would either duplicate
# the work or write a file nothing reads. Adding it to SRC_URI is the whole job.
FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI:append:comet-imx8mp = " \
    file://sensord-comet-imx8mp.conf \
"
