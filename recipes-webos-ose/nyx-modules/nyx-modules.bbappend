# nyx-modules takes a per-machine file://${MACHINE}.cmake and there is no
# fallback: without one the recipe cannot even be parsed for a new machine.
#
# It lives here rather than in meta-webos-ports/meta-luneos next to the other 57
# because it is Comet hardware description, and Comet hardware description
# belongs in the Comet layer - the same argument meta-pine64-luneos makes by
# carrying its own sensorfw and udev-extraconf appends.
FILESEXTRAPATHS:prepend:mecha-comet := "${THISDIR}/${PN}:"
