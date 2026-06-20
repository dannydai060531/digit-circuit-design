`timescale 1ns / 1ps
module tb_io_test;
    reg clk, rst_n;
    reg [15:0] tvi;
    wire done;
    wire [5:0] rom_addr;
    wire rom_rd_en;

    mcu_core #(.HAS_ACCEL(0)) uut (
        .clk(clk), .rst_n(rst_n), .test_vector_in(tvi),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(), .verify_vector_out(), .ram_we(),
        .cnt_start(), .cnt_stop(), .done(done),
        .debug_pc(), .debug_instruction(), .debug_state(),
        .debug_internal_mem_we(), .debug_internal_mem_addr(), .debug_internal_mem_wdata());

    always #5 clk = ~clk;
    reg [15:0] rom [0:63];
    integer i;
    always @(*) tvi = rom[rom_addr];

    initial begin
        clk = 0; rst_n = 0; tvi = 0;
        for (i=0;i<64;i=i+1) rom[i] = i * 2;  // ROM data: 0,2,4,...,126

        // Program: write IO_ROM_ADDR=5, read IO_ROM_DATA, store to int_RAM[0], HALT
        // 0: MOVL R7,#0x40  = 4740  (IO_ROM_ADDR)
        // 1: MOVL R8,#0x41  = 4841  (IO_ROM_DATA)
        // 2: MOVL R0,#0     = 4000  (base=0)
        // 3: MOVL R1,#5     = 4105  (i=5)
        // 4: STR R1,R7,R0   = 7170  (IO_ROM_ADDR = 5)
        // 5: LDR R2,R8,R0   = 6280  (R2 = IO_ROM_DATA, should be rom[5]=10)
        // 6: STR R2,R0,R0   = 7200  (internal_RAM[0] = R2)
        // 7: HALT           = A000
        rst_n = 0; #20;
        for (i=0;i<256;i=i+1) uut.u_imem.mem[i] = 16'h0000;
        uut.u_imem.mem[0] = 16'h4740;
        uut.u_imem.mem[1] = 16'h4841;
        uut.u_imem.mem[2] = 16'h4000;
        uut.u_imem.mem[3] = 16'h4105;
        uut.u_imem.mem[4] = 16'h7170;  // STR R1,R7,R0: mem[0x40+0]=5
        uut.u_imem.mem[5] = 16'h6280;  // LDR R2,R8,R0: R2=mem[0x41+0]=tvi[5]
        uut.u_imem.mem[6] = 16'h7200;  // STR R2,R0,R0: mem[0+0]=R2
        uut.u_imem.mem[7] = 16'hA000;
        rst_n = 1; #1;

        i = 0;
        while (!done && i < 1000) begin @(posedge clk); i = i + 1; end

        if (done && uut.u_dm.int_ram[0] === 16'd10) begin
            $display("PASS: IO path works! int_ram[0]=10 (rom[5]=10), cycles=%0d", i);
        end else begin
            $display("FAIL: done=%b int_ram[0]=%0d (expected 10), cycles=%0d",
                     done, uut.u_dm.int_ram[0], i);
        end
        $finish;
    end
endmodule
