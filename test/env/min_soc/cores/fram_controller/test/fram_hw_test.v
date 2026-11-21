`timescale 1ns / 1ps
// SoC de prueba en hardware del controlador FRAM.
//
// Basado en SOC.v de FPGBC_digital_UN/test/env/min_soc: FemtoRV32 (quark),
// BRAM con el firmware, UART por el puerto Link y los periféricos sqrt,
// bin2bcd, bcd2bin y multiplicador (peripheral_test). Se agrega el
// controlador FRAM como periférico mapeado en memoria.
//
// Fuentes: CPU, UART, sqrt, bin2bcd y bcd2bin de min_soc; BRAM (con
// $readmemh) y multiplicador de digital_UN/basic_circuits/test_peripherals.
//
// Mapa de memoria (mem_addr[31:16]), igual al de SOC.v más la FRAM:
//   0x0000          BRAM 4 KB (firmware.hex)                  cs[0]
//   0x0040          UART                                      cs[5]
//   0x0041          sqrt                                      cs[4]
//   0x0042          multiplicador (peripheral_test)           cs[3]
//   0x0043          div      (sin periférico en este SoC)     cs[2]
//   0x0044          bin2bcd                                   cs[1]
//   0x0045          dpRAM    (sin periférico en este SoC)     cs[6]
//   0x0046          bcd2bin                                   cs[7]
//   0x0048 - 0x0049 FRAM del cartucho (128 KB)                cs[8]
//   otro            BRAM
//
// No hay LED ni pin de interrupción libres en esta tarjeta (los pines que usa
// min_soc son D7 y D1 del cartucho), así que se quitaron: la UART reporta el
// resultado e interrupt_request queda en 0.

module fram_hw_test (
    input         clk,          // 40 MHz
    input         resetn,       // botón (activo en bajo)
    input         RXD,          // UART (puerto Link)
    output        TXD,
    // cartucho (vía buffers externos)
    output [15:0] cart_addr,
    inout  [7:0]  cart_d,
    output        cart_wr_n,
    output        cart_rd_n,
    output        cart_cs_n,
    output        cart_cmd_oe,  // habilitación del buffer de control (activo en alto)
    output        cart_data_dir // buffer de datos: 1 = hacia el cartucho
);

   // Reset al encender: mantiene el reset 16 ciclos tras configurar la FPGA
   /*reg [3:0] por = 4'd0;
   always @(posedge clk)
      if (por != 4'hF) por <= por + 4'd1;
  */
   wire sys_resetn = resetn; //& (por == 4'hF);
   wire [31:0] mem_addr;
   reg  [31:0] mem_rdata;
   wire        mem_rstrb;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;
   wire        mem_rbusy, mem_wbusy;

   // ============== Chip select (decodificador de direcciones) ===========
   reg [8:0] cs;

   always @* begin
      case (mem_addr[31:16])
         16'h0040: cs = 9'b000100000;   // UART
         16'h0041: cs = 9'b000010000;   // sqrt
         16'h0042: cs = 9'b000001000;   // multiplicador
         16'h0043: cs = 9'b000000100;   // div   (sin periférico: lee 0)
         16'h0044: cs = 9'b000000010;   // bin2bcd
         16'h0045: cs = 9'b001000000;   // dpRAM (sin periférico: lee 0)
         16'h0046: cs = 9'b010000000;   // bcd2bin
         16'h0048,
         16'h0049: cs = 9'b100000000;   // FRAM (128 KB)
         16'h0000: cs = 9'b000000001;   // BRAM
         default:  cs = 9'b000000001;
      endcase
   end

   wire wr = |mem_wmask;
   wire rd = mem_rstrb;

   FemtoRV32 CPU (
      .clk               (clk),
      .reset             (sys_resetn),
      .mem_addr          (mem_addr),
      .mem_rdata         (mem_rdata),
      .mem_rstrb         (mem_rstrb),
      .mem_wdata         (mem_wdata),
      .mem_wmask         (mem_wmask),
      .mem_rbusy         (mem_rbusy),
      .mem_wbusy         (mem_wbusy),
      .interrupt_request (1'b0)
   );

   // ============== BRAM ===================================================
   wire [31:0] RAM_rdata;

   bram RAM (
      .clk       (clk),
      .mem_addr  (mem_addr),
      .mem_rdata (RAM_rdata),
      .mem_rstrb (cs[0] & rd),
      .mem_wdata (mem_wdata),
      .mem_wmask ({4{cs[0]}} & mem_wmask)
   );

   // ============== Periféricos de min_soc =================================
   wire [31:0] uart_dout;
   wire [31:0] sqrt_dout;
   wire [31:0] test_dout;
   wire [31:0] bin2bcd_dout;
   wire [31:0] bcd2bin_dout;

   peripheral_uart #(
      .clk_freq (40_000_000),
      .baud     (57_600)
   ) per_uart (
      .clk     (clk),
      .rst     (!sys_resetn),
      .d_in    (mem_wdata),
      .cs      (cs[5]),
      .addr    (mem_addr[4:0]),
      .rd      (rd),
      .wr      (wr),
      .d_out   (uart_dout),
      .uart_tx (TXD),
      .uart_rx (RXD),
      .ledout  ()
   );

   peripheral_sqrt sqrt0 (
      .clk   (clk),
      .reset (!sys_resetn),
      .d_in  (mem_wdata[15:0]),
      .cs    (cs[4]),
      .addr  (mem_addr[4:0]),
      .rd    (rd),
      .wr    (wr),
      .d_out (sqrt_dout)
   );

   peripheral_bin2bcd bin2bcd0 (
      .clk   (clk),
      .reset (!sys_resetn),
      .d_in  (mem_wdata[15:0]),
      .cs    (cs[1]),
      .addr  (mem_addr[4:0]),
      .rd    (rd),
      .wr    (wr),
      .d_out (bin2bcd_dout)
   );

   peripheral_bcd2bin bcd2bin0 (
      .clk   (clk),
      .reset (!sys_resetn),
      .d_in  (mem_wdata[19:0]),
      .cs    (cs[7]),
      .addr  (mem_addr[4:0]),
      .rd    (rd),
      .wr    (wr),
      .d_out (bcd2bin_dout)
   );

   peripheral_test mult1 (
      .clk   (clk),
      .reset (!sys_resetn),
      .d_in  (mem_wdata[15:0]),
      .cs    (cs[3]),
      .addr  (mem_addr[4:0]),
      .rd    (rd),
      .wr    (wr),
      .d_out (test_dout)
   );

   // ============== Controlador FRAM ======================================
   wire [31:0] fram_rdata;

   fram_controller FRAM (
      .clk       (clk),
      .rst       (!sys_resetn),
      .mem_addr  (mem_addr[16:0]),
      .mem_wdata (mem_wdata),
      .mem_wmask ({4{cs[8]}} & mem_wmask),
      .mem_rstrb (cs[8] & rd),
      .mem_rdata (fram_rdata),
      .mem_rbusy (mem_rbusy),
      .mem_wbusy (mem_wbusy),
      .addr      (cart_addr),
      .d         (cart_d),
      .wr_n      (cart_wr_n),
      .rd_n      (cart_rd_n),
      .cs_n      (cart_cs_n),
      .cmd_oe    (cart_cmd_oe),
      .data_dir  (cart_data_dir)
   );

   // ============== MUX de lectura =========================================
   always @* begin
      case (cs)
         9'b100000000: mem_rdata = fram_rdata;
         9'b010000000: mem_rdata = bcd2bin_dout;
         9'b000100000: mem_rdata = uart_dout;
         9'b000010000: mem_rdata = sqrt_dout;
         9'b000001000: mem_rdata = test_dout;
         9'b000000010: mem_rdata = bin2bcd_dout;
         9'b000000001: mem_rdata = RAM_rdata;
         default:      mem_rdata = 32'd0;   // div, dpRAM: sin periférico
      endcase
   end

`ifdef BENCH
   // Caracteres enviados a la UART (registro de datos, offset 0x08)
   always @(posedge clk) begin
      if (cs[5] & wr & (mem_addr[4:0] == 5'h08)) begin
         $write("%c", mem_wdata[7:0]);
         $fflush(32'h8000_0001);
      end
   end
`endif

endmodule
