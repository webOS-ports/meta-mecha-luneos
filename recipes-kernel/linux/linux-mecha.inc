# Common definitions for the Mecha Comet kernels.
#
# Mecha maintains its own tree at github.com/mecha-org/linux. There is no
# mainline option here and will not be for a while: the panel
# (drm/panel DDIC_CH13726A), the touch controller (focaltech ft3519), the radio
# (nxpwifi, for the IW612 combo part) and the audio graph the Comet uses are all
# downstream. A mainline imx8mp.dtsi boots the SoC and gives you a dark screen.
#
# Branch choice - mecha-v7.1-wip, not the default fedora-mecha-7.1:
#
#   fedora-mecha-7.1 is Fedora's kernel packaging tree with Mecha's patches on
#   top. It carries redhat/, Makefile.rhelver, a .gitlab-ci.yml and Fedora's
#   config machinery, none of which Yocto's kernel classes know what to do with,
#   and its build is driven by redhat/ rather than by a defconfig. It exists so
#   that mecha-make can turn out kernel-core RPMs for their Fedora image.
#
#   mecha-v7.1-wip is the same 7.1 base and the same board support with none of
#   that: a plain kernel tree with arch/arm64/configs/mecha_v8_defconfig and
#   arch/arm64/boot/dts/freescale/imx8mp-mecha-comet.dts. That is what a Yocto
#   kernel recipe wants.
#
# Both branches are rebased and force-pushed, so a pinned SRCREV will eventually
# stop being reachable. Mirror the revision we pin the way meta-pine64-luneos
# does for megi's tree, and point MECHA_REPO at the mirror once it is pushed.

SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${S}/COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel
require recipes-kernel/linux/linux-yocto.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LINUX_VERSION ?= "7.1"
PV = "${LINUX_VERSION}-git"

# Mecha's branch does not always carry a matching EXTRAVERSION; do not let the
# sanity check fail the build over it. Same reasoning as linux-megi.inc.
KERNEL_VERSION_SANITY_SKIP = "1"

MECHA_BRANCH ?= "mecha-v7.1-wip"
MECHA_REPO ?= "git://github.com/mecha-org/linux.git;branch=${MECHA_BRANCH}"

# mecha-v7.1-wip tip as of 2026-09-17.
SRCREV_machine ?= "fd642caaca85d8fa8e9d2391cfb6f9fe38bfb4be"

# yocto-kernel-cache has no yocto-7.1 branch - it goes ..., 6.17, 6.18, 7.2 -
# so there is no exact match for a 7.1 kernel. yocto-7.2 is the nearest, and
# nothing here consumes its feature fragments anyway: the config comes from
# KBUILD_DEFCONFIG plus the .cfg files above, and the kmeta is only present
# because linux-yocto.inc expects one.
#
# Pinned to the same revision meta-pine64-luneos uses on purpose. It is the
# identical fetch, so all five LuneOS devices share one do_fetch/do_unpack
# sstate entry for it instead of each dragging down its own copy.
KMETA = "kernel-meta"
LINUX_KMETA_BRANCH ?= "yocto-7.2"
SRCREV_meta ?= "31a9aee38a2827fac9db03afde5bc9fe88b49957"

SRC_URI = " \
    ${MECHA_REPO};protocol=https;name=machine \
    git://git.yoctoproject.org/yocto-kernel-cache;protocol=https;type=kmeta;name=meta;branch=${LINUX_KMETA_BRANCH};destsuffix=${KMETA} \
    file://luneos-crypto.cfg \
    file://luneos-squashfs.cfg \
    file://luneos-waydroid-anbox.cfg \
"

# Unlike meta-pine64-luneos, this layer does NOT ship a copy of the defconfig.
#
# megi's tree has no defconfig for the Pine64 boards, so that layer has to carry
# one. Mecha's does - arch/arm64/configs/mecha_v8_defconfig - and it is the
# config their own images are built from, complete with DRM_PANEL_DDIC_CH13726A,
# DRM_ETNAVIV, NXPWIFI_SDIO and SND_SOC_MAX98090. Taking it from the tree means
# a board fix that comes with a config change arrives with the SRCREV bump
# instead of silently not arriving. The LuneOS-specific additions ride on top as
# the .cfg fragments above.
KBUILD_DEFCONFIG ?= "mecha_v8_defconfig"

# --alldefconfig is not optional here, and getting it wrong builds a kernel that
# looks fine and boots into nothing.
#
# mecha_v8_defconfig is a savedefconfig-style file: 1141 lines that list only
# the symbols differing from the Kconfig defaults. "make mecha_v8_defconfig"
# expands it by applying those defaults first.
#
# kernel-yocto does not do that. When it finds a defconfig it picks the baseline
# itself, and its rule is "a defconfig was passed, so use =n as the baseline",
# i.e. --allnoconfig, then merges the defconfig on top as a fragment. For a
# fully expanded defconfig - which is what meta-pine64-luneos ships, and why it
# never hit this - that is correct. For a minimal one it is not: every default-y
# symbol the file does not mention stays off.
#
# Measured on the first build of this recipe, with the baseline left at its
# default: 526 of the defconfig's 1133 symbols were missing from the final
# .config. CONFIG_BLOCK is not listed in mecha_v8_defconfig because it is
# default y, so it came out "# CONFIG_BLOCK is not set" - and with no block
# layer the dependency cascade took EXT4_FS, SQUASHFS, NXPWIFI and
# DRM_PANEL_DDIC_CH13726A with it. The kernel still compiled and still produced
# an Image and a .dtb.
#
# --alldefconfig makes the baseline the Kconfig defaults, which is what "make
# mecha_v8_defconfig" means, and the LuneOS .cfg fragments then merge on top.
KCONFIG_MODE = "--alldefconfig"

# kern-tools-native's bundled kconfiglib cannot parse the "depends on <sym> if
# <cond>" form that is upstream from 7.x on, so the config audit takes the build
# down on a tree this new. Same workaround, and the same reason, as
# meta-pine64-luneos/recipes-kernel/linux/linux-megi.inc.
KMETA_AUDIT = ""

# yaml and dtschema are required for device tree validation. libyaml is checked
# via pkgconfig so it must always be present.
DEPENDS += "gmp-native libmpc-native"
DEPENDS += "libyaml-native libyaml yaml-cpp python3-dtschema-wrapper-native"
