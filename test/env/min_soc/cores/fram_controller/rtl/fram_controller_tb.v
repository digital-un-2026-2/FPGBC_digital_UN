// Testbench del controlador FRAM.
//
// - Reloj de `FRAM_CLK_MHZ (40 MHz -> 25 ns).
// - El procesador se modela como el FemtoRV: mem_rstrb / mem_wmask duran un
//   ciclo y se espera mem_*busy = 1 en el flanco siguiente.
// - Se modelan los buffers externos y el cartucho (MBC5 con RAMB / RAMG y
//   FRAM de 128 KB, decodificación según la Hipótesis 1). Con CMD_OE = 0 el
//   cartucho ve #WR / #RD / #CS en 0, como lo harían los divisores resistivos.
// - Se verifican los tiempos del bus contra times.vh y los choques en el bus
//   de datos.
// - No se usa wait: toda espera es un ciclo con límite y además hay un
//   watchdog global, para que la simulación nunca se cuelgue.
//
// Casos: 3 escrituras (palabra, byte, media palabra) y 3 lecturas (con cambio
// de banco y con el banco ya cargado).

`timescale 1ns/1ps
`include "times.vh"

module fram_controller_tb;

    localparam real    T_CLK      = 1000.0 / `FRAM_CLK_MHZ;  // ns
    localparam integer MAX_CICLOS = 2000;                    // límite por operación
    localparam real    T_WATCHDOG = 200000.0;                // ns
    localparam real    EPS        = 0.001;                   // tolerancia (ns)

    localparam DIR_HACIA_CTRL = 1'b0;
    localparam DIR_HACIA_CART = 1'b1;

    // ------------------------------------------------------------------
    // Reloj, reset y procesador
    // ------------------------------------------------------------------
    reg clk = 1'b0;
    always #(T_CLK / 2.0) clk = ~clk;

    reg         rst;
    reg  [16:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wmask;
    reg         mem_rstrb;
    wire [31:0] mem_rdata;
    wire        mem_rbusy, mem_wbusy;

    // Lado cartucho del controlador
    wire [15:0] addr;
    wire [7:0]  d;          // pines de la FPGA
    wire        wr_n, rd_n, cs_n, cmd_oe, data_dir;

    fram_controller dut (
        .clk       (clk),
        .rst       (rst),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wmask (mem_wmask),
        .mem_rstrb (mem_rstrb),
        .mem_rdata (mem_rdata),
        .mem_rbusy (mem_rbusy),
        .mem_wbusy (mem_wbusy),
        .addr      (addr),
        .d         (d),
        .wr_n      (wr_n),
        .rd_n      (rd_n),
        .cs_n      (cs_n),
        .cmd_oe    (cmd_oe),
        .data_dir  (data_dir)
    );

    // ------------------------------------------------------------------
    // Buffers externos
    // ------------------------------------------------------------------
    wire [7:0] d_cart;      // bus de datos del lado del cartucho

    // Buffer de datos: solo maneja el lado que indica DATA_DIR
    assign d_cart = (data_dir === DIR_HACIA_CART) ? d      : 8'bz;
    assign d      = (data_dir === DIR_HACIA_CTRL) ? d_cart : 8'bz;

    // Buffer de control: deshabilitado -> los divisores llevan las líneas a 0
    wire c_wr_n = cmd_oe ? wr_n : 1'b0;
    wire c_rd_n = cmd_oe ? rd_n : 1'b0;
    wire c_cs_n = cmd_oe ? cs_n : 1'b0;

    // ------------------------------------------------------------------
    // Modelo del cartucho: MBC5 (RAMG, RAMB) + FRAM 128 KB
    // ------------------------------------------------------------------
    reg [7:0] ramg;
    reg [3:0] ramb;
    reg [7:0] fram [0:131071];

    wire en_ram  = (addr[15:13] == 3'b101);
    wire ram_sel = (ramg == 8'h0A) && !c_cs_n && en_ram;     // Hipótesis 1
    wire [16:0] fram_idx = {ramb, addr[12:0]};

    assign d_cart = (ram_sel && !c_rd_n) ? fram[fram_idx] : 8'bz;

    // Contadores de operaciones en el bus (para verificar cada caso)
    integer n_ramb = 0, n_ramg_on = 0, n_ramg_off = 0, n_fram_w = 0, n_fram_r = 0;
    reg     checks_on = 1'b0;
    integer errores   = 0;

    // El MBC5 y la FRAM capturan el dato en el flanco de subida de #WR
    always @(posedge c_wr_n) begin
        if (addr[15:13] == 3'b000) begin                    // 0x0000-0x1FFF
            ramg <= d_cart;
            if (checks_on) begin
                if (d_cart == 8'h0A) n_ramg_on  = n_ramg_on + 1;
                else                 n_ramg_off = n_ramg_off + 1;
            end
        end else if (addr[15:13] == 3'b010) begin           // 0x4000-0x5FFF
            ramb <= d_cart[3:0];
            if (checks_on) n_ramb = n_ramb + 1;
        end else if (ram_sel) begin                         // 0xA000-0xBFFF
            fram[fram_idx] <= d_cart;
            if (checks_on) n_fram_w = n_fram_w + 1;
        end
    end

    always @(posedge c_rd_n)
        if (checks_on && ram_sel) n_fram_r = n_fram_r + 1;

    // ------------------------------------------------------------------
    // Verificación de tiempos y choques en el bus
    // ------------------------------------------------------------------
    real t_addr = 0.0, t_cs_fall = 0.0, t_cs_rise = -1.0e9;
    real t_wr_fall = 0.0, t_wr_rise = 0.0, t_rd_fall = 0.0;
    reg  hubo_wr_fram = 1'b0;

    task error;
        input [8*80:1] msg;
        begin
            errores = errores + 1;
            $display("[%0t] ERROR: %0s", $realtime, msg);
        end
    endtask

    always @(addr) begin
        if (checks_on && (!c_wr_n || !c_rd_n))
            error("ADDR cambia con #WR o #RD activos");
        t_addr = $realtime;
    end

    always @(negedge c_cs_n) begin
        if (checks_on && ($realtime - t_cs_rise) < `FRAM_T_PC_NS - EPS)
            error("#CS inactivo menos de T_PC entre accesos");
        t_cs_fall = $realtime;
    end

    always @(posedge c_cs_n) begin
        if (checks_on && hubo_wr_fram && ($realtime - t_wr_rise) < `FRAM_T_HD_NS - EPS)
            error("#CS sube antes de T_HD tras #WR");
        hubo_wr_fram = 1'b0;
        t_cs_rise    = $realtime;
    end

    always @(negedge c_wr_n) begin
        if (checks_on) begin
            if (($realtime - t_addr) < `FRAM_T_SU_NS - EPS)
                error("ADDR estable menos de T_SU antes de #WR");
            if (!c_cs_n && ($realtime - t_cs_fall) < `FRAM_T_SU_NS - EPS)
                error("#CS activo menos de T_SU antes de #WR");
            if (!c_rd_n)
                error("#WR y #RD activos a la vez");
        end
        t_wr_fall = $realtime;
    end

    always @(posedge c_wr_n) begin
        if (checks_on) begin
            if (($realtime - t_wr_fall) < `FRAM_T_WP_NS - EPS)
                error("pulso #WR menor que T_WP");
            if (^d_cart === 1'bx)
                error("dato desconocido en el flanco de subida de #WR");
            hubo_wr_fram = !c_cs_n;
        end
        t_wr_rise = $realtime;
    end

    always @(d_cart)
        if (checks_on && !c_wr_n)
            error("el dato cambia con #WR en bajo");

    always @(negedge c_rd_n) begin
        if (checks_on && ($realtime - t_cs_fall) < `FRAM_T_SU_NS - EPS)
            error("#CS activo menos de T_SU antes de #RD");
        t_rd_fall = $realtime;
    end

    always @(posedge c_rd_n)
        if (checks_on && ($realtime - t_rd_fall) < `FRAM_T_ACC_NS - EPS)
            error("#RD en bajo menos de T_ACC");

    // Choques: la FPGA y el buffer de datos no deben manejar el mismo lado
    always @(posedge clk or negedge clk) begin
        if (checks_on) begin
            if (dut.d_oe && data_dir === DIR_HACIA_CTRL)
                error("choque: FPGA maneja D con DATA_DIR = HACIA_CTRL");
            if (ram_sel && !c_rd_n && data_dir === DIR_HACIA_CART)
                error("choque: cartucho y buffer manejan el bus del cartucho");
        end
    end

    // ------------------------------------------------------------------
    // Utilidades
    // ------------------------------------------------------------------
    function [7:0] patron;              // contenido inicial de la FRAM
        input [16:0] a;
        patron = a[7:0] ^ a[15:8] ^ {7'd0, a[16]} ^ 8'hA5;
    endfunction

    function integer popcount4;
        input [3:0] m;
        popcount4 = m[0] + m[1] + m[2] + m[3];
    endfunction

    // Lectura como el FemtoRV: mem_rstrb un ciclo, mem_rbusy en el siguiente
    task cpu_leer;
        input  [16:0] a;
        output [31:0] dato;
        integer k;
        reg     listo;
        begin
            @(posedge clk);
            mem_addr  <= a;
            mem_rstrb <= 1'b1;
            @(posedge clk);
            mem_rstrb <= 1'b0;
            if (mem_rbusy !== 1'b1)
                error("mem_rbusy no se activa en el ciclo siguiente a mem_rstrb");
            listo = 1'b0;
            for (k = 0; k < MAX_CICLOS && !listo; k = k + 1) begin
                @(posedge clk);
                if (mem_rbusy === 1'b0) listo = 1'b1;
            end
            if (!listo) error("timeout esperando mem_rbusy = 0");
            dato = mem_rdata;
        end
    endtask

    // Escritura como el FemtoRV: mem_wmask un ciclo, mem_wbusy en el siguiente
    task cpu_escribir;
        input [16:0] a;
        input [31:0] dato;
        input [3:0]  mascara;
        integer k;
        reg     listo;
        begin
            @(posedge clk);
            mem_addr  <= a;
            mem_wdata <= dato;
            mem_wmask <= mascara;
            @(posedge clk);
            mem_wmask <= 4'd0;
            if (mem_wbusy !== 1'b1)
                error("mem_wbusy no se activa en el ciclo siguiente a mem_wmask");
            listo = 1'b0;
            for (k = 0; k < MAX_CICLOS && !listo; k = k + 1) begin
                @(posedge clk);
                if (mem_wbusy === 1'b0) listo = 1'b1;
            end
            if (!listo) error("timeout esperando mem_wbusy = 0");
        end
    endtask

    // Contadores antes de cada operación
    integer c_ramb, c_on, c_off, c_w, c_r;
    task foto;
        begin
            c_ramb = n_ramb; c_on = n_ramg_on; c_off = n_ramg_off;
            c_w = n_fram_w;  c_r = n_fram_r;
        end
    endtask

    // Verifica la secuencia de bus de una operación
    task verificar_bus;
        input [8*16:1] caso;
        input integer  esp_ramb;     // escrituras a RAMB esperadas
        input integer  esp_w;        // escrituras a la FRAM esperadas
        input integer  esp_r;        // lecturas a la FRAM esperadas
        begin
            if (n_ramb - c_ramb != esp_ramb) begin
                errores = errores + 1;
                $display("  %0s: escrituras a RAMB = %0d, esperadas %0d", caso, n_ramb - c_ramb, esp_ramb);
            end
            if (n_ramg_on - c_on != 1 || n_ramg_off - c_off != 1) begin
                errores = errores + 1;
                $display("  %0s: RAMG on/off = %0d/%0d, esperado 1/1", caso, n_ramg_on - c_on, n_ramg_off - c_off);
            end
            if (ramg !== 8'h00) begin
                errores = errores + 1;
                $display("  %0s: la RAM queda habilitada (RAMG = %h)", caso, ramg);
            end
            if (n_fram_w - c_w != esp_w || n_fram_r - c_r != esp_r) begin
                errores = errores + 1;
                $display("  %0s: accesos FRAM esc/lec = %0d/%0d, esperados %0d/%0d",
                         caso, n_fram_w - c_w, n_fram_r - c_r, esp_w, esp_r);
            end
        end
    endtask

    task verificar_byte;
        input [8*16:1] caso;
        input [16:0]   a;
        input [7:0]    esperado;
        begin
            if (fram[a] !== esperado) begin
                errores = errores + 1;
                $display("  %0s: FRAM[%05h] = %02h, esperado %02h", caso, a, fram[a], esperado);
            end
        end
    endtask

    task verificar_lectura;
        input [8*16:1] caso;
        input [31:0]   leido;
        input [31:0]   esperado;
        begin
            if (leido !== esperado) begin
                errores = errores + 1;
                $display("  %0s: mem_rdata = %08h, esperado %08h", caso, leido, esperado);
            end
        end
    endtask

    task reportar;
        input [8*16:1] caso;
        input integer  err_antes;
        begin
            if (errores == err_antes) $display("  %0s: OK", caso);
            else                      $display("  %0s: FALLA", caso);
        end
    endtask

    // ------------------------------------------------------------------
    // Watchdog
    // ------------------------------------------------------------------
    initial begin
        #(T_WATCHDOG);
        $display("ERROR: watchdog, la simulación no terminó en %0.0f ns", T_WATCHDOG);
        $fatal(1);
    end

    // ------------------------------------------------------------------
    // Secuencia de prueba
    // ------------------------------------------------------------------
    integer    k, e;
    reg [31:0] leido;

    initial begin
        $timeformat(-9, 1, " ns", 0);
        $dumpfile("fram_controller_tb.vcd");
        $dumpvars(0, fram_controller_tb);

        for (k = 0; k < 131072; k = k + 1)
            fram[k] = patron(k);
        ramg = 8'h00;
        ramb = 4'h0;

        rst       = 1'b1;
        mem_addr  = 17'd0;
        mem_wdata = 32'd0;
        mem_wmask = 4'd0;
        mem_rstrb = 1'b0;

        repeat (4) @(posedge clk);
        rst <= 1'b0;
        repeat (4) @(posedge clk);

        $display("Tiempos (ciclos de %0.1f ns): TURN=%0d SU=%0d ACC=%0d WP=%0d HD=%0d PC=%0d",
                 T_CLK,
                 `FRAM_CYCLES(`FRAM_T_TURN_NS), `FRAM_CYCLES(`FRAM_T_SU_NS),
                 `FRAM_CYCLES(`FRAM_T_ACC_NS),  `FRAM_CYCLES(`FRAM_T_WP_NS),
                 `FRAM_CYCLES(`FRAM_T_HD_NS),   `FRAM_CYCLES(`FRAM_T_PC_NS));

        // Estado de reposo tras el reset
        if (wr_n !== 1'b1 || rd_n !== 1'b1 || cs_n !== 1'b1 || cmd_oe !== 1'b1 ||
            data_dir !== DIR_HACIA_CTRL || mem_rbusy !== 1'b0 || mem_wbusy !== 1'b0)
            error("salidas de reposo incorrectas tras el reset");
        checks_on = 1'b1;

        // ---------------- Escrituras ----------------
        // E1: palabra completa, banco 0 (primer acceso: se escribe RAMB)
        e = errores; foto;
        cpu_escribir(17'h00010, 32'hDEADBEEF, 4'b1111);
        verificar_bus("E1 palabra", 1, 4, 0);
        verificar_byte("E1 palabra", 17'h00010, 8'hEF);
        verificar_byte("E1 palabra", 17'h00011, 8'hBE);
        verificar_byte("E1 palabra", 17'h00012, 8'hAD);
        verificar_byte("E1 palabra", 17'h00013, 8'hDE);
        reportar("E1 palabra", e);

        // E2: byte (sb en 0x0A005), banco 5; los otros 3 bytes no cambian
        e = errores; foto;
        cpu_escribir(17'h0A005, 32'h5A5A5A5A, 4'b0010);
        verificar_bus("E2 byte", 1, 1, 0);
        verificar_byte("E2 byte", 17'h0A004, patron(17'h0A004));
        verificar_byte("E2 byte", 17'h0A005, 8'h5A);
        verificar_byte("E2 byte", 17'h0A006, patron(17'h0A006));
        verificar_byte("E2 byte", 17'h0A007, patron(17'h0A007));
        reportar("E2 byte", e);

        // E3: media palabra alta (sh en 0x1FFFE), banco 15
        e = errores; foto;
        cpu_escribir(17'h1FFFE, 32'hBEEF0000, 4'b1100);
        verificar_bus("E3 media", 1, 2, 0);
        verificar_byte("E3 media", 17'h1FFFC, patron(17'h1FFFC));
        verificar_byte("E3 media", 17'h1FFFD, patron(17'h1FFFD));
        verificar_byte("E3 media", 17'h1FFFE, 8'hEF);
        verificar_byte("E3 media", 17'h1FFFF, 8'hBE);
        reportar("E3 media", e);

        // ---------------- Lecturas ----------------
        // L1: lo escrito en E1; cambio de banco 15 -> 0
        e = errores; foto;
        cpu_leer(17'h00010, leido);
        verificar_bus("L1 cambio banco", 1, 0, 4);
        verificar_lectura("L1 cambio banco", leido, 32'hDEADBEEF);
        reportar("L1 cambio banco", e);

        // L2: mismo banco 0 (no se reescribe RAMB), contenido inicial
        e = errores; foto;
        cpu_leer(17'h00100, leido);
        verificar_bus("L2 mismo banco", 0, 0, 4);
        verificar_lectura("L2 mismo banco", leido,
                          {patron(17'h00103), patron(17'h00102),
                           patron(17'h00101), patron(17'h00100)});
        reportar("L2 mismo banco", e);

        // L3: palabra de E3 (dos bytes escritos y dos originales), banco 15
        e = errores; foto;
        cpu_leer(17'h1FFFC, leido);
        verificar_bus("L3 banco 15", 1, 0, 4);
        verificar_lectura("L3 banco 15", leido,
                          {8'hBE, 8'hEF, patron(17'h1FFFD), patron(17'h1FFFC)});
        reportar("L3 banco 15", e);

        repeat (10) @(posedge clk);

        if (errores == 0) begin
            $display("RESULTADO: PASA (6 casos)");
            $finish;
        end else begin
            $display("RESULTADO: FALLA (%0d errores)", errores);
            $fatal(1);
        end
    end

endmodule
