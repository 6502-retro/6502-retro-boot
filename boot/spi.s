; vim: set ft=asm_ca65:

.include "io.inc"

.autoimport

.export spi_read, spi_write, spi_rw_byte


.bss
spi_sr: .byte 0

.segment "BOOTLDR"

; read a byte over SPI - result in A
spi_read:
  lda #$ff
  jmp spi_rw_byte

; write a byte (A) via SPI
spi_write:
  ; fall through

spi_rw_byte:
  phx
  phy
  sta spi_sr

  ldx #$08

  lda via_porta
  and #$fe

  asl
  tay

@l:
  rol spi_sr
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
