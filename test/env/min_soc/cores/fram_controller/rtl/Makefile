# Controlador FRAM: simulación y síntesis de prueba.
# Herramientas del entorno pixi de FPGBC_digital_UN (iverilog, vvp, gtkwave, yosys).

SRC  = fram_controller.v
SRC += fram_fsm.v
SRC += fram_timer.v
SRC += fram_byte_counter.v
SRC += fram_req_reg.v
SRC += fram_addr_mapper.v
SRC += fram_addr_out.v
SRC += fram_bank_selector.v
SRC += fram_data_reg.v
SRC += fram_dq_mux.v
SRC += fram_dq_tri.v

TB   = fram_controller_tb.v
TOP  = fram_controller
YOSYS ?= yosys

.PHONY: sim wave synth clean

# Simulación con BENCH definido (nombres de estado en ASCII en la forma de onda)
sim: $(SRC) $(TB) times.vh
	rm -f $(TOP)_tb.vvp $(TOP)_tb.vcd
	iverilog -Wall -Wno-timescale -DBENCH -I. -o $(TOP)_tb.vvp $(TB) $(SRC)
	vvp -n $(TOP)_tb.vvp

wave: sim
	gtkwave $(TOP)_tb.vcd signals_$(TOP)_tb.gtkw &

# Síntesis de prueba para la familia de la consola (GW2A)
synth: $(SRC) times.vh
	"$(YOSYS)" -q -p 'read_verilog -I. $(SRC); synth_gowin -family gw2a -top $(TOP); check -assert; tee -o $(TOP)_synth_stat.txt stat'
	@cat $(TOP)_synth_stat.txt

clean:
	rm -f $(TOP)_tb.vvp $(TOP)_tb.vcd $(TOP)_synth_stat.txt
