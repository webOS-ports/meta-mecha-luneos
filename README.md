LuneOS Mecha layer
==================

This layer builds LuneOS for the [Mecha Comet](https://mecha.so/comet), a
modular Linux handheld. It is laid out the same way as `meta-pine64-luneos`:
one layer, one machine per board, everything the boards share in a common
include.

Source: <https://github.com/mecha-org> (kernel, u-boot, and Mecha's own
`mecha-make` image build system).

## Machines

| MACHINE | SoC | Status |
| --- | --- | --- |
| `comet-imx8mp` | NXP i.MX8M Plus, 4x Cortex-A53, Vivante GC7000UL | Builds |
| `comet-imx95` | NXP i.MX95, 6x Cortex-A55, Mali-G310 | Blocked, see below |

### The i.MX95 variant

Mecha sells the Comet with a choice of two SoCs, but has published board support
for only one of them. Checked on 2026-09-17 across every branch of both repos:

* `mecha-org/linux` (`fedora-mecha-7.1`, `fedora-mecha-7.2`, `mecha-v7.0-wip`,
  `mecha-v7.1-wip`, `imx/lf-6.12.20`, `imx-6.12.20-rev6`) carries
  `imx8mp-mecha-comet.dts` and, on the rev6 branch,
  `imx8mp-mecha-comet-m-gen6.dts`. There is no `imx95-mecha-comet.dts` on any
  branch; the only i.MX95 device trees present are NXP's own EVK/FRDM boards and
  third-party SoMs.
* `mecha-org/u-boot` (`v2026.07-mecha`, `v2026.04-mecha`, `imx/lf_v2025.04`) has
  `board/mecha/comet` with an 8M Plus SPL, three LPDDR4 timing tables and
  `mecha-comet-imx8mp-{2,4,8}gb_defconfig`. No i.MX95 defconfig or board dir.
* `mecha-org/mecha-make` builds `freescale/imx8mp-mecha-comet.dtb` and has one
  hardware profile, `comet`.

So `comet-imx95` is complete on the LuneOS side and refuses to parse until the
board exists. `conf/machine/comet-imx95.conf` documents exactly what to fill in.
Everything above the SoC - the panel, touch, radio, codec, sensors, graphics -
is in `conf/machine/include/mecha-comet.inc` and already applies to both.

## Hardware

The Comet is a downstream-kernel device. Mainline boots the SoC and gives you a
dark screen; the parts that matter are all out of tree:

| | |
| --- | --- |
| Panel | 3.91" MIPI DSI, `ch13726a,rp5` (`CONFIG_DRM_PANEL_DDIC_CH13726A`) |
| Touch | Focaltech FT3519 |
| GPU | Vivante GC7000UL via **etnaviv** - no `imx-gpu-viv`, no meta-freescale |
| Wi-Fi/BT | NXP IW612 combo, `nxpwifi_sdio` + `nxp,88w8987-bt` |
| Audio | MAX98090 codec on SAI3, plus HDMI audio |
| PMIC | PCA9450C |
| Storage | eMMC, microSD, NVMe over PCIe |

## The boot chain

There is no `meta-freescale` in this build and none is needed. u-boot's own
binman assembles the whole container:

```
flash.bin
├── lpddr4_pmu_train_{1d,2d}_{imem,dmem}_202006.bin   firmware-imx-ddr (NXP EULA)
├── SPL                                               mecha-org/u-boot
├── bl31.bin                                          meta-arm trusted-firmware-a
└── u-boot proper                                     mecha-org/u-boot
```

OP-TEE is off. Mecha's defconfigs enable it, which makes binman demand a
`tee.bin`; see `recipes-bsp/u-boot/u-boot-mecha/luneos-no-optee.cfg` for the
reasoning and for how to turn it back on.

The DDR training blobs are behind NXP's EULA, so a build needs this in
`conf/local.conf`:

```
LICENSE_FLAGS_ACCEPTED += "imx-firmware"
```

### DDR variants

`board/mecha/comet` has three LPDDR4 timing tables and the SPL does not detect
which one it needs, so u-boot is built once per size (`UBOOT_CONFIG = "2gb 4gb
8gb"`) and all three land in `DEPLOY_DIR_IMAGE` as `flash.bin-<size>`. The
`.wic` carries the one named by `COMET_DDR_VARIANT` (default `8gb`). On a
different Comet, either rebuild with

```
COMET_DDR_VARIANT = "4gb"
```

or write the right container over the existing one:

```
dd if=flash.bin-4gb of=/dev/sdX bs=1K seek=32 conv=fsync
```

## Building

```
MACHINE=comet-imx8mp bitbake luneos-dev-image
```

## Installing

`scripts/flash-comet.sh` covers the four ways onto the hardware. It finds the
deploy directory relative to itself, so it usually needs no arguments beyond the
target.

```
scripts/flash-comet.sh list                    # what is available to flash
scripts/flash-comet.sh sd /dev/sdX             # full image to a microSD
scripts/flash-comet.sh emmc                    # full image to eMMC, over fastboot
scripts/flash-comet.sh bootloader /dev/sdX     # only flash.bin, to an SD
scripts/flash-comet.sh bootloader-emmc         # only flash.bin, to the eMMC boot partition
scripts/flash-comet.sh uuu                     # blank/bricked board, over USB SDP
```

`-r 2gb|4gb|8gb` picks the DDR variant of `flash.bin` (default `8gb`) and has to
match the RAM actually fitted - see the DDR variants section above.

**Getting into fastboot** takes no button press on a board with an empty eMMC:
`bsp_bootcmd` tries to load a kernel and calls `fastboot 0` when it cannot, so it
is already waiting. On a board that does boot, interrupt u-boot on the serial
console (115200 8N1, `ttymxc1`) and run `fastboot 0`.

The `sd` and `bootloader` paths refuse to write to anything that holds `/`,
`/home` or `/boot`, to a partition rather than a whole disk, to a device with
something mounted on it, or to a non-removable disk without `--allow-internal` -
`sd /dev/sda` is how people erase their laptop. They also ask you to type the
device name back before erasing it; `-y` skips that.

`sd` uses `bmaptool` when it and the `.bmap` are present, which skips the
unallocated part of the image and is much faster than `dd`.

## Making a release archive

```
scripts/make-release.sh                 # -> luneos-comet-imx8mp-<build id>.tar.gz
scripts/make-release.sh -z -o /srv/dl   # zstd, written somewhere else
```

The archive is self-contained - the image, all three `flash.bin` variants,
`flash-comet.sh`, `SHA256SUMS` and a standalone README that assumes no Yocto on
the receiving machine. `flash-comet.sh` looks for an `images/` directory beside
itself before it looks for a build tree, which is what lets the same script serve
both cases.

## Status

Not yet booted on hardware. What has been built and verified on this tree:

* `firmware-imx-ddr` fetches and EULA-unpacks, deploying all four LPDDR4 PHY
  training blobs.
* `trusted-firmware-a` 2.14.1 builds `bl31.bin` for `PLAT=imx8mp`.
* `u-boot-mecha` builds all three DDR variants. Each `flash.bin` is ~1.63 MB,
  carries the i.MX image-vector-table header (`d1002041`), and the three differ
  from each other, so the per-variant timing tables really are taking effect.
* `linux-comet` builds `Image`, the bundled-initramfs `Image`, and
  `imx8mp-mecha-comet.dtb`.
* `MACHINE=comet-imx8mp bitbake -n luneos-dev-image` resolves the full 12173-task
  graph with no errors.
* `MACHINE=pinephonepro` still resolves and still selects the Pine64 layer's
  TF-A 2.6, so nothing here changed the existing boards.

Everything downstream of that - display bring-up, touch orientation, the radio,
audio routing, suspend - is untested and should be expected to need work, in
roughly that order. The things most likely to be wrong first:

* **Touch/display rotation.** The panel is 1080x1240 and the device tree leaves
  `rotation` commented out. Fix with `deviceinfo_compositor_geometry` in a
  `luneos-device-config` adaptation; that one declaration rotates evdevtouch too.
* **GridUnit.** 28 is DPI-scaled from the PinePhone's 19, not measured.
* **Sensor orientation.** `sensord-comet-imx8mp.conf` deliberately ships no
  `transformation_matrix`; see the note in that file.
* **The i.MX95 console** in `comet-imx95-boot.conf` is a guess, as is that
  machine's raw-partition size.
