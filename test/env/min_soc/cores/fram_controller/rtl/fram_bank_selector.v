// BANK SELECTOR: recuerda el último banco escrito en RAMB (síncrono, flanco +)
// e indica si hay que volver a escribirlo.

module fram_bank_selector (
    input  wire       clk,
    input  wire       blk_rst,
    input  wire [3:0] banco,
    input  wire       bank_ld,
    output wire       banco_cambia
);

    reg [3:0] banco_actual;
    reg       banco_valido;

    always @(posedge clk) begin
        if (blk_rst) begin
            banco_actual <= 4'd0;
            banco_valido <= 1'b0;
        end else if (bank_ld) begin
            banco_actual <= banco;
            banco_valido <= 1'b1;
        end
    end

    assign banco_cambia = !banco_valido || (banco != banco_actual);

endmodule
