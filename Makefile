# Assembler, linker and scripts
AS = ca65
LD = ld65
RELIST = scripts/relist.py
FINDSYM = scripts/findsymbols
LOADTRIM = scripts/loadtrim.py
TTY_DEVICE = /dev/ttyUSB0

# Assembler flags
ASFLAGS += -I inc -g --feature labels_without_colons --cpu 65C02 --feature string_escapes

# Set DEBUG=1 for debugging.
DEBUG = -D DEBUG=0

# Set CFG to the config for size of rom
CFG = rom_8k.cfg

RAM_CFG = ram.cfg
SFM_LOAD_ADDR = 8000

# Where should the builds be placed
BUILD_DIR = build

# Sources and objects
boot_SOURCES = \
	       boot/boot.s \
	       boot/acia.s \
	       boot/sdcard.s \
	       boot/sn76489.s \
	       boot/zerobss.s \
	       boot/via.s \
	       boot/xm.s \
	       boot/vectors.s \

boot_OBJS = $(addprefix $(BUILD_DIR)/, $(boot_SOURCES:.s=.o))


all: clean $(BUILD_DIR)/rom.raw $(BUILD_DIR)/ram.bin

clean:
	rm -fr $(BUILD_DIR)/*

$(BUILD_DIR)/%.o: %.s
	@mkdir -p $$(dirname $@)
	$(AS) $(ASFLAGS) $(DEBUG) -l $(BUILD_DIR)/$*.lst $< -o $@

$(BUILD_DIR)/rom.raw: $(boot_OBJS)
	@mkdir -p $$(dirname $@)
	$(LD) -C config/$(CFG) $^ -o $@ -m $(BUILD_DIR)/rom.map -Ln $(BUILD_DIR)/rom.sym
	$(RELIST) $(BUILD_DIR)/rom.map $(BUILD_DIR)/boot
	$(LOADTRIM) $(BUILD_DIR)/rom.raw $(BUILD_DIR)/rom.bin E000

$(BUILD_DIR)/ram.bin: $(boot_OBJS)
	@mkdir -p $$(dirname $@)
	$(LD) -C config/$(RAM_CFG) $^ -o $(BUILD_DIR)/ram.raw -m $(BUILD_DIR)/ram.map -Ln $(BUILD_DIR)/ram.sym
	$(LOADTRIM) $(BUILD_DIR)/ram.raw $@ $(SFM_LOAD_ADDR)

$(BUILD_DIR)/rom_load.bin: $(boot_OBJS)
	@mkdir -p $$(dirname $@)
	$(LD) -C config/rom_load.cfg $^ -o $(BUILD_DIR)/rom_load.raw -m $(BUILD_DIR)/rom_load.map -Ln $(BUILD_DIR)/rom_load.sym
	$(RELIST) $(BUILD_DIR)/rom_load.map $(BUILD_DIR)/boot
	$(LOADTRIM) $(BUILD_DIR)/rom_load.raw $@ E000

grep:
	grep boot_boot $(BUILD_DIR)/ram.sym

minipro:
	cat build/rom.raw ../6502-retro-monitor/build/bankmon.raw > build/rom.img
	minipro -s -p SST27SF512@DIP28 -w build/rom.img
