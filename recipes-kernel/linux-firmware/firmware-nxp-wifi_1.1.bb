SUMMARY = "Wi-Fi and Bluetooth firmware redistributed by NXP"
DESCRIPTION = "Firmware for the NXP IW612 combo part in the Mecha Comet. The \
kernel's nxpwifi_sdio driver and the 88W8987 Bluetooth attach both load from \
/lib/firmware/nxp; linux-firmware does not carry the .se-signed IW612 images."
HOMEPAGE = "https://github.com/nxp-imx/imx-firmware"

SECTION = "kernel"
LICENSE = "LicenseRef-Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=bc649096ad3928ec06a8713b8d787eac"

# LicenseRef-Proprietary has no text in oe-core's common-licenses, and the layer
# that normally supplies one - meta-freescale - is deliberately not part of this
# build. Point at the copy in the source tree instead, or do_populate_lic fails
# with "No generic license file exists for: LicenseRef-Proprietary".
NO_GENERIC_LICENSE[LicenseRef-Proprietary] = "LICENSE.txt"

SRC_URI = "git://github.com/nxp-imx/imx-firmware.git;protocol=https;branch=${SRCBRANCH}"
SRCBRANCH = "lf-6.18.2_1.0.0"
SRCREV = "d7e4bb37b45bbf93faf888e0ca6763a29e28054a"

inherit allarch

CLEANBROKEN = "1"
ALLOW_EMPTY:${PN} = "1"

do_compile[noexec] = "1"

# Install only the IW612 SDIO set, not the whole repository.
#
# "oe_runmake install", which is what meta-freescale does, lays down every
# firmware in the tree - 8987, 8997, 9098, AW693, IW416, IW610 - about 200 MB
# for parts the Comet does not have. meta-freescale then splits that eleven ways
# so each reference board can pick its own. There is one radio here, so copying
# the files it loads is both smaller and clearer, and it avoids an
# installed-but-not-shipped QA failure on everything left over.
#
# The three IW612 images are the SDIO Wi-Fi-only blob, the Wi-Fi+BT combo, and
# the combo with dual-PAN Zigbee. nxpwifi picks by what the DT describes
# (nxp,iw61x on SDIO plus the nxp,88w8987-bt node), so ship all three rather
# than guessing which one the driver will ask for.
#
# helper_uart_3000000.bin and wifi_mod_para.conf are the shared bits the driver
# reads regardless of chip.
do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/nxp

    install -m 0644 ${S}/FwImage_IW612_SD/sd_w61x_v1.bin.se               ${D}${nonarch_base_libdir}/firmware/nxp/
    install -m 0644 ${S}/FwImage_IW612_SD/sduart_nw61x_v1.bin.se          ${D}${nonarch_base_libdir}/firmware/nxp/
    install -m 0644 ${S}/FwImage_IW612_SD/sduart_nw61x_v1_zb_dual_pan.bin.se ${D}${nonarch_base_libdir}/firmware/nxp/
    install -m 0644 ${S}/mfguart/helper_uart_3000000.bin                  ${D}${nonarch_base_libdir}/firmware/nxp/
    install -m 0644 ${S}/wifi_mod_para.conf                               ${D}${nonarch_base_libdir}/firmware/nxp/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/nxp"
