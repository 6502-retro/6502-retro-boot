; vim: ft=asm_ca65
.include "io.inc"
.autoimport
.globalzp ptr1
.export acia_init, acia_putc

; vim: set ft=asm_ca65 sw=4 ts=4 et:
ACIA_PARITY_DISABLE          = %00000000
ACIA_ECHO_DISABLE            = %00000000
ACIA_TX_INT_DISABLE_RTS_LOW  = %00001000
ACIA_RX_INT_ENABLE           = %00000000
ACIA_RX_INT_DISABLE          = %00000010
ACIA_DTR_LOW                 = %00000001


.zeropage

.segment "BOOTLDR"
acia_init:
    lda #$00
    sta acia_status
    lda #(ACIA_PARITY_DISABLE | ACIA_ECHO_DISABLE | ACIA_TX_INT_DISABLE_RTS_LOW | ACIA_RX_INT_DISABLE | ACIA_DTR_LOW)
    sta acia_command
    lda #$10
    sta acia_control
    rts

acia_putc:
    pha                         ; save char
@wait_txd_empty:
    lda acia_status
    and #$10
    beq @wait_txd_empty
    pla                     ; restore char
    sta acia_data
    rts

.bss

.rodata
