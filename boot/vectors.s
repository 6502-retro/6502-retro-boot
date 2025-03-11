; vim: set ft=asm_ca65 sw=4 ts=4 et:
.include "io.inc"
.autoimport
.code
nmi:
    rti

irq:
    rti

.segment "VECTORS"
    .addr nmi
    .addr boot_boot
    .addr irq

