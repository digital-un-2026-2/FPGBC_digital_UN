// DQ TRI: pines tri-estado del bus de datos (combinacional).

module fram_dq_tri (
    input  wire [7:0] d_out,
    input  wire       d_oe,
    inout  wire [7:0] d,
    output wire [7:0] d_in
);

    assign d    = d_oe ? d_out : 8'bz;
    assign d_in = d;

endmodule
