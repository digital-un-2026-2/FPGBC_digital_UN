module test (
  input clk,
  input rst_n,
  output reg tx
);
  
  reg [$clog2(4096*1024):0] tick;

  always @(posedge clk ) begin
    if (!rst_n) begin
      tick = 0;
      tx = 0;
    end
    else if (tick == 4096*1024)begin
       tick = 0;
       tx = ~tx;
    end
    else tick = tick + 1;
  end


endmodule
