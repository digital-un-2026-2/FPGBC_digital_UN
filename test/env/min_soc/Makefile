.DEFAULT_GOAL := help

PIXI_BIN := $(abspath ../../../.pixi/envs/default/bin)
EQ144_YOSYS ?= $(if $(wildcard $(PIXI_BIN)/yosys),$(PIXI_BIN)/yosys,yosys)
EQ144_NEXTPNR ?= $(or $(shell command -v nextpnr-himbaechel-gowin 2>/dev/null),$(wildcard $(abspath ../../../.nextpnr/bin/nextpnr-himbaechel)),nextpnr-himbaechel)
EQ144_PACK ?= $(if $(wildcard $(PIXI_BIN)/gowin_pack),$(PIXI_BIN)/gowin_pack,gowin_pack)
EQ144_LOADER ?= $(if $(wildcard $(PIXI_BIN)/openFPGALoader),$(PIXI_BIN)/openFPGALoader,openFPGALoader)
IVERILOG ?= $(if $(wildcard $(PIXI_BIN)/iverilog),$(PIXI_BIN)/iverilog,iverilog)
VVP ?= $(if $(wildcard $(PIXI_BIN)/vvp),$(PIXI_BIN)/vvp,vvp)
EQ144_FTDI_SERIAL ?=
EQ144_JTAG_FREQ ?= 1000000
CALC_BUILD_DIR ?= ./build/gw2ar_eq144_calc
TOP := SOC

SOURCES := \
	cores/cpu/femtorv32_quark_un_irq.v \
	cores/uart/perip_uart.v cores/uart/uart.v \
	cores/bram/bram.v \
	cores/bin2bcd/add_sub_c2.v cores/bin2bcd/bin2bcd.v \
	cores/bin2bcd/mux2.v cores/bin2bcd/count.v cores/bin2bcd/ctrl_b2b.v \
	cores/bin2bcd/perip_bin2bcd.v cores/bin2bcd/lsr4.v cores/bin2bcd/reg_msb.v \
	cores/bcd2bin/bcd2bin.v cores/bcd2bin/perip_bcd2bin.v cores/bcd2bin/rsr4.v \
	cores/sqrt_ASM/perip_sqrt.v cores/sqrt_ASM/sqrt.v \
	cores/sqrt_ASM/control.v cores/sqrt_ASM/count.v cores/sqrt_ASM/lsr.v \
	cores/sqrt_ASM/lsr2.v cores/sqrt_ASM/addc2.v \
	cores/cart_flash/arreglobitscpu.v cores/cart_flash/controller.v \
	cores/cart_flash/rcv_data_register.v cores/cart_flash/byte_counter.v \
	cores/cart_flash/byte_comparator.v cores/cart_flash/address_generator.v \
	cores/cart_flash/cart_memory.v SOC.v

.PHONY: help check_cart_image sim_cart_calc check_synth build_cart_calc load_cart_calc configure_cart_calc detect
help:
	@echo "sim_cart_calc       Simular lector, periféricos y calculadora desde cartucho"
	@echo "check_synth         Comprobar síntesis sin colocar/enrutar"
	@echo "build_cart_calc     Generar build/gw2ar_eq144_calc/SOC.fs"
	@echo "load_cart_calc      Cargar el .fs generado en SRAM de FPGA"
	@echo "configure_cart_calc Generar y cargar el .fs"
	@echo "detect              Detectar la FPGA por JTAG"

check_cart_image:
	python3 tests/check_image.py

sim_cart_calc: check_cart_image
	python3 tests/simulate.py --iverilog "$(IVERILOG)" --vvp "$(VVP)" $(abspath $(SOURCES))

check_synth: check_cart_image
	mkdir -p build
	"$(EQ144_YOSYS)" -Q -T -q -l build/check_synth.log -p 'read_verilog $(SOURCES); synth_gowin -family gw2a -top $(TOP); check -assert'

build_cart_calc: check_cart_image $(SOURCES) gw2ar_eq144.cst gw2ar_eq144.sdc
	mkdir -p "$(CALC_BUILD_DIR)"
	"$(EQ144_YOSYS)" -Q -T -q -l $(CALC_BUILD_DIR)/$(TOP)_synth.log -p 'read_verilog $(SOURCES); synth_gowin -family gw2a -top $(TOP) -json $(CALC_BUILD_DIR)/$(TOP)_synth.json; check -assert'
	"$(EQ144_NEXTPNR)" --device GW2AR-LV18EQ144PC8/I7 --top $(TOP) --json $(CALC_BUILD_DIR)/$(TOP)_synth.json --write $(CALC_BUILD_DIR)/$(TOP)_pnr.json --sdc gw2ar_eq144.sdc --freq 40 --vopt family=GW2A-18C --vopt cst=gw2ar_eq144.cst --seed 1 --report $(CALC_BUILD_DIR)/$(TOP)_report.json --log $(CALC_BUILD_DIR)/$(TOP)_pnr.log
	"$(EQ144_PACK)" -d GW2A-18C -o $(CALC_BUILD_DIR)/$(TOP).fs $(CALC_BUILD_DIR)/$(TOP)_pnr.json

load_cart_calc:
	test -s "$(CALC_BUILD_DIR)/$(TOP).fs"
	"$(EQ144_LOADER)" --cable ft232RL --pins TXD:CTS:RTS:RXD --freq $(EQ144_JTAG_FREQ) $(if $(strip $(EQ144_FTDI_SERIAL)),--ftdi-serial "$(EQ144_FTDI_SERIAL)") --write-sram --bitstream $(CALC_BUILD_DIR)/$(TOP).fs

configure_cart_calc: build_cart_calc
	$(MAKE) load_cart_calc CALC_BUILD_DIR="$(CALC_BUILD_DIR)"

detect:
	"$(EQ144_LOADER)" --cable ft232RL --pins TXD:CTS:RTS:RXD --freq $(EQ144_JTAG_FREQ) $(if $(strip $(EQ144_FTDI_SERIAL)),--ftdi-serial "$(EQ144_FTDI_SERIAL)") --detect
