EQ144_YOSYS ?= yosys
EQ144_NEXTPNR ?= nextpnr-himbaechel-gowin
EQ144_PACK ?= gowin_pack
EQ144_BUILD_DIR ?= ./gw2ar_eq144_open
EQ144_FTDI_SERIAL ?=
EQ144_JTAG_FREQ ?= 1000000




COMM_OBJS+= cores/cpu/femtorv32_quark_un_irq.v
COMM_OBJS+= cores/uart/perip_uart.v
COMM_OBJS+= cores/uart/uart.v

COMM_OBJS+=cores/bin2bcd/add_sub_c2.v
COMM_OBJS+=cores/bin2bcd/bin2bcd.v
COMM_OBJS+=cores/bin2bcd/mux2.v
COMM_OBJS+=cores/bin2bcd/count.v
COMM_OBJS+=cores/bin2bcd/ctrl_b2b.v  
COMM_OBJS+=cores/bin2bcd/perip_bin2bcd.v
COMM_OBJS+=cores/bin2bcd/lsr4.v
COMM_OBJS+=cores/bin2bcd/reg_msb.v

COMM_OBJS+=cores/bcd2bin/bcd2bin.v
COMM_OBJS+=cores/bcd2bin/perip_bcd2bin.v
COMM_OBJS+=cores/bcd2bin/rsr4.v
COMM_OBJS += cores/bram/bram.v

# --------------------------------------------------------------#
# --------------------------------------------------------------#
# Incluir los archivos que hacen parte del periférico a probar--#
# --------------------------------------------------------------#
# --------------------------------------------------------------#

COMM_OBJS+= cores/test/perip_test.v
COMM_OBJS+= cores/test/mult/mult_32.v
COMM_OBJS+= cores/test/mult/acc.v
COMM_OBJS+= cores/test/mult/comp.v
COMM_OBJS+= cores/test/mult/lsr_mult.v
COMM_OBJS+= cores/test/mult/control_mult2.v
COMM_OBJS+= cores/test/mult/rsr.v

COMM_OBJS +=  SOC.v
OBJS += $(COMM_OBJS)
TOP = SOC

.PHONY: build_gw2ar_eq144 configure_gw2ar_eq144 sim_irq


sim_irq:
	rm -f a.out *.vcd
	iverilog -DBENCH  bench_quark_irq.v $(OBJS)
	vvp a.out
	gtkwave bench.vcd


build_gw2ar_eq144: $(COMM_OBJS) firmware.hex gw2ar_eq144.cst gw2ar_eq144.sdc
	mkdir -p "$(EQ144_BUILD_DIR)"
	"$(EQ144_YOSYS)" -Q -T -q -l $(EQ144_BUILD_DIR)/$(TOP)_synth.log -p 'read_verilog $(COMM_OBJS); synth_gowin -family gw2a -top $(TOP) -json $(EQ144_BUILD_DIR)/$(TOP)_synth.json; check -assert'
	"$(EQ144_NEXTPNR)" --device GW2AR-LV18EQ144PC8/I7 --top $(TOP) --json $(EQ144_BUILD_DIR)/$(TOP)_synth.json --write $(EQ144_BUILD_DIR)/$(TOP)_pnr.json --sdc gw2ar_eq144.sdc --freq 25 --vopt family=GW2A-18C --vopt cst=gw2ar_eq144.cst --seed 1 --report $(EQ144_BUILD_DIR)/$(TOP)_report.json --log $(EQ144_BUILD_DIR)/$(TOP)_pnr.log
	"$(EQ144_PACK)" -d GW2A-18C -o $(EQ144_BUILD_DIR)/$(TOP).fs $(EQ144_BUILD_DIR)/$(TOP)_pnr.json

configure_gw2ar_eq144: build_gw2ar_eq144
	openFPGALoader --cable ft232RL --pins TXD:CTS:DTR:RXD --freq $(EQ144_JTAG_FREQ) $(if $(strip $(EQ144_FTDI_SERIAL)),--ftdi-serial "$(EQ144_FTDI_SERIAL)") --write-sram --bitstream $(EQ144_BUILD_DIR)/$(TOP).fs
#										TDI:TDO:TCK:TMS


TEST_DIR = ./test

test_gowin : test.v
	mkdir -p $(TEST_DIR)
	"$(EQ144_YOSYS)" -Q -T -q -l $(TEST_DIR)/test_synth.log -p 'read_verilog test.v; synth_gowin -family gw2a -top test -json $(TEST_DIR)/test_synth.json; check -assert'
	"$(EQ144_NEXTPNR)" --device GW2AR-LV18EQ144PC8/I7 --top test --json $(TEST_DIR)/test_synth.json --write $(TEST_DIR)/test_pnr.json --sdc test.sdc --freq 40 --vopt family=GW2A-18C --vopt cst=test.cst --seed 1 --report $(TEST_DIR)/test_report.json --log $(TEST_DIR)/test_pnr.log
	"$(EQ144_PACK)" -d GW2A-18C -o $(TEST_DIR)/test.fs $(TEST_DIR)/test_pnr.json

detect:
	openFPGALoader --cable ft232RL --pins TXD:CTS:DTR:RXD --freq $(EQ144_JTAG_FREQ) --detect -f
configure_test :
	openFPGALoader --cable ft232RL --pins TXD:CTS:DTR:RXD --freq $(EQ144_JTAG_FREQ) --write-sram --bitstream $(EQ144_BUILD_DIR)/$(TOP).fs
#										TDI:TDO:TCK:TMS
