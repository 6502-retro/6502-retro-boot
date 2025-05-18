; vim: ft=asm_ca65
.include "io.inc"

.export spi_ssel_true, spi_ssel_false, spi_read, spi_write, spi_rw_byte

.bss
spi_sr:         .byte 0

.segment "BOOTLDR"

spi_ssel_true:
        pha
        phx
        phy
        ; read and discard a byte to generate 8 clk cycles
        jsr spi_read
        ; make sure clock = 0 and mosi = 1 before enabling the card.
        lda via_porta
        and #%11111110 ; CLOCK = 0
        ora #%10000000 ; MOSI  = 1
        sta via_porta
        ; enable the card
        and #%11111101 ; SD_CS = 0
        sta via_porta
        ; read and discard a byte to generate another 8 clk cycles
        jsr spi_read
        ply
        plx
        pla
        rts

spi_ssel_false:
        pha
        phx
        phy
        ; read and discard a byte to generate 8 clk cycles
        jsr spi_read
        ; make sure clock is low before disabling the card
        lda via_porta
        and #%11111110 ; CLOCK = 0
        sta via_porta
        ora #%10000010 ; MOSI=1, SDCS=1
        sta via_porta
        jsr spi_read
        jsr spi_read
        ply
        plx
        pla
        rts

spi_read:
        lda #$ff
        jsr spi_rw_byte
        rts

spi_write:
        jsr spi_rw_byte
        rts

; send byte (A), return received byte in A.
spi_rw_byte:
        phx
        phy

        sta spi_sr

        ldx #$08

        lda via_porta
        and #$fe

        asl
        tay

@l:     rol spi_sr
        tya
        ror

        sta via_porta
        inc via_porta
        sta via_porta

        dex
        bne @l

        lda via_sr
        ply
        plx
        rts

