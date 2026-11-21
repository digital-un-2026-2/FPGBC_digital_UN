// TIMER: temporizador de espera de las sub-máquinas de bus (síncrono, flanco +).
//
// Cuenta hacia arriba desde 0. tmr_done se activa cuando el contador llega a
// N(tmr_sel) - 1, de modo que el estado que espera dura exactamente N ciclos.
// El contador vuelve a 0 con tmr_ld o con tmr_done, así que se reinicia solo
// en el mismo flanco en que la sub-máquina cambia de estado (no requiere un
// pulso de carga por transición).

`include "times.vh"

module fram_timer #(
    parameter W = 8                     // ancho del contador
) (
    input  wire       clk,
    input  wire       blk_rst,
    input  wire       tmr_ld,           // 1 = mantener el contador en 0
    input  wire [2:0] tmr_sel,          // espera seleccionada (`TSEL_*)
    output wire       tmr_done
);

    localparam integer N_TURN = `FRAM_CYCLES(`FRAM_T_TURN_NS);
    localparam integer N_SU   = `FRAM_CYCLES(`FRAM_T_SU_NS);
    localparam integer N_ACC  = `FRAM_CYCLES(`FRAM_T_ACC_NS);
    localparam integer N_WP   = `FRAM_CYCLES(`FRAM_T_WP_NS);
    localparam integer N_HD   = `FRAM_CYCLES(`FRAM_T_HD_NS);
    localparam integer N_PC   = `FRAM_CYCLES(`FRAM_T_PC_NS);

    reg [W-1:0] contador;
    reg [W-1:0] n_ciclos;

    always @(*) begin
        case (tmr_sel)
            `TSEL_TURN: n_ciclos = N_TURN;
            `TSEL_SU:   n_ciclos = N_SU;
            `TSEL_ACC:  n_ciclos = N_ACC;
            `TSEL_WP:   n_ciclos = N_WP;
            `TSEL_HD:   n_ciclos = N_HD;
            `TSEL_PC:   n_ciclos = N_PC;
            default:    n_ciclos = 1;
        endcase
    end

    // n_ciclos >= 1 siempre: un tiempo de 0 ns equivale a 1 ciclo
    assign tmr_done = (contador >= n_ciclos - 1);

    always @(posedge clk) begin
        if (blk_rst || tmr_ld || tmr_done)
            contador <= {W{1'b0}};
        else
            contador <= contador + 1'b1;
    end

`ifdef BENCH
    initial begin
        if (N_TURN >= (1 << W) || N_SU >= (1 << W) || N_ACC >= (1 << W) ||
            N_WP   >= (1 << W) || N_HD >= (1 << W) || N_PC  >= (1 << W))
            $display("fram_timer: ERROR, algún tiempo no cabe en %0d bits", W);
    end
`endif

endmodule
