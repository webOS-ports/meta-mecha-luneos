SUMMARY = "U-Boot for the Mecha Comet"
DESCRIPTION = "Mecha's downstream U-Boot. board/mecha/comet carries the Comet's \
SPL, its LPDDR4 timing tables and its boot environment; none of it is upstream."

require recipes-bsp/u-boot/u-boot-common.inc
require recipes-bsp/u-boot/u-boot.inc

# u-boot-common.inc and u-boot.inc do not carry the whole dependency set: some
# of it lives in oe-core's versioned u-boot_2026.01.bb, which this recipe
# deliberately does not require (different source tree entirely). Keep this list
# in step with that file's DEPENDS when oe-core moves.
#
# gnutls-native is the non-obvious one: Mecha's defconfigs set
# CONFIG_EFI_CAPSULE_ON_DISK and CONFIG_EFI_RUNTIME_UPDATE_CAPSULE, which pull
# tools/mkeficapsule into the host-tools build, and that includes
# <gnutls/gnutls.h>. Without it do_compile dies on a missing header long after
# configure has succeeded.
DEPENDS += "bc-native dtc-native gnutls-native python3-setuptools-native python3-pyelftools-native"

PROVIDES += "u-boot"

# Mecha's tree, not denx. u-boot-common.inc sets SRC_URI and SRCREV for denx
# and both have to be replaced outright, not appended to.
PV = "2026.07"
SRCREV = "a28d9447bed992f0fa3488d10164e8b4a34b8e1b"
SRC_URI = " \
    git://github.com/mecha-org/u-boot.git;protocol=https;branch=v2026.07-mecha \
    file://luneos-no-optee.cfg \
"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

COMPATIBLE_MACHINE = "(comet-imx8mp|comet-imx95)"

# One build per DDR size.
#
# board/mecha/comet/lpddr4_timing_{2,4,8}gb.c are three different PHY training
# tables and the SPL has no run-time detection to pick between them, so the
# choice is made at compile time and there is nothing to share. UBOOT_CONFIG is
# exactly the mechanism for this - it runs configure/compile/deploy once per
# entry and keeps the outputs apart.
UBOOT_MACHINE = ""
UBOOT_CONFIG ??= "2gb 4gb 8gb"
UBOOT_CONFIG[2gb] = "mecha-comet-imx8mp-2gb_defconfig"
UBOOT_CONFIG[4gb] = "mecha-comet-imx8mp-4gb_defconfig"
UBOOT_CONFIG[8gb] = "mecha-comet-imx8mp-8gb_defconfig"

UBOOT_CONFIG_BINARY[2gb] = "flash.bin"
UBOOT_CONFIG_BINARY[4gb] = "flash.bin"
UBOOT_CONFIG_BINARY[8gb] = "flash.bin"

# The artifact the i.MX8M boot ROM actually reads is flash.bin - the container
# binman builds out of the DDR blobs, the SPL, bl31.bin and u-boot proper - not
# u-boot.bin. Naming it here is what makes the class deploy flash-<type>-<ver>.bin
# with flash.bin-<type> symlinks beside it.
UBOOT_SUFFIX = "bin"
UBOOT_BINARY = "flash.bin"

# The i.MX95 uses the same recipe with a different container (ELE firmware, the
# M33 System Manager, OEI/DDR images, TF-A). The defconfig name is not known
# because Mecha has not published one - conf/machine/comet-imx95.conf refuses to
# parse until COMET_IMX95_UBOOT_CONFIG is set, so this cannot silently build the
# wrong thing.
UBOOT_CONFIG:comet-imx95 = "imx95"
UBOOT_CONFIG[imx95] = "${COMET_IMX95_UBOOT_CONFIG}"
UBOOT_CONFIG_BINARY[imx95] = "flash.bin"

# binman needs bl31.bin and the four DDR training blobs to exist in the build
# directory before it can pack the container. It looks in the O= directory
# first (the Makefile passes binman "-I ."), which is ${B}/<config>-<type>.
DEPENDS += "trusted-firmware-a"
do_compile[depends] += " \
    trusted-firmware-a:do_deploy \
    ${@'firmware-imx-ddr:do_deploy' if d.getVar('SOC_FAMILY') == 'imx8mp' else ''} \
"

do_compile:prepend() {
    # Every configured build directory, rather than replaying the class's
    # index-matching loop over UBOOT_MACHINE and UBOOT_CONFIG: do_configure has
    # already created exactly these, and a .config is what tells them apart from
    # anything else that might land under ${B}.
    for builddir in ${B}/*/; do
        [ -f "$builddir/.config" ] || continue

        install -m 0644 ${DEPLOY_DIR_IMAGE}/trusted-firmware-a/bl31.bin "$builddir"

        if [ "${SOC_FAMILY}" = "imx8mp" ]; then
            for f in ${DEPLOY_DIR_IMAGE}/firmware-imx-ddr/*.bin; do
                install -m 0644 "$f" "$builddir"
            done
        fi
    done
}
