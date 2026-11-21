// FSM del controlador FRAM.
//
// Contiene tres máquinas de estado:
//   - Principal (flanco negativo): secuencia RAMB -> RAMG on -> accesos ->
//     RAMG off, y contacto con el procesador.
//   - ESCRIBIR_BUS y LEER_BUS (flanco positivo, igual que el TIMER y el
//     data path): un ciclo de bus de la Game Boy cada una.
//
// En todas, el estado siguiente se calcula en el bloque síncrono y las
// salidas son combinacionales a partir del estado actual (Moore). Como la
// máquina principal cambia en el flanco negativo, sus salidas ya están
// estables cuando los bloques de flanco positivo las muestrean.
//
// Contacto con las sub-máquinas:
//   llamar_w / llamar_r : la principal pide un ciclo de bus (según su estado).
//   bus_done            : la sub-máquina está en W_FIN / R_FIN (un ciclo);
//                         la principal lo ve en el flanco negativo intermedio.
//
// Si los estados son 5 o menos se codifican en binario; si son más, en
// one-hot.

`include "times.vh"

module fram_fsm (
    input  wire       clk,
    input  wire       rst,            // reset del sistema, activo en alto
    // procesador
    input  wire       mem_rstrb,
    input  wire [3:0] mem_wmask,
    output reg        mem_rbusy,
    output reg        mem_wbusy,
    // estado del data path
    input  wire       tmr_done,
    input  wire       i_last,
    input  wire       lane_en,
    input  wire       banco_cambia,
    // control del data path
    output reg        blk_rst,
    output reg        req_ld,
    output wire       rd_shift,
    output reg        bank_ld,
    output reg        cnt_ld,
    output reg        cnt_dec,
    output wire       tmr_ld,
    output wire [2:0] tmr_sel,
    output reg  [1:0] addr_sel,
    output reg  [1:0] dq_sel,
    // bus del cartucho
    output wire       wr_n,
    output wire       rd_n,
    output wire       cs_n,
    output reg        cmd_oe,
    output wire       data_dir,
    output wire       d_oe
);

    localparam DIR_HACIA_CTRL = 1'b0;   // cartucho -> controlador (B->A)
    localparam DIR_HACIA_CART = 1'b1;   // controlador -> cartucho (A->B)

    localparam OP_ESCRIBIR = 1'b0;
    localparam OP_LEER     = 1'b1;

    // Señales internas entre la máquina principal y las sub-máquinas
    reg  llamar_w, llamar_r;
    reg  cs_par;                         // #CS que usa ESCRIBIR_BUS
    wire bus_done;

    // ==================================================================
    // Máquina principal (flanco negativo), 10 estados -> one-hot
    // ==================================================================
    localparam RESET     = 10'b0000000001;
    localparam REPOSO    = 10'b0000000010;
    localparam BANCO     = 10'b0000000100;
    localparam RAMB      = 10'b0000001000;
    localparam RAMG_ON   = 10'b0000010000;
    localparam LEER_BYTE = 10'b0000100000;
    localparam ESC_CHK   = 10'b0001000000;
    localparam ESC_BYTE  = 10'b0010000000;
    localparam SIG_BYTE  = 10'b0100000000;
    localparam RAMG_OFF  = 10'b1000000000;

    reg [9:0] state;
    reg       op;

    // Estado siguiente (síncrono)
    always @(negedge clk) begin
        if (rst) begin
            state <= RESET;
            op    <= OP_ESCRIBIR;
        end else begin
            case (state)
                RESET:
                    state <= REPOSO;
                REPOSO:
                    if (mem_rstrb) begin
                        op    <= OP_LEER;
                        state <= BANCO;
                    end else if (mem_wmask != 4'd0) begin
                        op    <= OP_ESCRIBIR;
                        state <= BANCO;
                    end
                BANCO:
                    state <= banco_cambia ? RAMB : RAMG_ON;
                RAMB:
                    if (bus_done) state <= RAMG_ON;
                RAMG_ON:
                    if (bus_done) state <= (op == OP_LEER) ? LEER_BYTE : ESC_CHK;
                LEER_BYTE:
                    if (bus_done) state <= i_last ? RAMG_OFF : SIG_BYTE;
                ESC_CHK:
                    if (lane_en)  state <= ESC_BYTE;
                    else          state <= i_last ? RAMG_OFF : SIG_BYTE;
                ESC_BYTE:
                    if (bus_done) state <= i_last ? RAMG_OFF : SIG_BYTE;
                SIG_BYTE:
                    state <= (op == OP_LEER) ? LEER_BYTE : ESC_CHK;
                RAMG_OFF:
                    if (bus_done) state <= REPOSO;
                default:            // estado inválido (p. ej. registros en 0
                    state <= RESET; // al configurar la FPGA)
            endcase
        end
    end

    // Salidas (combinacionales según el estado actual)
    always @(*) begin
        blk_rst   = 1'b0;
        cmd_oe    = 1'b1;
        mem_rbusy = 1'b0;
        mem_wbusy = 1'b0;
        req_ld    = 1'b0;
        bank_ld   = 1'b0;
        cnt_ld    = 1'b0;
        cnt_dec   = 1'b0;
        addr_sel  = 2'd0;               // fram_addr
        dq_sel    = 2'd0;               // wbyte
        cs_par    = 1'b1;
        llamar_w  = 1'b0;
        llamar_r  = 1'b0;

        if (state != RESET && state != REPOSO) begin
            mem_rbusy = (op == OP_LEER);
            mem_wbusy = (op == OP_ESCRIBIR);
        end

        case (state)
            RESET: begin
                blk_rst = 1'b1;
                cmd_oe  = 1'b0;
            end
            BANCO:
                req_ld = 1'b1;
            RAMB: begin
                bank_ld  = 1'b1;
                addr_sel = 2'd1;        // 0x4000
                dq_sel   = 2'd1;        // {0000, banco}
                llamar_w = 1'b1;
            end
            RAMG_ON: begin
                cnt_ld   = 1'b1;
                addr_sel = 2'd2;        // 0x0000
                dq_sel   = 2'd2;        // 0x0A
                llamar_w = 1'b1;
            end
            LEER_BYTE:
                llamar_r = 1'b1;
            ESC_BYTE: begin
                cs_par   = 1'b0;
                llamar_w = 1'b1;
            end
            SIG_BYTE:
                cnt_dec = 1'b1;
            RAMG_OFF: begin
                addr_sel = 2'd2;        // 0x0000
                dq_sel   = 2'd3;        // 0x00
                llamar_w = 1'b1;
            end
            default: ;
        endcase
    end

    // ==================================================================
    // Sub-máquina ESCRIBIR_BUS (flanco positivo), 7 estados -> one-hot
    // ==================================================================
    localparam W_IDLE = 7'b0000001;
    localparam W_TURN = 7'b0000010;
    localparam W_SU   = 7'b0000100;
    localparam W_WP   = 7'b0001000;
    localparam W_HD   = 7'b0010000;
    localparam W_PC   = 7'b0100000;
    localparam W_FIN  = 7'b1000000;

    reg [6:0] w_state;

    always @(posedge clk) begin
        if (blk_rst)
            w_state <= W_IDLE;
        else begin
            case (w_state)
                W_IDLE: if (llamar_w) w_state <= W_TURN;
                W_TURN: if (tmr_done) w_state <= W_SU;
                W_SU:   if (tmr_done) w_state <= W_WP;
                W_WP:   if (tmr_done) w_state <= W_HD;
                W_HD:   if (tmr_done) w_state <= W_PC;
                W_PC:   if (tmr_done) w_state <= W_FIN;
                W_FIN:  w_state <= W_IDLE;
                default: w_state <= W_IDLE;
            endcase
        end
    end

    reg       w_wr_n, w_cs_n, w_d_oe, w_dir, w_tmr_ld, w_done;
    reg [2:0] w_tmr_sel;

    always @(*) begin
        w_wr_n    = 1'b1;
        w_cs_n    = 1'b1;
        w_d_oe    = 1'b0;
        w_dir     = DIR_HACIA_CTRL;
        w_tmr_ld  = 1'b0;
        w_tmr_sel = `TSEL_NONE;
        w_done    = 1'b0;
        case (w_state)
            W_IDLE: w_tmr_ld = 1'b1;
            W_TURN: w_tmr_sel = `TSEL_TURN;
            W_SU: begin
                w_cs_n    = cs_par;
                w_d_oe    = 1'b1;
                w_dir     = DIR_HACIA_CART;
                w_tmr_sel = `TSEL_SU;
            end
            W_WP: begin
                w_wr_n    = 1'b0;
                w_cs_n    = cs_par;
                w_d_oe    = 1'b1;
                w_dir     = DIR_HACIA_CART;
                w_tmr_sel = `TSEL_WP;
            end
            W_HD: begin
                w_cs_n    = cs_par;
                w_d_oe    = 1'b1;
                w_dir     = DIR_HACIA_CART;
                w_tmr_sel = `TSEL_HD;
            end
            W_PC:  w_tmr_sel = `TSEL_PC;
            W_FIN: begin
                w_tmr_ld = 1'b1;
                w_done   = 1'b1;
            end
            default: w_tmr_ld = 1'b1;
        endcase
    end

    // ==================================================================
    // Sub-máquina LEER_BUS (flanco positivo), 6 estados -> one-hot
    // ==================================================================
    localparam R_IDLE = 6'b000001;
    localparam R_SU   = 6'b000010;
    localparam R_ACC  = 6'b000100;
    localparam R_CAP  = 6'b001000;
    localparam R_PC   = 6'b010000;
    localparam R_FIN  = 6'b100000;

    reg [5:0] r_state;

    always @(posedge clk) begin
        if (blk_rst)
            r_state <= R_IDLE;
        else begin
            case (r_state)
                R_IDLE: if (llamar_r) r_state <= R_SU;
                R_SU:   if (tmr_done) r_state <= R_ACC;
                R_ACC:  if (tmr_done) r_state <= R_CAP;
                R_CAP:  r_state <= R_PC;
                R_PC:   if (tmr_done) r_state <= R_FIN;
                R_FIN:  r_state <= R_IDLE;
                default: r_state <= R_IDLE;
            endcase
        end
    end

    reg       r_rd_n, r_cs_n, r_tmr_ld, r_done, r_shift;
    reg [2:0] r_tmr_sel;

    always @(*) begin
        r_rd_n    = 1'b1;
        r_cs_n    = 1'b1;
        r_tmr_ld  = 1'b0;
        r_tmr_sel = `TSEL_NONE;
        r_done    = 1'b0;
        r_shift   = 1'b0;
        case (r_state)
            R_IDLE: r_tmr_ld = 1'b1;
            R_SU: begin
                r_cs_n    = 1'b0;
                r_tmr_sel = `TSEL_SU;
            end
            R_ACC: begin
                r_cs_n    = 1'b0;
                r_rd_n    = 1'b0;
                r_tmr_sel = `TSEL_ACC;
            end
            R_CAP: begin                 // un ciclo: DATA REG captura D_IN
                r_cs_n   = 1'b0;         // al final de este estado
                r_rd_n   = 1'b0;
                r_shift  = 1'b1;
                r_tmr_ld = 1'b1;
            end
            R_PC:  r_tmr_sel = `TSEL_PC;
            R_FIN: begin
                r_tmr_ld = 1'b1;
                r_done   = 1'b1;
            end
            default: r_tmr_ld = 1'b1;
        endcase
    end

    // ==================================================================
    // Combinación de las salidas de las sub-máquinas
    // (la inactiva entrega valores neutros)
    // ==================================================================
    assign bus_done = w_done | r_done;
    assign tmr_ld   = w_tmr_ld & r_tmr_ld;   // la inactiva pide 1 (IDLE)
    assign tmr_sel  = w_tmr_sel | r_tmr_sel; // la inactiva entrega TSEL_NONE
    assign rd_shift = r_shift;
    assign wr_n     = w_wr_n;
    assign rd_n     = r_rd_n;
    assign cs_n     = w_cs_n & r_cs_n;
    assign d_oe     = w_d_oe;
    assign data_dir = w_dir;

`ifdef BENCH
    reg [8*40:1] state_name;
    always @(*) begin
        case (state)
            RESET:     state_name = "RESET";
            REPOSO:    state_name = "REPOSO";
            BANCO:     state_name = "BANCO";
            RAMB:      state_name = "RAMB";
            RAMG_ON:   state_name = "RAMG_ON";
            LEER_BYTE: state_name = "LEER_BYTE";
            ESC_CHK:   state_name = "ESC_CHK";
            ESC_BYTE:  state_name = "ESC_BYTE";
            SIG_BYTE:  state_name = "SIG_BYTE";
            RAMG_OFF:  state_name = "RAMG_OFF";
            default:   state_name = "INVALIDO";
        endcase
    end

    reg [8*40:1] w_state_name;
    always @(*) begin
        case (w_state)
            W_IDLE:  w_state_name = "W_IDLE";
            W_TURN:  w_state_name = "W_TURN";
            W_SU:    w_state_name = "W_SU";
            W_WP:    w_state_name = "W_WP";
            W_HD:    w_state_name = "W_HD";
            W_PC:    w_state_name = "W_PC";
            W_FIN:   w_state_name = "W_FIN";
            default: w_state_name = "INVALIDO";
        endcase
    end

    reg [8*40:1] r_state_name;
    always @(*) begin
        case (r_state)
            R_IDLE:  r_state_name = "R_IDLE";
            R_SU:    r_state_name = "R_SU";
            R_ACC:   r_state_name = "R_ACC";
            R_CAP:   r_state_name = "R_CAP";
            R_PC:    r_state_name = "R_PC";
            R_FIN:   r_state_name = "R_FIN";
            default: r_state_name = "INVALIDO";
        endcase
    end
`endif

endmodule
