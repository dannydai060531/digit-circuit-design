`timescale 1ns / 1ps

module tb_mcu_core_speed;
    reg clk, rst_n;
    reg [15:0] test_vector_in;
    wire [5:0] rom_addr, verify_ram_addr;
    wire rom_rd_en, ram_we, cnt_start, cnt_stop, done;
    wire [15:0] verify_vector_out;
    wire [7:0] debug_pc;
    wire [15:0] debug_instruction;
    wire [2:0] debug_state;

    mcu_core #(.HAS_ACCEL(1)) uut (
        .clk(clk), .rst_n(rst_n),
        .test_vector_in(test_vector_in),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(verify_ram_addr), .verify_vector_out(verify_vector_out),
        .ram_we(ram_we), .cnt_start(cnt_start), .cnt_stop(cnt_stop), .done(done),
        .debug_pc(debug_pc), .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        .debug_internal_mem_we(), .debug_internal_mem_addr(), .debug_internal_mem_wdata()
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id, i;

    initial begin
        clk = 0; rst_n = 0; test_vector_in = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;

        // ============================================
        // Test 1: HALT still works with HAS_ACCEL=1
        // ============================================
        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = 16'h0000;
        uut.u_imem.mem[0] = 16'hA000;  // HALT
        rst_n = 1; #1;
        i = 0;
        while (!done && i < 200) @(posedge clk) i = i + 1;
        test_id = 1;
        if (done) begin
            $display("[%0d] PASS: HALT works (HAS_ACCEL=1)", test_id);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: No HALT", test_id); fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 2: SORT8 opcode triggers accelerator
        // Load data into internal memory, then SORT8
        // ============================================
        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = 16'h0000;
        // Program:
        // 0: STR to IO_RAM_ADDR  — just a placeholder, we test SORT8 directly
        // Let's write a program that loads data and does SORT8
        // Simplified: MOVL R0,#0; SORT8 R0; HALT
        // Actually SORT8 operates on data_memory[base:base+7]
        // First we need data in data_memory at address 0-7
        // Let's use STR to write data, then SORT8
        //
        // Program:
        // 0: MOVL R0, #0       — base=0
        // 1: MOVL R1, #7       — data to store
        // 2: STR  R1, R0, R0   — mem[0]=7
        // 3: MOVL R1, #3       — mem[1]=3
        // 4: MOVL R2, #1       — offset 1
        // 5: STR  R1, R0, R2   — mem[1]=3
        // 6: MOVL R1, #8       — mem[2]=8
        // 7: ADDI R2, R2, #1   — offset 2
        // 8: STR  R1, R0, R2
        // ... too long. Let's just use backdoor to set data_memory

        // Backdoor: write test data to internal memory
        // Addresses 0-7 get [7,3,8,1,6,4,2,5]
        for (i = 0; i < 64; i = i + 1) uut.u_dm.int_ram[i] = 16'd0;
        uut.u_dm.int_ram[0] = 7;
        uut.u_dm.int_ram[1] = 3;
        uut.u_dm.int_ram[2] = 8;
        uut.u_dm.int_ram[3] = 1;
        uut.u_dm.int_ram[4] = 6;
        uut.u_dm.int_ram[5] = 4;
        uut.u_dm.int_ram[6] = 2;
        uut.u_dm.int_ram[7] = 5;

        // Program: SORT8 R0; HALT (R0=0)
        uut.u_imem.mem[0] = {4'b1110, 4'd0, 4'd0, 4'd0};  // SORT8 R0
        uut.u_imem.mem[1] = 16'hA000;  // HALT

        rst_n = 1; #1;
        i = 0;
        while (!done && i < 500) @(posedge clk) i = i + 1;

        test_id = 2;
        // Check sorted
        if (uut.u_dm.int_ram[0] === 1 && uut.u_dm.int_ram[1] === 2 &&
            uut.u_dm.int_ram[2] === 3 && uut.u_dm.int_ram[3] === 4 &&
            uut.u_dm.int_ram[4] === 5 && uut.u_dm.int_ram[5] === 6 &&
            uut.u_dm.int_ram[6] === 7 && uut.u_dm.int_ram[7] === 8) begin
            $display("[%0d] PASS: SORT8 via MCU opcode sorted [7,3,8,1,6,4,2,5] -> [1..8] (%0d cyc)",
                     test_id, i);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: SORT8 result [%d,%d,%d,%d,%d,%d,%d,%d]",
                test_id, uut.u_dm.int_ram[0], uut.u_dm.int_ram[1],
                uut.u_dm.int_ram[2], uut.u_dm.int_ram[3],
                uut.u_dm.int_ram[4], uut.u_dm.int_ram[5],
                uut.u_dm.int_ram[6], uut.u_dm.int_ram[7]);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        $display("========================================");
        $display("  MCU Core Speed Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end
endmodule
