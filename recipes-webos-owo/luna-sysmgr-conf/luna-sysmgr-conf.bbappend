# Same situation as nyx-modules: luna-sysmgr-conf needs a per-machine
# luna-platform.conf and has no default to fall back on.
FILESEXTRAPATHS:prepend:mecha-comet := "${THISDIR}/${PN}:"
