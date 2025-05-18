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

.segment "BOOTLDR"
;-----------------------------------------------------------------------------
; wait ready
;
; clobbers: A,X,Y
;-----------------------------------------------------------------------------
wait_ready:
        lda #$F0
        sta timeout_cnt

@1:     ldx #0          ; 2
@2:     ldy #0          ; 2
@3:     jsr spi_read    ; 22
        cmp #$FF        ; 2
        beq @done       ; 2 + 1
        dey             ; 2
        bne @3          ; 2 + 1
        dex             ; 2
        bne @2          ; 2 + 1
        dec timeout_cnt
        bne @1

        ; Total timeout: ~508 ms @ 8MHz

        ; Timeout error
        clc
        rts

@done:  sec
        rts

; waits for sdcard to return anything other than FF
wait_result:
        jsr spi_read
        cmp #$FF
        beq wait_result
        rts

;-----------------------------------------------------------------------------
; send_cmd - Send cmdbuf
;
; first byte of result in A, clobbers: Y
;-----------------------------------------------------------------------------
send_cmd:
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
        sec
        rts

@error: ; Error
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

;-----------------------------------------------------------------------------
; sdcard_init
; result: C=0 -> error, C=1 -> success
;-----------------------------------------------------------------------------
sdcard_init:
        ; init shift register and port b for SPI use
        ; SR shift in, External clock on CB1
        lda #%00001100
        sta via_acr

        jsr spi_ssel_false
        ldx #160
        lda via_porta
@clockloop:
        eor #SD_SCK
        sta via_porta
        dex
        bne @clockloop

        jsr spi_ssel_true

        ; Enter idle state
        send_cmd_inline 0, 0
        bcs @2
        jmp @error
@2:
        cmp #1  ; In idle state?
        beq @3
        jmp @error
@3:
        ; SDv2? (SDHC/SDXC)
        send_cmd_inline 8, $1AA
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
@6:
        send_cmd_inline 55, 0
        bcs @7
        bra @error
@7:
        send_cmd_inline 41, $40000000
        bcs @8
        bra @error
@8:
        cmp #0
        bne @6

        ; ; Check CCS bit in OCR register
        send_cmd_inline 58, 0
        cmp #0
        jsr spi_read
        and #$40        ; Check if this card supports block addressing mode
        beq @error
        jsr spi_read
        jsr spi_read
        jsr spi_read

        ; Success
        jsr spi_ssel_false
        sec
        rts

@error:
        ; Error
        jsr spi_ssel_false
        clc
        rts

;-----------------------------------------------------------------------------
; sdcard_read_sector
; Set sector_lba prior to calling this function.
; result: C=0 -> error, C=1 -> success
;-----------------------------------------------------------------------------
sdcard_read_sector:
.if DEBUG=1
        lda #0
        jsr debug_sector_lba
.endif
        jsr spi_ssel_true

        ; Send READ_SINGLE_BLOCK command
        lda #($40 | 17)
        sta cmd_idx
        lda #1
        sta cmd_crc
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
        jsr spi_ssel_false
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

        ; Success
        jsr spi_ssel_false
        sec
        rts
