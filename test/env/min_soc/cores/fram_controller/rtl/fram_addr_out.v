// ADDR OUT: dirección que va al cartucho (combinacional).
//   0: fram_addr (acceso a la FRAM)
//   1: 0x4000    (registro RAMB del MBC5)
//   2: 0x0000    (registro RAMG del MBC5)

module fram_addr_out (
    input  wire [1:0]  addr_sel,
    input  wire [15:0] fram_addr,
    output reg  [15:0] addr
);

    always @(*) begin
        case (addr_sel)
            2'd1:    addr = 16'h4000;
            2'd2:    addr = 16'h0000;
            default: addr = fram_addr;
        endcase
    end

endmodule
