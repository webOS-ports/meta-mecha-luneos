#!/bin/sh
# Bundle a Mecha Comet build into one archive somebody else can flash.
#
# Copyright (c) 2026, Herman van Hazendonk
# Released under the MIT license (see COPYING.MIT for the terms)
#
# The result is self-contained: the image, every DDR variant of the bootloader,
# the flashing script and instructions that do not assume Yocto. flash-comet.sh
# finds images/ next to itself, so the archive works with nothing installed but
# the usual host tools.

set -eu

MACHINE=${MACHINE:-comet-imx8mp}
DEPLOY=
OUTDIR=
NAME=
COMPRESS=gz

PROG=$(basename "$0")
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

usage() {
    cat <<EOF
Usage: $PROG [options]

Options:
  -d, --deploy DIR   DEPLOY_DIR_IMAGE. Default: <build>/tmp/deploy/images/\$MACHINE
  -M, --machine M    Default: $MACHINE
  -o, --outdir DIR   Where to write the archive. Default: current directory.
  -n, --name NAME    Archive basename. Default: luneos-<machine>-<build id>
  -z, --zstd         Compress with zstd instead of gzip.
  -h, --help         This text.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--deploy)  DEPLOY=${2:?}; shift 2 ;;
        -M|--machine) MACHINE=${2:?}; shift 2 ;;
        -o|--outdir)  OUTDIR=${2:?}; shift 2 ;;
        -n|--name)    NAME=${2:?}; shift 2 ;;
        -z|--zstd)    COMPRESS=zstd; shift ;;
        -h|--help)    usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

[ -n "$DEPLOY" ] || DEPLOY="$HERE/../../tmp/deploy/images/$MACHINE"
[ -d "$DEPLOY" ] || die "no such deploy directory: $DEPLOY"
DEPLOY=$(CDPATH= cd -- "$DEPLOY" && pwd)
OUTDIR=${OUTDIR:-$(pwd)}
mkdir -p "$OUTDIR"

# --- locate the pieces -----------------------------------------------------

IMG=
for _p in "$DEPLOY"/*.wic.gz; do [ -e "$_p" ] && { IMG=$_p; break; }; done
[ -n "$IMG" ] || for _p in "$DEPLOY"/*.wic; do [ -e "$_p" ] && { IMG=$_p; break; }; done
[ -n "$IMG" ] || die "no .wic/.wic.gz in $DEPLOY - build the image first"

# Resolve the convenience symlink to the real file, so the archive carries a
# name that says which build it is rather than a generic one.
IMG=$(readlink -f "$IMG")

BOOTLOADERS=
for _r in 2gb 4gb 8gb; do
    _f="$DEPLOY/flash.bin-$_r"
    [ -e "$_f" ] && BOOTLOADERS="$BOOTLOADERS $_r"
done
[ -n "$BOOTLOADERS" ] || die "no flash.bin-* in $DEPLOY - build u-boot-mecha first"

# Name the archive after the build, falling back to today.
if [ -z "$NAME" ]; then
    _id=$(basename "$IMG" | sed -nE 's/.*-([0-9]{8,14})\..*/\1/p')
    [ -n "$_id" ] || _id=$(date -u +%Y%m%d)
    NAME="luneos-$MACHINE-$_id"
fi

STAGE=$(mktemp -d "${TMPDIR:-/var/tmp}/mkrelease.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT INT TERM
ROOT="$STAGE/$NAME"
mkdir -p "$ROOT/images"

say "Staging $NAME ..."

cp -L "$IMG" "$ROOT/images/"
_bmap=$(printf '%s' "$IMG" | sed -e 's/\.wic\.gz$/.wic.bmap/' -e 's/\.wic$/.wic.bmap/')
[ -f "$_bmap" ] && cp -L "$_bmap" "$ROOT/images/"

for _r in $BOOTLOADERS; do
    cp -L "$DEPLOY/flash.bin-$_r" "$ROOT/images/flash.bin-$_r"
done

cp "$HERE/flash-comet.sh" "$ROOT/"
chmod +x "$ROOT/flash-comet.sh"

# --- standalone instructions ----------------------------------------------

_imgname=$(basename "$IMG")
cat > "$ROOT/README.md" <<EOF
# LuneOS for the Mecha Comet (i.MX8M Plus)

Build: \`$_imgname\`
Machine: \`$MACHINE\`
Packaged: $(date -u '+%Y-%m-%d %H:%M UTC')

## What is in here

    flash-comet.sh     the installer
    images/            the image and the bootloaders
    SHA256SUMS         checksums for everything in images/

## Which bootloader

\`images/\` carries one \`flash.bin\` per memory size, because the Comet's SPL has
no run-time DDR detection - the LPDDR4 training table is chosen at build time
and the wrong one will not train. Pass the size fitted to your board:

    -r 2gb | -r 4gb | -r 8gb        (default: 8gb)

The image itself is identical for all three; only the bootloader differs.

## Installing

Onto a microSD in a card reader:

    ./flash-comet.sh -r 8gb sd /dev/sdX

Onto the internal eMMC, over fastboot:

    ./flash-comet.sh -r 8gb emmc

A board with an empty eMMC is already in fastboot - u-boot's \`bsp_bootcmd\`
tries to load a kernel and calls \`fastboot 0\` when it cannot. On a board that
does boot, interrupt u-boot on the serial console (115200 8N1, \`ttymxc1\`) and
run \`fastboot 0\`.

Just the bootloader, leaving the rootfs alone:

    ./flash-comet.sh -r 8gb bootloader /dev/sdX      # SD, written at 32 KiB
    ./flash-comet.sh -r 8gb bootloader-emmc          # eMMC boot partition

A board that will not boot at all, over USB serial download (needs NXP's \`uuu\`):

    ./flash-comet.sh -r 8gb uuu

\`./flash-comet.sh --help\` lists everything.

## Before you run it

The SD paths refuse to write to a disk holding \`/\`, \`/home\` or \`/boot\`, to a
partition instead of a whole disk, to a device with anything mounted on it, or
to a non-removable disk without \`--allow-internal\`. You are asked to type the
device name back before it erases anything. None of that is a substitute for
checking \`lsblk\` first.

Optional but worth having: \`bmaptool\` (much faster SD writes, uses the .bmap),
\`android-tools\`/\`fastboot\` for the eMMC paths, and \`uuu\` for recovery.

## Verifying

    cd images && sha256sum -c ../SHA256SUMS

## Status

This is an early port. It builds and the boot chain is assembled correctly, but
it has not been through a full bring-up on hardware - expect display, touch
orientation, radio and audio to need work. Report what you find.
EOF

( cd "$ROOT/images" && sha256sum ./* > "$ROOT/SHA256SUMS" )

# --- pack ------------------------------------------------------------------

case "$COMPRESS" in
    zstd) need_ext=tar.zst; tar -C "$STAGE" -c "$NAME" | zstd -19 -T0 -o "$OUTDIR/$NAME.tar.zst" -f ;;
    *)    need_ext=tar.gz;  tar -C "$STAGE" -czf "$OUTDIR/$NAME.tar.gz" "$NAME" ;;
esac

ARCHIVE="$OUTDIR/$NAME.$need_ext"
( cd "$OUTDIR" && sha256sum "$NAME.$need_ext" > "$NAME.$need_ext.sha256" )

say ""
say "Archive:  $ARCHIVE"
say "Size:     $(du -h "$ARCHIVE" | cut -f1)"
say "Checksum: $ARCHIVE.sha256"
say ""
say "Contents:"
tar -tf "$ARCHIVE" | sed 's/^/  /'
