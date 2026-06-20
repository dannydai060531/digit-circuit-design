`timescale 1ns / 1ps

module tb_mcu_core_efficiency;
    reg clk, rst_n;
    reg [15:0] test_vector_in;
    wire [5:0] rom_addr, verify_ram_addr;
    wire rom_rd_en, ram_we, cnt_start, cnt_stop, done;
    wire [15:0] verify_vector_out;
    wire [7:0] debug_pc;
    wire [15:0] debug_instruction;
    wire [2:0] debug_state;

    mcu_core #(.HAS_ACCEL(0)) uut (
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
    integer pass_cnt, fail_cnt, test_id;
    reg [15:0] imem [0:255];
    integer i;

    initial begin
        clk = 0; rst_n = 0; test_vector_in = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;

        // Test 1 program: MOVL R0,#0; HALT
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = 16'h0000;
        uut.u_imem.mem[0] = 16'h4000;
        uut.u_imem.mem[1] = 16'hA000;
        #25 rst_n = 1; #1;

        // Test 1: Start from reset, expect HALT eventually
        test_id = 1;
        i = 0;
        while (!done && i < 200) begin
            @(posedge clk); i = i + 1;
            if (i <= 15) $display("  cycle %0d: PC=%0d instr=%h state=%d halt=%b done=%b",
                i, debug_pc, debug_instruction, debug_state, uut.halt, done);
        end
        if (done) begin
            $display("[%0d] PASS: HALT reached at cycle %0d, PC=%0d", test_id, i, debug_pc);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: Timeout, no HALT", test_id);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 2: Simple addition program
        // ============================================
        rst_n = 0; #20;
        // Load program BEFORE releasing reset
        for (i = 0; i < 256; i = i + 1) imem[i] = 16'h0000;
        imem[0] = 16'h4105;  // MOVL R1, #5
        imem[1] = 16'hC113;  // ADDI R1, R1, #3
        imem[2] = 16'hA000;  // HALT
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = imem[i];
        rst_n = 1; #1;

        test_id = 2;
        i = 0;
        while (!done && i < 200) begin
            @(posedge clk); i = i + 1;
            if (i <= 20)
                $display("  cyc%0d PC=%0d IR=%h st=%0d rf_wen=%b rf_wa=%0d rf_wd=%h R1=%0d alu_op=%0d alu_r=%h",
                    i, debug_pc, debug_instruction, debug_state,
                    uut.u_ctrl.reg_wen, uut.u_ctrl.reg_write_addr,
                    uut.reg_wdata, uut.u_rf.regs[1], uut.u_ctrl.alu_op,
                    uut.alu_result);
        end
        if (uut.u_rf.regs[1] === 16'd8) begin
            $display("[%0d] PASS: MOVL+ADDI: R1=8 (5+3)", test_id);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: R1=%d, expected 8", test_id, uut.u_rf.regs[1]);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 3: Branch test
        // ============================================
        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) imem[i] = 16'h0000;
        imem[0] = {4'b1001, 1'b0, 11'd2};  // B +2 → PC=0+1+2=3
        imem[1] = 16'h4163;  // MOVL R1 #99 (skipped)
        imem[2] = 16'h4163;  // MOVL R1 #99 (skipped)
        imem[3] = 16'h422A;  // MOVL R2 #42
        imem[4] = 16'hA000;  // HALT
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = imem[i];
        rst_n = 1; #1;

        test_id = 3;
        i = 0;
        while (!done && i < 200) begin
            @(posedge clk); i = i + 1;
            if (i <= 20)
                $display("  cyc%0d PC=%0d IR=%h st=%0d pc_load=%b bt=%0d R1=%0d R2=%0d",
                    i, debug_pc, debug_instruction, debug_state,
                    uut.u_ctrl.pc_load, uut.u_ctrl.branch_target,
                    uut.u_rf.regs[1], uut.u_rf.regs[2]);
        end
        if (uut.u_rf.regs[2] === 16'd42 && uut.u_rf.regs[1] === 16'd0) begin
            $display("[%0d] PASS: B +2: R2=42, R1=0 (skipped)", test_id);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: R1=%d R2=%d (exp R1=0,R2=42)",
                     test_id, uut.u_rf.regs[1], uut.u_rf.regs[2]);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 4: SUB + negative
        // ============================================
        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) imem[i] = 16'h0000;
        imem[0] = 16'h410A;  // MOVL R1, #10
        imem[1] = {4'b1101, 4'd1, 4'd1, 4'd15};  // SUBI R1,R1,#15
        imem[2] = 16'hA000;
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = imem[i];
        rst_n = 1; #1;

        test_id = 4;
        i = 0;
        while (!done && i < 200) begin
            @(posedge clk); i = i + 1;
        end
        if ($signed(uut.u_rf.regs[1]) === -5) begin
            $display("[%0d] PASS: SUBI: R1=-5 (10-15)", test_id);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: R1=%d, expected -5", test_id, $signed(uut.u_rf.regs[1]));
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Final
        // ============================================
        $display("========================================");
        $display("  MCU Core Efficiency Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

endmodule
