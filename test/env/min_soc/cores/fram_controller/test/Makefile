# Prueba en hardware del controlador FRAM (SoC de min_soc + controlador FRAM).
#
# Usa como dependencia, sin copiarlos:
#   - min_soc (FPGBC_digital_UN): CPU, UART, bin2bcd, bcd2bin y sqrt.
#   - test_peripherals de digital_UN: BRAM con $$readmemh("./firmware.hex")
#     y multiplicador, que ya no están en min_soc.
#   - la RTL del controlador en ../rtl. Herramientas del entorno pixi de
# FPGBC_digital_UN (yosys, nextpnr-himbaechel, gowin_pack,
# openFPGALoader, riscv-none-elf-gcc).

MIN_SOC  ?= $(abspath ../../../FPGBC_digital_UN/test/env/min_soc)
DUN_RTL  ?= $(abspath ../../../digital_UN/basic_circuits/test_peripherals/rtl)
FRAM_RTL ?= $(abspath ../rtl)

# Herramientas: entorno pixi y toolchain RISC-V de FPGBC_digital_UN si existen
PIXI_BIN := $(abspath $(MIN_SOC)/../../../.pixi/envs/default/bin)
RV_BIN   := $(firstword $(wildcard $(abspath $(MIN_SOC)/../../../.toolchain)/xpack-riscv-none-elf-gcc-*/bin))
EQ144_YOSYS      ?= $(if $(wildcard $(PIXI_BIN)/yosys),$(PIXI_BIN)/yosys,yosys)
EQ144_NEXTPNR    ?= $(or $(shell command -v nextpnr-himbaechel-gowin 2>/dev/null),$(if $(wildcard $(PIXI_BIN)/yowasp-nextpnr-himbaechel-gowin),$(PIXI_BIN)/yowasp-nextpnr-himbaechel-gowin,nextpnr-himbaechel-gowin))
EQ144_PACK       ?= $(if $(wildcard $(PIXI_BIN)/gowin_pack),$(PIXI_BIN)/gowin_pack,gowin_pack)
EQ144_LOADER     ?= $(if $(wildcard $(PIXI_BIN)/openFPGALoader),$(PIXI_BIN)/openFPGALoader,openFPGALoader)
RV_PREFIX        ?= $(if $(RV_BIN),$(RV_BIN)/riscv-none-elf-,riscv-none-elf-)
EQ144_BUILD_DIR  ?= ./gw2ar_eq144_fram_controller
EQ144_FTDI_SERIAL ?=
EQ144_JTAG_FREQ  ?= 100000

# Núcleos de min_soc
COMM_OBJS  = $(MIN_SOC)/cores/cpu/femtorv32_quark_un_irq.v
COMM_OBJS += $(MIN_SOC)/cores/uart/perip_uart.v
COMM_OBJS += $(MIN_SOC)/cores/uart/uart.v

COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/add_sub_c2.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/bin2bcd.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/mux2.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/count.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/ctrl_b2b.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/perip_bin2bcd.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/lsr4.v
COMM_OBJS += $(MIN_SOC)/cores/bin2bcd/reg_msb.v

COMM_OBJS += $(MIN_SOC)/cores/bcd2bin/bcd2bin.v
COMM_OBJS += $(MIN_SOC)/cores/bcd2bin/perip_bcd2bin.v
COMM_OBJS += $(MIN_SOC)/cores/bcd2bin/rsr4.v

COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/perip_sqrt.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/sqrt.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/control.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/count.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/lsr.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/lsr2.v
COMM_OBJS += $(MIN_SOC)/cores/sqrt_ASM/addc2.v

# BRAM con firmware inicial (la de min_soc ya no tiene $$readmemh)
COMM_OBJS += $(DUN_RTL)/cores/bram/bram.v

# Multiplicador (peripheral_test, retirado de min_soc)
COMM_OBJS += $(DUN_RTL)/cores/test/perip_test.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/mult_32.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/acc.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/comp.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/lsr_mult.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/control_mult2.v
COMM_OBJS += $(DUN_RTL)/cores/test/mult/rsr.v

# Controlador FRAM
FRAM_OBJS  = $(FRAM_RTL)/fram_controller.v
FRAM_OBJS += $(FRAM_RTL)/fram_fsm.v
FRAM_OBJS += $(FRAM_RTL)/fram_timer.v
FRAM_OBJS += $(FRAM_RTL)/fram_byte_counter.v
FRAM_OBJS += $(FRAM_RTL)/fram_req_reg.v
FRAM_OBJS += $(FRAM_RTL)/fram_addr_mapper.v
FRAM_OBJS += $(FRAM_RTL)/fram_addr_out.v
FRAM_OBJS += $(FRAM_RTL)/fram_bank_selector.v
FRAM_OBJS += $(FRAM_RTL)/fram_data_reg.v
FRAM_OBJS += $(FRAM_RTL)/fram_dq_mux.v
FRAM_OBJS += $(FRAM_RTL)/fram_dq_tri.v

TOP  = fram_hw_test
OBJS = $(COMM_OBJS) $(FRAM_OBJS) $(TOP).v

.PHONY: firmware check_deps check_synth build configure detect clean

# bram.v carga ./firmware.hex: se genera en este directorio
firmware:
	$(MAKE) -C firmware PREFIX=$(RV_PREFIX)

firmware.hex: firmware/fram_boot.S firmware/fram_boot.ld firmware/bin2hex.py
	$(MAKE) -C firmware PREFIX=$(RV_PREFIX)

# Verifica que existan todas las fuentes
check_deps:
	@for f in $(OBJS); do test -f "$$f" || { echo "FALTA: $$f"; exit 1; }; done
	@echo "Dependencias OK"

# Elaboración rápida (sin síntesis completa): detecta módulos faltantes
check_synth: check_deps firmware.hex
	"$(EQ144_YOSYS)" -Q -T -q -p 'read_verilog -I$(FRAM_RTL) $(OBJS); hierarchy -check -top $(TOP)'

build: $(OBJS) firmware.hex $(TOP).cst $(TOP).sdc
	mkdir -p "$(EQ144_BUILD_DIR)"
	"$(EQ144_YOSYS)" -Q -T -q -l $(EQ144_BUILD_DIR)/$(TOP)_synth.log -p 'read_verilog -I$(FRAM_RTL) $(OBJS); synth_gowin -family gw2a -top $(TOP) -json $(EQ144_BUILD_DIR)/$(TOP)_synth.json; check -assert'
	"$(EQ144_NEXTPNR)" --device GW2AR-LV18EQ144PC8/I7 --top $(TOP) --json $(EQ144_BUILD_DIR)/$(TOP)_synth.json --write $(EQ144_BUILD_DIR)/$(TOP)_pnr.json --sdc $(TOP).sdc --freq 40 --vopt family=GW2A-18C --vopt cst=$(TOP).cst --seed 1 --report $(EQ144_BUILD_DIR)/$(TOP)_report.json --log $(EQ144_BUILD_DIR)/$(TOP)_pnr.log
	"$(EQ144_PACK)" -d GW2A-18C -o $(EQ144_BUILD_DIR)/$(TOP).fs $(EQ144_BUILD_DIR)/$(TOP)_pnr.json

configure: $(EQ144_BUILD_DIR)/fram_hw_test.fs
	"$(EQ144_LOADER)" --cable ft232RL --pins TXD:CTS:RTS:RXD --freq $(EQ144_JTAG_FREQ) $(if $(strip $(EQ144_FTDI_SERIAL)),--ftdi-serial "$(EQ144_FTDI_SERIAL)") --write-sram --bitstream $(EQ144_BUILD_DIR)/$(TOP).fs
#										TDI:TDO:TCK:TMS
#										TXD:CTS:RTS:RXD
#										TXD:CTS:DTR:RXD

flash: $(EQ144_BUILD_DIR)/fram_hw_test.fs
	"$(EQ144_LOADER)" --cable ft232RL --pins TXD:CTS:RTS:RXD --freq $(EQ144_JTAG_FREQ) $(if $(strip $(EQ144_FTDI_SERIAL)),--ftdi-serial "$(EQ144_FTDI_SERIAL)") -f --bitstream $(EQ144_BUILD_DIR)/$(TOP).fs

detect:
	"$(EQ144_LOADER)" --cable ft232RL --pins TXD:CTS:RTS:RXD --freq $(EQ144_JTAG_FREQ) --detect

clean:
	rm -rf $(EQ144_BUILD_DIR)
	$(MAKE) -C firmware clean
