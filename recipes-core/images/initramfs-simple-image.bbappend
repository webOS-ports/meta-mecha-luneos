# key-state reads the recovery trigger node named on the kernel command line;
# luneos-recovery-ui is what draws the menu when it fires.
IMAGE_INSTALL:append:mecha-comet = " luneos-recovery-ui key-state"
