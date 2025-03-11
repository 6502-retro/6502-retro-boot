# 6502-Retro-Boot

This is the ROM Bootloader for the 6502-Retro.  It copies 16 sectors (8kb) from
the SDCARD sectors 1 to 17 into RAM at 0xE000.

The way it works is the rom first copies the bootloader code into low ram and
jumps to it.

Then the bootloader disables the ROM by writing a 0 on pin 6 of the VIA PORT A.
Once that's done, it begins copying the 16 sectors from the SDCARD from sector
1 into 0xE000, sector 2 into 0xE200 etc.  When all 16 sectors are copied, the
bootloader jumps to the reset vector at 0xFFFC.

And that's it.
