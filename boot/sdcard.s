; vim: ft=asm_ca65
;-----------------------------------------------------------------------------
; SDCARD Routines adapted from: 
;       https://github.com/X16Community/x16-rom/blob/master/fat32/sdcard.s
;       Copyright (C) 2020 Frank van den Hoef
;
; SPI Routines from: 
;       https://github.com/Steckschwein/code/blob/master/steckos/libsrc/spi/spi_rw_byte.s
;       Copyright (c) 2018 Thomas Woinke, Marko Lauke, www.steckschwein.de
;-----------------------------------------------------------------------------
.include "io.inc"
.autoimport
.globalzp bdma_ptr
.export sector_lba, sdcard_init, sdcard_read_sector

.macro deselect
        lda     #(SD_CS|SD_MOSI|SN_WE)        ; deselect sdcard
        sta     via_porta
.endmacro

.macro select
        lda     #(SD_MOSI|SN_WE)
        sta     via_porta
.endmacro

cmd_idx = sdcard_param
cmd_arg = sdcard_param + 1
cmd_crc = sdcard_param + 5


        .bss
sdcard_param:
        .res 1
sector_lba:
        .res 4 ; dword (part of sdcard_param) - LBA of sector to read/write
        .res 1

timeout_cnt:    .byte 0
spi_sr:         .byte 0

.segment "BOOTLDR"

; read a byte over SPI - result in A
spi_read:
        pha
        select
        pla
        lda #$ff
        phx
        phy
        jsr spi_rw_byte
        ply
        plx
        pha
        deselect
        pla
        rts


; write a byte (A) via SPI
spi_write:
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

spi_rw_byte:
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
        rts
;-----------------------------------------------------------------------------
; send_cmd - Send cmdbuf
;
; first byte of result in A, clobbers: Y
;-----------------------------------------------------------------------------
send_cmd:
        jsr sdcmd_start
        ; Send the 6 cmdbuf bytes
        lda cmd_idx
        jsr spi_write
        lda cmd_arg + 3
        jsr spi_write
        lda cmd_arg + 2
        jsr spi_write
        lda cmd_arg + 1
        jsr spi_write
        lda cmd_arg + 0
        jsr spi_write
        lda cmd_crc
        jsr spi_write

        ; Wait for response
        ldy #(10 + 1)
@1:     dey
        beq @error      ; Out of retries
        jsr spi_read
        cmp #$ff
        beq @1

        ; Success
        jsr sdcmd_end
        sec
        rts

@error: ; Error
        jsr sdcmd_end
        clc
        rts

;-----------------------------------------------------------------------------
; send_cmd_inline - send command with specified argument
;-----------------------------------------------------------------------------
.macro send_cmd_inline cmd, arg
        lda #(cmd | $40)
        sta cmd_idx

.if .hibyte(.hiword(arg)) = 0
        stz cmd_arg + 3
.else
        lda #(.hibyte(.hiword(arg)))
        sta cmd_arg + 3
.endif

.if ^arg = 0
        stz cmd_arg + 2
.else
        lda #^arg
        sta cmd_arg + 2
.endif

.if >arg = 0
        stz cmd_arg + 1
.else
        lda #>arg
        sta cmd_arg + 1
.endif

.if <arg = 0
        stz cmd_arg + 0
.else
        lda #<arg
        sta cmd_arg + 0
.endif

.if cmd = 0
        lda #$95
.else
.if cmd = 8
        lda #$87
.else
        lda #1
.endif
.endif
        sta cmd_crc
        jsr send_cmd
.endmacro

sdcmd_start:
        php
        pha
        phx
        jsr sdcmd_nothingbyte
        jsr sdcmd_nothingbyte
        lda #$ff
        jsr spi_write
        plx
        pla
        plp
        rts

sdcmd_nothingbyte:
        ldx     #8
@loop:
        lda #(SD_MOSI|SD_CS|SN_WE)
        sta via_porta
        lda #(SD_SCK|SD_MOSI|SD_CS|SN_WE)
        sta via_porta
        dex
        bne @loop
        rts

sdcmd_end:
        php
        pha
        phx
        lda #$ff
        jsr spi_write
        jsr sdcmd_nothingbyte
        jsr sdcmd_nothingbyte
        lda #(SD_CS|SD_MOSI|SN_WE)
        sta via_porta
        plx
        pla
        plp
        rts

;-----------------------------------------------------------------------------
; sdcard_init
; result: C=0 -> error, C=1 -> success
;-----------------------------------------------------------------------------
sdcard_init:
        php
        sei
        ; init shift register and port b for SPI use
        ; SR shift in, External clock on CB1
        lda #%00001100
        sta via_acr

        lda     #(SD_CS|SD_MOSI|SN_WE)        ; toggle clock 160 times
        ldx     #160
@clockloop:
        eor     #SD_SCK
        sta     via_porta
        dex
        bne     @clockloop

        ; Enter idle state
        jsr sdcmd_start
        send_cmd_inline 0, 0
        jsr sdcmd_end
        bcs @2
        jmp @error
@2:
        cmp #1  ; In idle state?
        beq @3
        jmp @error
@3:
        ; SDv2? (SDHC/SDXC)
        jsr sdcmd_start
        send_cmd_inline 8, $1AA
        jsr sdcmd_end
        bcs @4
        jmp @error
@4:
        cmp #1  ; No error?
        beq @5
        jmp @error
@5:
@sdv2:  ; Receive remaining 4 bytes of R7 response
        jsr spi_read
        jsr spi_read
        jsr spi_read
        jsr spi_read

        ; Wait for card to leave idle state
@6:     jsr sdcmd_start
        send_cmd_inline 55, 0
        jsr sdcmd_end
        bcs @7
        bra @error
@7:
        jsr sdcmd_start
        send_cmd_inline 41, $40000000
        jsr sdcmd_end
        bcs @8
        bra @error
@8:
        cmp #0
        bne @6

        ; ; Check CCS bit in OCR register
        jsr sdcmd_start
        send_cmd_inline 58, 0
        jsr sdcmd_end
        cmp #0
        jsr spi_read
        and #$40        ; Check if this card supports block addressing mode
        bne @exit_ok
@9:
        jsr sdcmd_start
        send_cmd_inline 16, $00000200
@exit_ok:
        ; Success
        deselect
        plp
        sec
        rts
@error:
        ; Error
        deselect
        plp
        clc
        rts

;-----------------------------------------------------------------------------
; sdcard_read_sector
; Set sector_lba prior to calling this function.
; result: C=0 -> error, C=1 -> success
;-----------------------------------------------------------------------------
sdcard_read_sector:
        jsr sdcmd_start
        ; Send READ_SINGLE_BLOCK command
        lda #($40 | 17)
        sta cmd_idx
        lda #1
        sta cmd_crc
        jsr sdcmd_start
        jsr send_cmd

        ; Wait for start of data packet
        ldx #0
@1:     ldy #0
@2:     jsr spi_read
        cmp #$FE
        beq @start
        dey
        bne @2
        dex
        bne @1

        ; Timeout error
        jsr sdcmd_end
        deselect
        clc
        rts

@start: ; Read 512 bytes of sector data
        ldx #$FF
        ldy #0
@3:     jsr spi_read
        sta (bdma_ptr), y
        iny
        bne @3
        inc bdma_ptr + 1
        ; Y already 0 at this point
@5:     jsr spi_read
        sta (bdma_ptr), y
        iny
        bne @5
        dec bdma_ptr + 1

        ; Read CRC bytes
        jsr spi_read
        jsr spi_read

        jsr sdcmd_end
        ; Success
        deselect
        sec
        rts
