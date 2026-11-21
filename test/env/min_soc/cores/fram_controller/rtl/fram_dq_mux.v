// DQ MUX: byte que el controlador pone en el bus de datos (combinacional).
//   0: wbyte          (dato hacia la FRAM)
//   1: {0000, banco}  (RAMB)
//   2: 0x0A           (RAMG = habilitar)
//   3: 0x00           (RAMG = deshabilitar)

module fram_dq_mux (
    input  wire [1:0] dq_sel,
    input  wire [7:0] wbyte,
    input  wire [3:0] banco,
    output reg  [7:0] d_out
);

    always @(*) begin
        case (dq_sel)
            2'd1:    d_out = {4'b0000, banco};
            2'd2:    d_out = 8'h0A;
            2'd3:    d_out = 8'h00;
            default: d_out = wbyte;
        endcase
    end

endmodule
