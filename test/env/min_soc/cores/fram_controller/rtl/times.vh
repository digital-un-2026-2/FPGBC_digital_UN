// Parámetros de tiempo del controlador FRAM.
//
// Los tiempos se dan en ns y el TIMER los convierte a ciclos de reloj:
//     N = ceil(t_ns * f_clk_MHz / 1000)
// Cada estado de espera de las sub-máquinas dura exactamente N ciclos.
// Ajustar FRAM_CLK_MHZ si cambia el reloj del sistema.

`ifndef FRAM_TIMES_VH
`define FRAM_TIMES_VH

// Frecuencia del reloj del controlador (MHz)
`define FRAM_CLK_MHZ    40

// Tiempos del ciclo de bus (ns); ver flow.txt para su justificación
`define FRAM_T_TURN_NS  50   // espera tras subir #RD antes de girar el bus de datos
`define FRAM_T_SU_NS    150  // ADDR y #CS estables antes de #RD / #WR
`define FRAM_T_ACC_NS   200  // #RD en bajo antes de capturar el dato
`define FRAM_T_WP_NS    150  // ancho del pulso #WR
`define FRAM_T_HD_NS    100  // dato y #CS se mantienen tras subir #WR
`define FRAM_T_PC_NS    150  // todo inactivo entre accesos (pre-carga)

// Conversión ns -> ciclos (redondeo hacia arriba)
`define FRAM_CYCLES(t_ns) (((t_ns) * `FRAM_CLK_MHZ + 999) / 1000)

// Códigos de tmr_sel (FSM -> TIMER)
`define TSEL_NONE  3'd0
`define TSEL_TURN  3'd1
`define TSEL_SU    3'd2
`define TSEL_ACC   3'd3
`define TSEL_WP    3'd4
`define TSEL_HD    3'd5
`define TSEL_PC    3'd6

`endif
