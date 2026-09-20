SUMMARY = "Synopsys LPDDR4 PHY training firmware for i.MX 8M"
DESCRIPTION = "The four PHY training blobs the i.MX8M SPL loads to bring up \
LPDDR4. u-boot's binman packs them into flash.bin; without them the SPL cannot \
train the DDR and the board never reaches u-boot proper."
HOMEPAGE = "https://www.nxp.com/"
SECTION = "base"

# NXP's own EULA, not an open licence, and the archive is a self-extracting
# shell script that prints it and waits for agreement. Nothing pulls this in
# unless the builder has said yes:
#
#     LICENSE_FLAGS_ACCEPTED += "imx-firmware"
#
# in local.conf. That is the same gate meta-freescale puts on the same file.
LICENSE = "LicenseRef-Proprietary"
LIC_FILES_CHKSUM = "file://COPYING;md5=bc649096ad3928ec06a8713b8d787eac"
LICENSE_FLAGS = "imx-firmware"

# As in firmware-nxp-wifi: no generic text for LicenseRef-Proprietary without
# meta-freescale, so take it from the unpacked archive.
NO_GENERIC_LICENSE[LicenseRef-Proprietary] = "COPYING"

IMX_SRCREV_ABBREV = "1991416"

SRC_URI = "https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}.bin;downloadfilename=firmware-imx-${PV}-${IMX_SRCREV_ABBREV}.bin;unpack=0"
SRC_URI[sha256sum] = "11396e5798b62cd61963db806c0c05500887bc62a98e1d16dbc3014aa0c21a2a"

S = "${UNPACKDIR}/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}"

# This layer does not depend on meta-freescale, so fsl-eula-unpack.bbclass is
# not available and the unpack is done here. The archive is a shell self-
# extractor; --auto-accept skips the interactive prompt, which is safe only
# because LICENSE_FLAGS above already forced the builder to accept explicitly.
do_unpack[cleandirs] = "${UNPACKDIR}"
do_unpack:append() {
    import subprocess
    archive = d.expand("${UNPACKDIR}/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}.bin")
    subprocess.check_call(["sh", archive, "--auto-accept", "--force"],
                          cwd=d.getVar("UNPACKDIR"))
}

inherit deploy nopackages

do_configure[noexec] = "1"
do_compile[noexec] = "1"
do_install[noexec] = "1"

# Only the LPDDR4 set, and only the 202006 revision of it: that is what
# arch/arm/dts/imx8mp-u-boot.dtsi names in its binman node. The DDR3L/DDR4 and
# older-dated blobs in the same archive are for other boards and would just be
# dead weight in DEPLOY_DIR_IMAGE.
DDR_FIRMWARE_NAME = " \
    lpddr4_pmu_train_1d_imem_202006.bin \
    lpddr4_pmu_train_1d_dmem_202006.bin \
    lpddr4_pmu_train_2d_imem_202006.bin \
    lpddr4_pmu_train_2d_dmem_202006.bin \
"

do_deploy() {
    install -d ${DEPLOYDIR}/firmware-imx-ddr
    for f in ${DDR_FIRMWARE_NAME}; do
        install -m 0644 ${S}/firmware/ddr/synopsys/$f ${DEPLOYDIR}/firmware-imx-ddr/
    done
}
addtask deploy after do_install before do_build

PACKAGE_ARCH = "${MACHINE_ARCH}"

# i.MX8M only. The i.MX95 does not train DDR this way at all - its container is
# built from ELE firmware, the M33 System Manager and OEI/DDR images - so
# pointing that machine at this recipe would be a category error, not a missing
# version. See conf/machine/include/imx95.inc.
COMPATIBLE_MACHINE = "(comet-imx8mp)"
