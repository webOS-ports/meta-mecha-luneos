# Copyright (c) 2026, Herman van Hazendonk
# Released under the MIT license (see COPYING.MIT for the terms)
#
# NXP i.MX95: hexa Cortex-A55, Mali-G310 (panfrost), eIQ Neutron NPU.
#
# The i.MX95 boots differently from every i.MX8M. There is no SPL doing DDR
# training from PHY blobs: an on-die System Manager (running on the Cortex-M33)
# brings up the SoC, and the boot container is built from the ELE firmware, the
# System Manager image, OEI/DDR images and TF-A. u-boot's imx95 binman node
# assembles that container, so the shape of the recipe is the same as on the
# 8M Plus even though the parts inside it are not.
#
# What this file cannot do is name the board. See comet-imx95.conf.

SOC_FAMILY ?= "imx95"

require conf/machine/include/soc-family.inc
require conf/machine/include/arm/armv8-2a/tune-cortexa55.inc

# meta-arm carries three TF-A versions and meta-pine64-luneos carries a fourth
# recipe of the same name at 2.6. Name the one we mean rather than letting
# version comparison across two layers decide it.
PREFERRED_VERSION_trusted-firmware-a ?= "2.14.1"

TFA_PLATFORM = "imx95"
TFA_BUILD_TARGET = "bl31"

IMX_BOOT_SEEK ?= "32"
