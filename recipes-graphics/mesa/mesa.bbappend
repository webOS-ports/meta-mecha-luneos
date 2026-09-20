# The two Comet variants need two different gallium drivers, and both are open:
#
#   i.MX8M Plus  Vivante GC7000UL + GC520L  -> etnaviv
#   i.MX95       Arm Mali-G310 (Valhall)    -> panfrost
#
# Neither needs NXP's proprietary imx-gpu-viv stack, which is the usual reason a
# build like this ends up depending on meta-freescale. GC7000UL is one of the
# cores etnaviv has supported for years, and Mecha's own kernel config agrees:
# mecha_v8_defconfig sets CONFIG_DRM_ETNAVIV=m, not the vendor driver.
#
# Both are enabled for both machines on purpose, the same way meta-pine64-luneos
# enables lima and panfrost together: it keeps one mesa build shared across the
# machines instead of splitting sstate for a driver that costs almost nothing to
# carry.
PACKAGECONFIG:append:mecha-comet = " etnaviv panfrost"
