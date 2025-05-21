# EMULATOR Instructions

The included Makefile includes a recipe for creating the ROM image suitable for
loading into the [EtchedPixels
EmualtorKit](https://github.com/etchedpixels/EmulatorKit.git).

Simpy type:

``` bash
make emu
```

The 8KB rom image will be compiled and saved to `./build/rom_emu.img`

This is the file you pass into the EmulatorKit.  For example:

``` bash
./6502retro -r rom_emu.img -S 6502-retro-sdcard.img
```
