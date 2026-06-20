`timescale 1ns / 1ps
module tb_teacher_data;
    reg clk, rst_n;
    reg [15:0] test_vector_in;
    wire done;
    wire [5:0] rom_addr;
    wire rom_rd_en;

    mcu_core #(.HAS_ACCEL(0)) uut (
        .clk(clk), .rst_n(rst_n), .test_vector_in(test_vector_in),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(), .verify_vector_out(), .ram_we(),
        .cnt_start(), .cnt_stop(), .done(done),
        .debug_pc(), .debug_instruction(), .debug_state(),
        .debug_internal_mem_we(), .debug_internal_mem_addr(), .debug_internal_mem_wdata());

    // Mock test_ROM: 640 entries (10 groups x 64)
    reg [15:0] rom_data [0:639];
    reg [15:0] golden [0:639];
    integer i, j, cyc, pass, fail;

    always #5 clk = ~clk;
    always @(*) test_vector_in = rom_data[rom_addr];

    initial begin
        clk = 0; rst_n = 0; test_vector_in = 16'd0; pass = 0; fail = 0;

        // Load teacher's .coe files
        $readmemh("C:/Users/danny/mcu_sort_project/coe/sort_input.mem", rom_data);
        $readmemh("C:/Users/danny/mcu_sort_project/coe/sort_output.mem", golden);

        // Load sort_efficiency.mem into instruction memory
        $readmemh("C:/Users/danny/mcu_sort_project/asm/sort_efficiency.mem", uut.u_imem.mem);

        // Load done, set rst_n

        // Test group 0 (64 elements)
        rst_n = 0; #20; rst_n = 1; #1;

        cyc = 0;
        while (!done && cyc < 100000) begin @(posedge clk); cyc = cyc + 1; end

        if (done) begin
            // Check sorted result
            i = 0;
            for (j = 0; j < 64; j = j + 1) begin
                if (uut.u_dm.int_ram[j] !== golden[j]) i = i + 1;
            end
            if (i == 0) begin
                $display("PASS: Teacher data group 0 sorted correctly (%0d cycles)", cyc);
                pass = pass + 1;
            end else begin
                $display("FAIL: %0d mismatches", i);
                $display("  Expected[0:3]: %d,%d,%d,%d", golden[0], golden[1], golden[2], golden[3]);
                $display("  Got[0:3]:      %d,%d,%d,%d", uut.u_dm.int_ram[0], uut.u_dm.int_ram[1], uut.u_dm.int_ram[2], uut.u_dm.int_ram[3]);
                fail = fail + 1;
            end
        end else begin
            $display("FAIL: Timeout after %0d cycles", cyc);
            fail = fail + 1;
        end

        $display("===== Teacher Data Test: PASS=%0d FAIL=%0d =====", pass, fail);
        if (fail == 0) $display("OVERALL: PASS");
        else $display("OVERALL: FAIL");
        $finish;
    end
endmodule
