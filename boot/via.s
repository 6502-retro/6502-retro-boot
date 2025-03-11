; vim: ft=asm_ca65
.include "io.inc"

.autoimport

.export via_init, led_on, led_off, get_button

SD_SCK          = %00000001
SD_CS           = %00000010
SN_WE           = %00000100
SN_READY        = %00001000
ROMSW           = %01000000
SD_MOSI         = %10000000
LED_ON          = %00010000 ; ORA
LED_OFF         = %11101111 ; AND
BUTTON          = %00100000 ; MASK
ROM_SWITCH_ON   = %01000000 ; ORA
ROM_SWITCH_OFF  = %10111111 ; AND

.code

.segment "BOOTLDR"
; WE will DISABLE rom by making bit 6 on DDRA an OUTPUT.
; FOR NOW though, it's floating, so pulled up by a resistor.
via_init:
    lda #(SD_SCK|SD_CS|SN_WE|SD_MOSI)
    sta via_porta
    lda #(SD_SCK|SD_CS|SN_WE|SD_MOSI) ; ROM SWITCH IS ON BY PULLUP NO
    sta via_ddra
    rts

led_on:
    lda via_porta
    ora #LED_ON
    sta via_porta
    rts

led_off:
    lda via_porta
    and #LED_OFF
    sta via_porta
    rts

; returns 1 when pressed.
get_button:
    lda via_porta
    and #BUTTON
    beq :+
    lda #0
    rts
:   lda #1
    rts

