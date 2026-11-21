// DATA REG: dato a escribir y palabra leída (síncrono, flanco +).
//
// Lectura: los bytes llegan en orden i = 3 .. 0 y se desplazan a la
// izquierda, así el byte 0 termina en rdata[7:0] (little-endian).
// Escritura: wbyte entrega el byte i de la palabra guardada.

module fram_data_reg (
    input  wire        clk,
    input  wire        blk_rst,
    input  wire        req_ld,
    input  wire [31:0] mem_wdata,
    input  wire        rd_shift,
    input  wire [7:0]  d_in,
    input  wire [1:0]  i,
    output wire [31:0] mem_rdata,
    output wire [7:0]  wbyte
);

    reg [31:0] wdata;
    reg [31:0] rdata;

    always @(posedge clk) begin
        if (blk_rst) begin
            wdata <= 32'd0;
            rdata <= 32'd0;
        end else begin
            if (req_ld)
                wdata <= mem_wdata;
            if (rd_shift)
                rdata <= {rdata[23:0], d_in};
        end
    end

    assign mem_rdata = rdata;
    assign wbyte     = wdata[8*i +: 8];

endmodule
