// Controlador FRAM (FM28V100 en cartucho MBC5) para el FemtoRV.
// Módulo superior: instancia los bloques del data path (ver data_path.d2).
//
// Interfaz con el procesador: señales mem_* del FemtoRV, sin adaptar.
// Interfaz con el cartucho: a través de los buffers externos de la consola.

module fram_controller (
    input  wire        clk,
    input  wire        rst,           // reset del sistema, activo en alto
    // procesador (FemtoRV)
    input  wire [16:0] mem_addr,      // dirección de byte dentro de los 128 KB
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wmask,
    input  wire        mem_rstrb,
    output wire [31:0] mem_rdata,
    output wire        mem_rbusy,
    output wire        mem_wbusy,
    // cartucho (vía buffers externos)
    output wire [15:0] addr,
    inout  wire [7:0]  d,
    output wire        wr_n,
    output wire        rd_n,
    output wire        cs_n,
    output wire        cmd_oe,        // habilitación del buffer de control
    output wire        data_dir       // 1 = hacia el cartucho, 0 = hacia el controlador
);

    // Señales internas (mismos nombres que en data_path.d2)
    wire        blk_rst;
    wire        req_ld, rd_shift, bank_ld, cnt_ld, cnt_dec;
    wire        tmr_ld, tmr_done;
    wire [2:0]  tmr_sel;
    wire [1:0]  addr_sel, dq_sel;
    wire        i_last, lane_en, banco_cambia;
    wire [1:0]  i;
    wire [16:0] req_addr;
    wire [3:0]  banco;
    wire [15:0] fram_addr;
    wire [7:0]  wbyte, d_out, d_in;
    wire        d_oe;

    fram_fsm u_fsm (
        .clk          (clk),
        .rst          (rst),
        .mem_rstrb    (mem_rstrb),
        .mem_wmask    (mem_wmask),
        .mem_rbusy    (mem_rbusy),
        .mem_wbusy    (mem_wbusy),
        .tmr_done     (tmr_done),
        .i_last       (i_last),
        .lane_en      (lane_en),
        .banco_cambia (banco_cambia),
        .blk_rst      (blk_rst),
        .req_ld       (req_ld),
        .rd_shift     (rd_shift),
        .bank_ld      (bank_ld),
        .cnt_ld       (cnt_ld),
        .cnt_dec      (cnt_dec),
        .tmr_ld       (tmr_ld),
        .tmr_sel      (tmr_sel),
        .addr_sel     (addr_sel),
        .dq_sel       (dq_sel),
        .wr_n         (wr_n),
        .rd_n         (rd_n),
        .cs_n         (cs_n),
        .cmd_oe       (cmd_oe),
        .data_dir     (data_dir),
        .d_oe         (d_oe)
    );

    fram_timer u_timer (
        .clk      (clk),
        .blk_rst  (blk_rst),
        .tmr_ld   (tmr_ld),
        .tmr_sel  (tmr_sel),
        .tmr_done (tmr_done)
    );

    fram_byte_counter u_byte_counter (
        .clk     (clk),
        .blk_rst (blk_rst),
        .cnt_ld  (cnt_ld),
        .cnt_dec (cnt_dec),
        .i       (i),
        .i_last  (i_last)
    );

    fram_req_reg u_req_reg (
        .clk       (clk),
        .blk_rst   (blk_rst),
        .req_ld    (req_ld),
        .mem_addr  (mem_addr),
        .mem_wmask (mem_wmask),
        .i         (i),
        .req_addr  (req_addr),
        .lane_en   (lane_en)
    );

    fram_addr_mapper u_addr_mapper (
        .req_addr  (req_addr),
        .i         (i),
        .banco     (banco),
        .fram_addr (fram_addr)
    );

    fram_addr_out u_addr_out (
        .addr_sel  (addr_sel),
        .fram_addr (fram_addr),
        .addr      (addr)
    );

    fram_bank_selector u_bank_selector (
        .clk          (clk),
        .blk_rst      (blk_rst),
        .banco        (banco),
        .bank_ld      (bank_ld),
        .banco_cambia (banco_cambia)
    );

    fram_data_reg u_data_reg (
        .clk       (clk),
        .blk_rst   (blk_rst),
        .req_ld    (req_ld),
        .mem_wdata (mem_wdata),
        .rd_shift  (rd_shift),
        .d_in      (d_in),
        .i         (i),
        .mem_rdata (mem_rdata),
        .wbyte     (wbyte)
    );

    fram_dq_mux u_dq_mux (
        .dq_sel (dq_sel),
        .wbyte  (wbyte),
        .banco  (banco),
        .d_out  (d_out)
    );

    fram_dq_tri u_dq_tri (
        .d_out (d_out),
        .d_oe  (d_oe),
        .d     (d),
        .d_in  (d_in)
    );

endmodule
