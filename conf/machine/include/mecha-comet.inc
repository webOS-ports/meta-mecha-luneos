# Copyright (c) 2026, Herman van Hazendonk
# Released under the MIT license (see COPYING.MIT for the terms)
#
# Everything the two Mecha Comet SoC variants have in common.
#
# The Comet is one product sold with a choice of SoC - an i.MX8M Plus board and
# an i.MX95 board - inside the same chassis, with the same panel, touch
# controller, radio, codec and PMIC family. So the split here is deliberate:
# this file holds the device, and imx8mp.inc / imx95.inc hold the silicon.
# A fix for the touchscreen or the speaker belongs here and lands on both.
#
# MACHINEOVERRIDES gives both machines a shared "mecha-comet" override, so a
# bbappend can say :mecha-comet instead of repeating itself per machine. It is
# prepended (=.) so the machine's own override still wins.

MACHINEOVERRIDES =. "mecha-comet:"

# Reuse the generic aarch64 packages rather than a tune that would rebuild Qt,
# WebEngine and the rest of the expensive half of the distro for one board.
# This is the same argument meta-pine64-luneos makes for the PineTab2 and the
# PinePhone Pro, and it is what lets all five devices share one sstate cache.
DEFAULTTUNE = "aarch64"

KERNEL_IMAGETYPE = "Image"

# The initramfs is built into the kernel image rather than loaded separately.
#
# The alternative - a standalone cpio.gz named from extlinux.conf - is what the
# PinePhone Pro does, and the comment above its INITRAMFS_IMAGE records what
# that costs: u-boot's image wrapper hides the gzip magic, the kernel discards
# the initramfs without failing the boot, and the device comes up with none of
# the setup init.sh was supposed to do. Bundling has no wrapper and no second
# file to keep in sync with the bootloader config.
INITRAMFS_IMAGE = "initramfs-simple-image"
INITRAMFS_IMAGE_BUNDLE = "1"

IMAGE_FSTYPES += "wic.gz wic.bmap"

SERIAL_CONSOLES = "115200;ttymxc1"

MACHINE_FEATURES = "alsa bluetooth rtc screen touchscreen usbgadget usbhost vfat ext2 ext3 wifi"

MACHINE_EXTRA_RRECOMMENDS += "kernel-modules"

MACHINE_EXTRA_RDEPENDS = " \
    kernel-modules \
    \
    firmware-nxp-wifi \
    \
    qtsensors-sensorfw-plugin \
    sensorfw \
    \
    libcamera \
    libcamera-gst \
"

# Boot-time hardware state dump - see meta-pine64-luneos/recipes-support/luneos-diag
MACHINE_EXTRA_RRECOMMENDS += "luneos-diag"
