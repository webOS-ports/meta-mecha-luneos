# Copyright (c) 2026, Herman van Hazendonk
# Released under the MIT license (see COPYING.MIT for the terms)
#
# NXP i.MX8M Plus: quad Cortex-A53, Vivante GC7000UL (etnaviv), GC520L 2D.
#
# There is no meta-freescale in this build and this file does not want one.
# Everything the SoC needs at boot is assembled by u-boot's own binman:
# bl31.bin from meta-arm's trusted-firmware-a, the four Synopsys DDR PHY
# training blobs from firmware-imx-ddr, and u-boot proper, all packed into a
# single flash.bin. See recipes-bsp/u-boot/u-boot-mecha_git.bb.

SOC_FAMILY ?= "imx8mp"

require conf/machine/include/soc-family.inc
require conf/machine/include/arm/armv8a/tune-cortexa53.inc

# meta-arm carries three trusted-firmware-a versions and meta-pine64-luneos
# carries a fourth recipe of the same name at 2.6 (a 2021 master revision with
# Allwinner patches). Name the one we mean rather than leaving it to version
# comparison across two layers.
PREFERRED_VERSION_trusted-firmware-a ?= "2.14.1"

# meta-arm's firmware.bbclass defaults TFA_PLATFORM to ${MACHINE}, which is a
# machine name, not a TF-A platform. Name the platform explicitly.
TFA_PLATFORM = "imx8mp"
TFA_BUILD_TARGET = "bl31"

# The boot ROM reads the image container from 32 KiB into the boot medium on
# SD and on the eMMC user area. The wks below reserves that offset.
IMX_BOOT_SEEK ?= "32"
