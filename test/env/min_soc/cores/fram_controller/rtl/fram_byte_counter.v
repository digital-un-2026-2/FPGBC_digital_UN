// BYTE COUNTER: índice del byte dentro de la palabra (síncrono, flanco +).
// Recorre i = 3 .. 0; el orden descendente permite que DATA REG arme la
// palabra little-endian con un corrimiento a la izquierda.

module fram_byte_counter (
    input  wire       clk,
    input  wire       blk_rst,
    input  wire       cnt_ld,     // i = 3
    input  wire       cnt_dec,    // i = i - 1
    output reg  [1:0] i,
    output wire       i_last      // i == 0
);

    always @(posedge clk) begin
        if (blk_rst || cnt_ld)
            i <= 2'd3;
        else if (cnt_dec)
            i <= i - 2'd1;
    end

    assign i_last = (i == 2'd0);

endmodule
