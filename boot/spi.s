; vim: set ft=asm_ca65:

.include "io.inc"

.autoimport

.export spi_read, spi_write, spi_rw_byte

.code

.zeropage
spi_buf_ptr: .res 2
spi_buf_cnt: .res 2

.bss
spi_sr: .byte 0


.macro deselect
        lda     #(SD_CS|SD_MOSI|SN_WE)        ; deselect sdcard
        sta     via_porta
.endmacro

.macro select
        lda     #(SD_MOSI|SN_WE)
        sta     via_porta
.endmacro

.code

; read a byte over SPI - result in A
.proc spi_read
  select
  phx
  phy
  lda #$ff
  jsr spi_rw_byte
  ply
  plx
  pha
  deselect
  pla
  rts
.endproc

; write a byte (A) via SPI
.proc  spi_write
  pha
  select
  pla
  phx
  phy
  jsr spi_rw_byte
  ply
  plx
  pha
  deselect
  pla
  rts
.endproc

.proc spi_rw_byte
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
  rts
.endproc
