# meta-arm ships trusted-firmware-a with COMPATIBLE_MACHINE = "invalid", so
# every board that wants it has to opt in by name. TFA_PLATFORM and
# TFA_BUILD_TARGET come from the machine's SoC include.
#
# The "meta-arm in FILE" guard is load-bearing, not decoration. There are two
# trusted-firmware-a recipes in this build: meta-arm's (2.10.30 / 2.12.10 /
# 2.14.1) and meta-pine64-luneos's own 2.6, which is a different recipe with
# the same name - it pins a 2021 master revision, carries four Allwinner
# patches and hard-codes PLATFORM per Pine64 machine. A plain
# COMPATIBLE_MACHINE:append in a _%.bbappend hits both, and the 2.6 recipe then
# advertises itself as a provider for the Comet, which it cannot be: it has no
# PLATFORM mapping for this machine, so it would build bl31 for whatever
# PLATFORM happened to be empty. Widen only meta-arm's.
COMPATIBLE_MACHINE:append:mecha-comet = "${@'|comet-imx8mp|comet-imx95' if 'meta-arm' in d.getVar('FILE') else ''}"

# No SPD: this build has no BL32. u-boot is configured without OP-TEE (see
# recipes-bsp/u-boot/u-boot-mecha/luneos-no-optee.cfg for why), so TF-A must not
# be built expecting a secure payload it will never be handed.
TFA_SPD:mecha-comet = ""
