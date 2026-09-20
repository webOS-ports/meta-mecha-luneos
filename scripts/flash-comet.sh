#!/bin/sh
# Write LuneOS to a Mecha Comet.
#
# Copyright (c) 2026, Herman van Hazendonk
# Released under the MIT license (see COPYING.MIT for the terms)
#
# Four ways in, in the order you are likely to need them:
#
#   sd <device>       full image to a microSD in a card reader
#   emmc              full image to the internal eMMC, over fastboot
#   bootloader <dev>  just flash.bin, to an SD already carrying an image
#   bootloader-emmc   just flash.bin, to the eMMC boot partition over fastboot
#   uuu               a Comet whose eMMC is blank or bricked, over USB SDP
#
# POSIX sh on purpose: this gets run from a rescue shell often enough that
# depending on bash is not worth it.

set -eu

MACHINE=${MACHINE:-comet-imx8mp}
RAM=8gb
DEPLOY=
IMAGE=
ASSUME_YES=0
ALLOW_INTERNAL=0

PROG=$(basename "$0")

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

usage() {
    cat <<EOF
Usage: $PROG [options] <command> [args]

Commands:
  sd <device>          Write the full image to a removable device (e.g. /dev/sdb).
  emmc                 Write the full image to the Comet's eMMC over fastboot.
  bootloader <device>  Write only flash.bin to a removable device, at 32 KiB.
  bootloader-emmc      Write only flash.bin to the eMMC boot partition (fastboot).
  uuu                  Boot flash.bin over USB SDP and provision eMMC (blank board).
  list                 Show what is available to flash.

Options:
  -d, --deploy DIR   DEPLOY_DIR_IMAGE. Default: auto-detected from this script's
                     location, else \$DEPLOY_DIR_IMAGE.
  -M, --machine M    Machine name. Default: $MACHINE
  -r, --ram SIZE     DDR variant of flash.bin: 2gb, 4gb or 8gb. Default: $RAM
                     This must match the RAM actually fitted - see README.md.
  -i, --image FILE   Use this .wic/.wic.gz instead of the deploy dir's.
  -y, --yes          Do not ask for confirmation. Be careful.
      --allow-internal
                     Permit writing to a non-removable disk. Off by default,
                     because "sd /dev/sda" is how people erase their laptop.
  -h, --help         This text.

Getting the Comet into fastboot:
  It does it itself. bsp_bootcmd tries to load a kernel from mmc \${mmcdev} and
  calls "fastboot 0" when it cannot, so a board with an empty eMMC is already
  waiting. On a board that does boot, interrupt u-boot on the serial console
  (115200 8N1 on ttymxc1) and run: fastboot 0
EOF
}

# ---------------------------------------------------------------- deploy dir

# Where the artifacts are. This script is used two ways - from the layer in a
# build tree, and unpacked from a release archive on a machine with no Yocto on
# it at all - so it looks for both layouts.
find_deploy() {
    [ -n "$DEPLOY" ] && { printf '%s' "$DEPLOY"; return; }
    [ -n "${DEPLOY_DIR_IMAGE:-}" ] && { printf '%s' "$DEPLOY_DIR_IMAGE"; return; }

    _here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

    # Release archive: images/ sits next to the script, or the script sits in
    # amongst the images.
    for _c in "$_here/images" "$_here"; do
        for _f in "$_c"/*.wic.gz "$_c"/*.wic "$_c"/flash.bin-*; do
            [ -e "$_f" ] || continue
            (CDPATH= cd -- "$_c" && pwd)
            return
        done
    done

    # Build tree: <build>/meta-mecha-luneos/scripts/ -> <build>/tmp/deploy/images/<machine>
    _guess="$_here/../../tmp/deploy/images/$MACHINE"
    [ -d "$_guess" ] && { (CDPATH= cd -- "$_guess" && pwd); return; }

    die "cannot find the images; pass -d or set DEPLOY_DIR_IMAGE"
}

find_image() {
    [ -n "$IMAGE" ] && { printf '%s' "$IMAGE"; return; }
    _d=$1
    # Newest first: a rebuild should win over yesterday's leftovers. The link
    # names differ across oe-core versions (.rootfs.wic.gz appeared in
    # scarthgap), so glob rather than hard-code.
    for _p in "$_d"/*.wic.gz "$_d"/*.wic; do
        [ -e "$_p" ] || continue
        printf '%s' "$_p"
        return
    done
    die "no .wic or .wic.gz in $_d - build the image first:
    MACHINE=$MACHINE bitbake luneos-dev-image"
}

find_bootloader() {
    _d=$1
    for _p in "$_d/flash.bin-$RAM" "$_d/flash-$RAM"*.bin; do
        [ -e "$_p" ] && { printf '%s' "$_p"; return; }
    done
    die "no flash.bin for the $RAM variant in $_d (looked for flash.bin-$RAM)"
}

# ---------------------------------------------------------------- safety

# The disk backing a given mount point, e.g. /dev/nvme0n1 for /.
disk_of_mount() {
    _src=$(findmnt -n -o SOURCE --target "$1" 2>/dev/null) || return 0
    lsblk -n -o PKNAME "$_src" 2>/dev/null | head -1
}

check_target() {
    _dev=$1
    [ -b "$_dev" ] || die "$_dev is not a block device"

    # A partition, not the whole disk. Ask lsblk for the parent rather than
    # trimming digits off the name: "${_dev%%[0-9]*}" turns /dev/nvme1n1p2 into
    # /dev/nvme, which is not a device and sends people looking for one.
    _parent=$(lsblk -ndo PKNAME "$_dev" 2>/dev/null || true)
    [ -n "$_parent" ] && die "$_dev is a partition; give the whole disk (/dev/$_parent)"

    _name=$(basename "$_dev")
    _removable=$(cat "/sys/block/$_name/removable" 2>/dev/null || echo 0)
    _model=$(cat "/sys/block/$_name/device/model" 2>/dev/null || echo "?")
    _size=$(lsblk -bdn -o SIZE "$_dev" 2>/dev/null || echo 0)
    _hsize=$(lsblk -dn -o SIZE "$_dev" 2>/dev/null || echo "?")

    # Never the disk this system is running from, whatever the flags say.
    for _m in / /home /boot; do
        _sysdisk=$(disk_of_mount "$_m")
        [ -n "$_sysdisk" ] && [ "$_sysdisk" = "$_name" ] && \
            die "$_dev holds $_m on this machine - refusing"
    done

    if [ "$_removable" != "1" ] && [ "$ALLOW_INTERNAL" != "1" ]; then
        die "$_dev is not a removable device (model: $_model, size: $_hsize).
Pass --allow-internal if you are certain this is the card reader."
    fi

    # A mounted partition means the card is in use; writing under a mounted
    # filesystem corrupts both it and the image.
    if lsblk -nlo MOUNTPOINT "$_dev" 2>/dev/null | grep -q .; then
        say "$_dev has mounted partitions:"
        lsblk -o NAME,SIZE,MOUNTPOINT "$_dev"
        die "unmount them first (udisksctl unmount -b ${_dev}1, or umount)"
    fi

    say "Target: $_dev  ($_model, $_hsize, removable=$_removable)"
    if [ "$_size" -lt 3500000000 ] 2>/dev/null; then
        say "NOTE: this looks smaller than 4 GB; the image may not fit."
    fi

    # Explicit, and not decoration. Under "set -e" the function's exit status is
    # the last command's, so ending on a test that is false for every normally
    # sized card - which is the common case - aborted the whole script right
    # after printing "Target:", before writing anything.
    return 0
}

confirm() {
    [ "$ASSUME_YES" = "1" ] && return 0
    printf 'Type the device name to confirm erasing it (%s): ' "$1"
    read -r _answer
    [ "$_answer" = "$1" ] || die "aborted"
}

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

# fastboot and uuu both need a raw .wic; the build produces .wic.gz.
#
# Decompress into a scratch directory rather than beside the image: the deploy
# directory is bitbake's, and on a typical setup it sits on the build disk,
# which is the one most likely to be nearly full. TMPDIR wins if set, else
# /var/tmp - not /tmp, which is frequently a tmpfs sized well under an image.
SCRATCH=
# Same "set -e" trap as check_target: an EXIT handler whose last command is a
# false test would replace a clean exit status with 1.
cleanup() { [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"; return 0; }
trap cleanup EXIT INT TERM

# Sets RAW, rather than printing the path for $( ) to capture.
#
# A command substitution runs in a subshell, so an assignment to SCRATCH inside
# one would never reach the parent - the EXIT trap above would have nothing to
# clean up, and in shells that do run EXIT traps on subshell exit it would
# delete the decompressed image before fastboot ever opened it.
RAW=
raw_image() {
    case "$1" in
        *.gz) ;;
        *) RAW=$1; return ;;
    esac
    _base=$(basename "${1%.gz}")
    SCRATCH=$(mktemp -d "${TMPDIR:-/var/tmp}/flash-comet.XXXXXX") \
        || die "cannot create a scratch directory"
    say "Decompressing to $SCRATCH/$_base ..."
    gunzip -c "$1" > "$SCRATCH/$_base" \
        || die "decompression failed (out of space in ${TMPDIR:-/var/tmp}?)"
    RAW=$SCRATCH/$_base
}

# ---------------------------------------------------------------- commands

cmd_list() {
    _d=$(find_deploy)
    say "Deploy directory: $_d"
    say ""
    say "Images:"
    ls -lh "$_d"/*.wic.gz "$_d"/*.wic 2>/dev/null | sed 's/^/  /' || say "  (none - build luneos-dev-image)"
    say ""
    say "Bootloaders (flash.bin, one per DDR size):"
    ls -lh "$_d"/flash.bin-* 2>/dev/null | sed 's/^/  /' || say "  (none - build u-boot-mecha)"
}

cmd_sd() {
    _dev=${1:-}
    [ -n "$_dev" ] || die "which device? e.g. $PROG sd /dev/sdb"

    # Validate the device before looking for an image. The other order means a
    # missing image masks "you passed your root disk", which is the error that
    # actually matters.
    check_target "$_dev"

    _d=$(find_deploy)
    _img=$(find_image "$_d")
    say "Image:  $_img"
    confirm "$_dev"

    # bmaptool skips the unallocated parts of the image, which on a sparse
    # rootfs is most of it. Only usable when the matching .bmap is present and
    # actually corresponds to this image.
    _bmap=$(printf '%s' "$_img" | sed -e 's/\.wic\.gz$/.wic.bmap/' -e 's/\.wic$/.wic.bmap/')
    if command -v bmaptool >/dev/null 2>&1 && [ -f "$_bmap" ]; then
        say "Writing with bmaptool (using $_bmap)..."
        bmaptool copy --bmap "$_bmap" "$_img" "$_dev"
    else
        say "Writing with dd (no bmaptool/.bmap; this is slower)..."
        case "$_img" in
            *.gz) gunzip -c "$_img" | dd of="$_dev" bs=4M conv=fsync status=progress ;;
            *)    dd if="$_img" of="$_dev" bs=4M conv=fsync status=progress ;;
        esac
    fi
    sync
    say "Done. Put the card in the Comet and power on."
}

cmd_bootloader() {
    _dev=${1:-}
    [ -n "$_dev" ] || die "which device? e.g. $PROG bootloader /dev/sdb"

    # Device first - see the note in cmd_sd.
    check_target "$_dev"

    _d=$(find_deploy)
    _fb=$(find_bootloader "$_d")
    say "Bootloader: $_fb  ($RAM)"
    say "Written at 32 KiB, which is where the i.MX8M boot ROM looks on SD and"
    say "on the eMMC user area. The partition table and the rootfs are untouched."
    confirm "$_dev"

    dd if="$_fb" of="$_dev" bs=1K seek=32 conv=fsync status=progress
    sync
    say "Done."
}

cmd_emmc() {
    need fastboot
    _d=$(find_deploy)
    _img=$(find_image "$_d")

    say "Waiting for a Comet in fastboot mode..."
    fastboot devices
    say ""
    say "Image: $_img"
    say "This overwrites the whole eMMC user area (fastboot alias 'all' -> mmc 2:0)."
    if [ "$ASSUME_YES" != "1" ]; then
        printf 'Type ERASE to continue: '
        read -r _answer
        [ "$_answer" = "ERASE" ] || die "aborted"
    fi

    raw_image "$_img"; _raw=$RAW

    # The host tool splits this into sparse chunks by itself, using the
    # max-download-size u-boot advertises (FASTBOOT_BUF_SIZE, 1 GiB here), so a
    # multi-gigabyte image is fine.
    fastboot flash all "$_raw"
    say "Done. 'fastboot reboot' to start it."
}

cmd_bootloader_emmc() {
    need fastboot
    _d=$(find_deploy)
    _fb=$(find_bootloader "$_d")

    say "Bootloader: $_fb  ($RAM)"
    say "Target: eMMC boot partition (fastboot alias 'bootloader' -> mmc 2.1)."
    say "u-boot places it at the offset the ROM expects for a boot partition,"
    say "which is not the same as the 32 KiB used on SD - let it do that."
    if [ "$ASSUME_YES" != "1" ]; then
        printf 'Continue? [y/N] '
        read -r _answer
        case "$_answer" in y|Y|yes) ;; *) die "aborted" ;; esac
    fi

    fastboot flash bootloader "$_fb"
    say "Done."
}

cmd_uuu() {
    need uuu
    _d=$(find_deploy)
    _fb=$(find_bootloader "$_d")
    _img=$(find_image "$_d")

    raw_image "$_img"; _raw=$RAW

    say "This is the recovery path for a Comet that cannot boot at all."
    say "Put it in serial-download mode first (hold the boot/recovery button"
    say "while applying power), then plug in USB-C. 'uuu -lsusb' should list it."
    say ""
    say "Bootloader: $_fb"
    say "Image:      $_raw"
    if [ "$ASSUME_YES" != "1" ]; then
        printf 'Type ERASE to continue: '
        read -r _answer
        [ "$_answer" = "ERASE" ] || die "aborted"
    fi

    # emmc_all is uuu's built-in script: load flash.bin over SDP, run it, then
    # hand the whole image to the fastboot it brings up.
    uuu -b emmc_all "$_fb" "$_raw"
    say "Done."
}

# ---------------------------------------------------------------- arguments

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--deploy)  DEPLOY=${2:?missing dir}; shift 2 ;;
        -M|--machine) MACHINE=${2:?missing machine}; shift 2 ;;
        -r|--ram)     RAM=${2:?missing size}; shift 2 ;;
        -i|--image)   IMAGE=${2:?missing file}; shift 2 ;;
        -y|--yes)     ASSUME_YES=1; shift ;;
        --allow-internal) ALLOW_INTERNAL=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *) break ;;
    esac
done

case "$RAM" in
    2gb|4gb|8gb) ;;
    *) die "--ram must be 2gb, 4gb or 8gb (got: $RAM)" ;;
esac

[ $# -ge 1 ] || { usage; exit 1; }
CMD=$1; shift

case "$CMD" in
    sd)              cmd_sd "$@" ;;
    emmc)            cmd_emmc "$@" ;;
    bootloader)      cmd_bootloader "$@" ;;
    bootloader-emmc) cmd_bootloader_emmc "$@" ;;
    uuu)             cmd_uuu "$@" ;;
    list)            cmd_list "$@" ;;
    *) die "unknown command: $CMD (try --help)" ;;
esac
