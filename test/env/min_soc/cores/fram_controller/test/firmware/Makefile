# Firmware de la prueba en hardware del controlador FRAM.
#
# Programa: calculator.S de digital_UN y sus rutinas, usados como dependencia
# (no se copian), más fram_boot.S, que copia la BRAM a la FRAM y salta a
# calculator en la FRAM.
#
# Genera ../firmware.hex, que bram.v carga con $readmemh("./firmware.hex").

FW_SRC ?= $(abspath ../../../../digital_UN/basic_circuits/test_peripherals/firmware/asm)

PREFIX  ?= riscv-none-elf-
AS       = $(PREFIX)as
LD       = $(PREFIX)ld
OBJCOPY  = $(PREFIX)objcopy
OBJDUMP  = $(PREFIX)objdump

# -mno-relax / --no-relax: "la" y "call" quedan como auipc + addi / auipc + jalr
# (relativos al PC), así la copia en la FRAM usa su propio código y datos.
AFLAGS   = -march=rv32i_zicsr -mabi=ilp32 -mno-relax
LDFLAGS  = -m elf32lriscv -nostdlib --no-relax -N

# Mismos objetos que el Makefile de digital_UN, más fram_boot.o
FW_OBJS  = get_number.o bin2bcd.o bcd2bin.o bin_to_bcd.o sqrt.o mult.o div.o \
           wait.o putchar.o getchar.o calculator.o putstring.o
OBJECTS  = fram_boot.o $(FW_OBJS)

.PHONY: all clean

all: ../firmware.hex firmware.lst

fram_boot.o: fram_boot.S
	$(AS) $(AFLAGS) -c $< -o $@

%.o: $(FW_SRC)/%.S
	$(AS) $(AFLAGS) -c $< -o $@

firmware.elf: $(OBJECTS) fram_boot.ld
	$(LD) $(LDFLAGS) -T fram_boot.ld -Map firmware.map -o $@ $(OBJECTS)

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

firmware.lst: firmware.elf
	$(OBJDUMP) -h -S $< > $@

../firmware.hex: firmware.bin bin2hex.py
	python3 bin2hex.py $< $@

clean:
	rm -f $(OBJECTS) firmware.elf firmware.bin firmware.lst firmware.map ../firmware.hex
