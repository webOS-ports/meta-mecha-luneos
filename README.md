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

### How large the bundled kernel may get

`INITRAMFS_IMAGE_BUNDLE` puts the initramfs inside `Image`, and u-boot loads
that at `CONFIG_SYS_LOAD_ADDR` 0x40400000 while `fdt_addr_r` is 0x43000000, so
there are 0x2C00000 - 46,137,344 bytes - between the two. Nothing checks this:
a bundled `Image` that crosses 0x43000000 overwrites the device tree u-boot
already loaded, and what you get is a kernel that does not print a line.

Measured on 2026-10-13:

```
Image              28,678,656
Image-initramfs    43,686,400   -> 2,450,944 bytes (2.34 MiB) spare
```

Building the display path in costs 925,696 of those bytes and still fits; see
the note in `recipes-kernel/linux/linux-comet/extra.cfg` for why it is not.

Check it after anything that grows the kernel or the initramfs:

```
echo $(( 0x43000000 - 0x40400000 - $(stat -Lc %s tmp/deploy/images/comet-imx8mp/Image-initramfs-comet-imx8mp.bin) ))
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

### A board that has run Mecha's own OS keeps its u-boot environment

`CONFIG_ENV_IS_IN_MMC` with `CONFIG_ENV_MMC_DEVICE_INDEX=2` puts the saved
environment in the eMMC raw area, at `CONFIG_ENV_OFFSET` 0x700000 and
`CONFIG_ENV_OFFSET_REDUND` 0x20400 - on the eMMC whether the board boots from
eMMC or from SD. Nothing in a `.wic` written to a microSD touches it, so an
environment saved while the board ran Mecha's distribution survives installing
LuneOS, and it wins: `CONFIG_BOOTCOMMAND` is

```
run sr_ir_v2_cmd; bootflow scan -lb; run bsp_bootcmd
```

and `bsp_bootcmd` loads `/Image` and `${fdtfile}` off `mmc ${mmcdev}:1` - the
same files, out of the same `/boot` - but builds `bootargs` from `mmcargs`
rather than from the `append` line in `extlinux/extlinux.conf`. The result is
LuneOS's kernel booted with the vendor's command line, which is easy to miss
because everything loads and boots.

Check it from the running system and compare against what this layer installs
(`files/wic/comet-imx8mp-boot.conf`):

```
cat /proc/cmdline
```

Two of Mecha's arguments stop LuneOS working if they are inherited:

* `module_blacklist=imx_lcdif` leaves the i.MX8MP LCDIFv3 unbound, so there is
  no CRTC and no KMS device - `/sys/class/drm` holds only etnaviv's `card0`,
  there is no `card0-DSI-1` and no `/dev/fb0`, and the compositor has nothing
  to start on even though `samsung-dsim` and `panel-chipwealth-ch13726a` both
  loaded and attached.
* `rdinit=/nonexistent` makes the kernel skip the bundled initramfs
  (`check access for rdinit=/nonexistent failed: -2, ignoring`) and mount
  `root=` directly, which bypasses LuneOS's initramfs entirely.

Clear the inherited environment once, on the serial console:

```
=> env default -a
=> saveenv
=> reset
```

After that `bootflow scan` finds `extlinux/extlinux.conf` and the `append` line
in this layer is what reaches the kernel. To try it without saving anything
first, set the one variable `bsp_bootcmd` uses and boot by hand:

```
=> setenv mmcroot '/dev/mmcblk2p2 rootwait rw'
=> run bsp_bootcmd
```

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

Boots to userspace on an imx8mp Comet; the display is not up yet. What has been
built and verified on this tree:

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

Observed on hardware on 2026-10-12, kernel 7.2.4-comet-gbdac75651c25:
systemd, ls-hubd, nyx and db8 all come up and a root login on `ttymxc1` works,
`samsung-dsim` attaches `panel-chipwealth-ch13726a` ("Attached comet device
(lanes:4 bpp:24 mode-flags:0x401)"), and `etnaviv` binds. There is no KMS
device, because that boot had `module_blacklist=imx_lcdif` on its command line.

### Why imx_lcdif is blacklisted

Not an accident and not ours. Reported by the tester on 2026-10-13: whenever the
LCDIF driver binds, powering up the display block raises an asynchronous SError
inside the i.MX interconnect code, the kernel panics, and the board hangs until
the watchdog resets it - so it never reaches a login prompt. Reproduces on
7.1.0 and on 7.2.4. The blacklist is the workaround that makes the board usable,
and it is the reason the display path is kept modular rather than built in; see
the note in `recipes-kernel/linux/linux-comet/extra.cfg`.

Where to look first, in order of how cheap the experiment is. `lcdif1`'s power
domain is the only one in `fsl,imx8mp-media-blk-ctrl` with interconnect paths
(`path_names` "lcdif-rd", "lcdif-wr" in `imx8m-blk-ctrl.c`), and
`imx8m_blk_ctrl_power_on` calls `icc_bulk_set_bw` immediately after releasing
the block's reset. That lands in `imx_icc_node_set`, which does a bare `writel`
to the main NoC at `interconnect@32700000` + 0x980 and + 0xa00 with no clock or
power handshake of its own - the only register write in that sequence that is
outside the mediamix. So:

1. Delete `interconnects` and `interconnect-names` from `blk-ctrl@32ec0000`.
   `of_icc_get()` returns NULL rather than an error when the `interconnects`
   property is absent, so the two paths become no-ops and nothing else changes;
   the HDMI, GPU and VPU blocks keep theirs. This needs no kernel rebuild at
   all - patch the deployed dtb in place and drop it on /boot:

   ```
   fdtput -d imx8mp-mecha-comet.dtb /soc@0/bus@32c00000/blk-ctrl@32ec0000 interconnects
   fdtput -d imx8mp-mecha-comet.dtb /soc@0/bus@32c00000/blk-ctrl@32ec0000 interconnect-names
   ```

2. Match the configuration that demonstrably works on this hardware. Mecha's
   own kernel is configured from `redhat/configs`, not from
   `mecha_v8_defconfig`, and it has the i.MX interconnect provider as a
   *module* where our merge produces built-in:

   ```
                                 redhat/configs   ours
   CONFIG_INTERCONNECT                 y            y
   CONFIG_INTERCONNECT_IMX             m            y
   CONFIG_INTERCONNECT_IMX8MP          m            y
   CONFIG_ARM_IMX_BUS_DEVFREQ          m            y
   CONFIG_DRM_IMX_LCDIF                m            m
   ```

   Built in, the provider registers during kernel init and the NoC is written
   the first time the LCDIF domain powers up. As modules, none of that can
   happen until udev has loaded `imx-bus` and `imx8mp-interconnect`, by which
   point the blk-ctrl has been sitting in deferred probe. Same code, very
   different point in boot.

3. `CONFIG_INTERCONNECT=n` as the blunt version of experiment 1 - the stubs in
   `include/linux/interconnect.h` make `devm_of_icc_bulk_get` return 0 and
   `icc_bulk_set_bw` a no-op. Note that `CONFIG_INTERCONNECT_IMX=n` or
   `CONFIG_INTERCONNECT_IMX8MP=n` on their own are *worse* than useless:
   `imx_bus_init_icc()` then registers no provider, `of_icc_get` returns
   -EPROBE_DEFER forever and the blk-ctrl never probes at all.

Worth noting what Mecha's own u-boot environment does: `sr_ir_v2_cmd`, which
`CONFIG_PREBOOT` runs on every boot, deletes `dsi@32e60000`,
`display-controller@32e80000`, `blk-ctl@32ec0000` and the GPU, NPU and VPU
nodes from u-boot's device tree. That reads like a workaround for silicon on
which exactly those blocks misbehave. (It deletes them from a *copy* at
`fdt_addr_r` which `loadfdt` then overwrites with the kernel's dtb, and it
spells the node `blk-ctl` where the dtb has `blk-ctrl`, so two of the removals
cannot be having any effect in any case.)

Also seen on that boot, not yet chased:

* `systemd-backlight@backlight:32e60000.dsi.0` fails with "Failed to write
  system 'brightness' attribute: Invalid argument" and gives up after six
  retries. The panel driver did register its backlight
  (`/sys/class/backlight/32e60000.dsi.0`), but the panel is not enabled, so this
  may well go away with the LCDIF bound.
* `bq27xxx-battery 3-0055` returns -EREMOTEIO for current and temperature, so
  `power_supply bq27441-0` reports no `status` and `thermal_zone0` fails its
  temperature check. The gauge answers enough to probe but not to read.
* `nxpwifi_sdio mmc0:0001:1` logs "Direct firmware load for
  nxp/cal_data.conf failed with error -2", but that file is optional: the FW
  download completes (965536 bytes), "WLAN FW is active" follows and the driver
  reports 18.99.8.p3.0, and Bluetooth gets its combo firmware too. Probably
  noise rather than a missing file; nothing in `mecha-make` references a
  `cal_data` either.
* `snvs_rtc` starts at 1970, so the first journal lines carry a bogus date
  until systemd-timesyncd steps the clock.
* `swap-on.sh` reports "Swapon failed" - no swap is set up in the `.wic`.
* `configurator-db8.sh` ends with "Partial configuration - 11 ok, 5 failed".

Everything else downstream - touch orientation, audio routing, suspend - is
untested and should be expected to need work, in roughly that order. The things
most likely to be wrong first:

* **Touch/display rotation.** The panel is 1080x1240 and the device tree leaves
  `rotation` commented out. Fix with `deviceinfo_compositor_geometry` in a
  `luneos-device-config` adaptation; that one declaration rotates evdevtouch too.
* **GridUnit.** 28 is DPI-scaled from the PinePhone's 19, not measured.
* **Sensor orientation.** `sensord-comet-imx8mp.conf` deliberately ships no
  `transformation_matrix`; see the note in that file.
* **The i.MX95 console** in `comet-imx95-boot.conf` is a guess, as is that
  machine's raw-partition size.
