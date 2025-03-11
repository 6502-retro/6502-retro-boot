; vim: ft=asm_ca65
.include "io.inc"

.autoimport
.globalzp ptr1, bdma_ptr, lba_ptr

.export boot_boot, bios_conin, bios_conout, bios_const
.export bios_setdma, bios_setlba, bios_sdread, bios_sdwrite, bios_puts
.export bios_prbyte
.export error_code

.macro crlf
    lda #10
    jsr bios_conout
    lda #13
    jsr bios_conout
.endmacro

.zeropage

ptr1:       .word 0
bdma_ptr:   .word 0
blba_ptr:   .word 0
src:        .word 0
dst:        .word 0

.code

boot_boot:
    ldx #$ff
    txs
    cld
    sei
; copy bootloader from rom to run
    lda #<__BOOTLDR_LOAD__
    sta src+0
    lda #>__BOOTLDR_LOAD__
    sta src+1
    lda #<__BOOTLDR_RUN__
    sta dst+0
    lda #>__BOOTLDR_RUN__
    sta dst+1

    ldy #0
@L1:
    ldx #>__BOOTLDR_SIZE__
    beq @L3
@L2:
    lda (src),y
    sta (dst),y
    iny
    bne @L2
    inc src+1
    inc dst+1
    dex
    bne @L2
; Clear remaining page (y is zero on entry)
@L3:
    cpy #<__BOOTLDR_SIZE__
    beq @L4
    lda (src),y
    sta (dst),y
    iny
    bne @L3
@L4:
    ; fall through
    jmp __BOOTLDR_RUN__

; ---- BOOTLOADER SEGMENT ---------------------------------------------------

.segment "BOOTLDR"

bootloader:
    jsr via_init
    jsr acia_init
    jsr sn_start

    lda #<start_message
    ldx #>start_message
    jsr bios_puts

    ldx #3
@L1:
    phx
    jsr sdcard_init
    plx
    dex
    bne @L1

    ; copy SYSTEM code into RUN area
    ldx #<__SYSTEM_SIZE__
@L2:
    lda __SYSTEM_LOAD__ - 1,x
    sta __SYSTEM_RUN__ -1,x
    dex
    bne @L2
    jsr zerobss
    jsr zero_lba

    ; DISABLE ROM
    lda #%01000000
    ora via_porta
    sta via_porta
    lda #%01000000 ; make bit 6 an output thus driving a 0.
    ora via_ddra
    sta via_ddra

    ; COPY SECTORS FROM SDCARD TO TOP OF RAM (Behind rom)
    ; ROM IS NOW DISABLED
load_from_sdcard:
    stz bdma+0
    lda #$e0
    sta bdma+1          ; start writing into rom at E0

    lda #1
    sta sector_lba+0
    stz sector_lba+1
    stz sector_lba+2
    stz sector_lba+2

    ldx #16             ; read 16 sectors
@sector_loop:
    phx

    lda bdma+1
    jsr bios_prbyte
    lda #'-'
    jsr bios_conout

    lda bdma+0
    ldx bdma+1
    jsr bios_setdma     ; set dma

    jsr bios_printlba
    crlf

    jsr sdcard_read_sector ; read the sector

    inc bdma+1
    inc bdma+1          ; Add two pages to bdma

    inc sector_lba+0    ; add one to the lba (next sector)
    plx
    dex
    beq :+
    bra @sector_loop

:   lda #<done_message
    ldx #>done_message
    jsr bios_puts
    jsr sn_beep

    crlf
    lda $FFFC
    jsr bios_prbyte
    lda $FFFD
    jsr bios_prbyte
    ; JUMP TO THE RESET VECTOR NOW IN TOP OF RAM. (Behind rom)
    jmp ($FFFC)

bios_conin:
    jmp acia_getc

bios_conout:
    jmp acia_putc

bios_const:
    jmp acia_getc_nw

bios_setdma:
    sta bdma_ptr + 0
    sta bdma + 0
    stx bdma_ptr + 1
    stx bdma + 1
    clc
    rts

bios_setlba:
    sta blba_ptr + 0
    stx blba_ptr + 1
    ldy #3
@L1:
    lda (blba_ptr),y
    sta sector_lba,y
    dey
    bpl @L1
    clc
    rts

bios_sdread:
    jsr set_sdbuf_ptr
    jsr sdcard_read_sector
    rts

bios_sdwrite:
    jsr set_sdbuf_ptr
    jsr sdcard_write_sector
    rts

bios_puts:
    sta ptr1 + 0
    stx ptr1 + 1
    ldy #0
:   lda (ptr1),y
    beq @done
    jsr acia_putc
    iny
    beq @done
    bra :-
@done:
    rts

bios_printlba:
    pha
    phx
    phy

    lda sector_lba + 3
    jsr bios_prbyte
    lda sector_lba + 2
    jsr bios_prbyte
    lda sector_lba + 1
    jsr bios_prbyte
    lda sector_lba + 0
    jsr bios_prbyte

    ply
    plx
    pla
    rts

bios_prbyte:
    pha             ;Save A for LSD.
    lsr
    lsr
    lsr             ;MSD to LSD position.
    lsr
    jsr prhex       ;Output hex digit.
    pla             ;Restore A.
prhex:
    and #$0F        ;Mask LSD for hex print.
    ora #$B0        ;Add "0".
    cmp #$BA        ;Digit?
    bcc echo        ;Yes, output it.
    adc #$06        ;Add offset for letter.
echo:
    pha             ;*Save A
    and #$7F        ;*Change to "standard ASCII"
    jsr acia_putc
    pla             ;*Restore A
    rts             ;*Done, over and out...

;---- Helper functions -------------------------------------------------------
set_sdbuf_ptr:
    lda bdma + 1
    sta bdma_ptr + 1
    lda bdma + 0
    sta bdma_ptr + 0
    rts

zero_lba:
    stz sector_lba + 0 ; sector inside file
    stz sector_lba + 1 ; file number
    stz sector_lba + 2 ; drive number
    stz sector_lba + 3 ; always zero
    rts

start_message: .byte 10,13,"BOOT LOADER STARTING...",10,13,0
done_message: .byte 10,13,"BOOT LOADER FINISHED. JUMPING TO OS",10,13,0

.segment "SYSTEM"
; dispatch function, will be relocated on boot into SYSRAM
error_code: .byte 0 ; 230


.bss
bdma:       .word 0
sdcard_lba: .dword 0
.rodata
