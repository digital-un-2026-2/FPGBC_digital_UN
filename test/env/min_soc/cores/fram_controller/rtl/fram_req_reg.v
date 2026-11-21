// REQ REG: copia de la petición del procesador (síncrono, flanco +).
// mem_wmask solo dura un ciclo en el FemtoRV, por eso se guarda aquí.

module fram_req_reg (
    input  wire        clk,
    input  wire        blk_rst,
    input  wire        req_ld,
    input  wire [16:0] mem_addr,
    input  wire [3:0]  mem_wmask,
    input  wire [1:0]  i,
    output reg  [16:0] req_addr,
    output wire        lane_en      // req_wmask[i]: hay que escribir el byte i
);

    reg [3:0] req_wmask;

    always @(posedge clk) begin
        if (blk_rst) begin
            req_addr  <= 17'd0;
            req_wmask <= 4'd0;
        end else if (req_ld) begin
            req_addr  <= mem_addr;
            req_wmask <= mem_wmask;
        end
    end

    assign lane_en = req_wmask[i];

endmodule
