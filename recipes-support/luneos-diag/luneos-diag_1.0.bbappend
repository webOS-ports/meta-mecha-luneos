# luneos-diag lives in meta-pine64-luneos and pins COMPATIBLE_MACHINE to the
# three Pine64 boards, so a Comet build fails with "Nothing RPROVIDES
# 'luneos-diag'" as soon as mecha-comet.inc recommends it.
#
# Nothing in it is Pine64-specific: luneos-diag.sh dumps dwc3/UDC gadget
# binding, Type-C roles, extcon cables, power supplies, DRM nodes and who holds
# them, whether libEGL got wl_drm, and the wireless regulatory domain. There is
# not one pine, rk3 or sun50i string in the script. On a board nobody has booted
# yet that dump is worth more than on the boards it was written for.
#
# Widening it from here rather than editing the Pine64 layer keeps the change
# with the machine that needs it.
COMPATIBLE_MACHINE:append:mecha-comet = "|comet-imx8mp|comet-imx95"
