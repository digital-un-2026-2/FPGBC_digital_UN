// ADDR MAPPER: separa banco y dirección dentro de 0xA000-0xBFFF (combinacional).

module fram_addr_mapper (
    input  wire [16:0] req_addr,
    input  wire [1:0]  i,
    output wire [3:0]  banco,       // 16 bancos de 8 KB
    output wire [15:0] fram_addr    // {101, offset de palabra, byte}
);

    assign banco     = req_addr[16:13];
    assign fram_addr = {3'b101, req_addr[12:2], i};

endmodule
