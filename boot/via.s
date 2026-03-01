; vim: ft=asm_ca65
.include "io.inc"

.autoimport

.export via_init, led_on, led_off

.segment "BOOTLDR"
; WE will DISABLE rom by making bit 6 on DDRA an OUTPUT.
; FOR NOW though, it's floating, so pulled up by a resistor.
via_init:
    lda #(SD_SCK|SPI_CS2|SPI_CS3|SD_CS|SN_WE|SD_MOSI)
    sta via_porta
    lda #(SD_SCK|SPI_CS2|SPI_CS3|SD_CS|SN_WE|SD_MOSI) ; ROM SWITCH IS ON BY PULLUP
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

