`timescale 1ns / 1ps

module tb_efficiency;
    reg clk, rst_n;
    reg [15:0] test_vector_in;
    wire done;
    wire [7:0] debug_pc;
    wire [15:0] debug_instruction;
    wire [2:0] debug_state;

    mcu_core #(.HAS_ACCEL(0)) uut (
        .clk(clk), .rst_n(rst_n), .test_vector_in(test_vector_in),
        .rom_addr(), .rom_rd_en(), .verify_ram_addr(), .verify_vector_out(),
        .ram_we(), .cnt_start(), .cnt_stop(), .done(done),
        .debug_pc(debug_pc), .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        .debug_internal_mem_we(), .debug_internal_mem_addr(), .debug_internal_mem_wdata()
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, i, cyc;

    initial begin
        clk = 0; rst_n = 0; test_vector_in = 0;
        pass_cnt = 0; fail_cnt = 0;

        // ============================================
        // Test: Insertion Sort on 4 elements [4,2,5,1]
        // Hand-assembled program:
        //  0: MOVL R0,#0     4000  (base = 0)
        //  1: MOVL R1,#4     4104  (n = 4)
        //  2: MOVL R2,#1     4201  (const 1)
        //  3: MOVL R3,#1     4301  (i = 1)
        // outer:
        //  4: CMP R3,R1      8031  (i < n?)
        //  5: BGE done        B... skip
        //  6: LDR R4,R0,R3   6403  (key = A[i])
        //  7: SUBI R5,R3,#1  D531  (j = i-1)
        // while:
        //  8: CMP R5,R0      8050  (j >= 0?)
        //  9: BLT wdone       B... skip
        // 10: LDR R6,R0,R5   6605  (A[j])
        // 11: CMP R6,R4      8064  (A[j] > key?)
        // 12: BLE wdone       B... skip
        // 13: ADDI R7,R5,#1  C751  (j+1)
        // 14: STR R6,R0,R7   7607  (A[j+1]=A[j])
        // 15: SUBI R5,R5,#1  D551  (j--)
        // 16: B while           9xxx
        // wdone:
        // 17: ADDI R7,R5,#1  C751  (j+1)
        // 18: STR R4,R0,R7   7407  (A[j+1]=key)
        // 19: ADDI R3,R3,#1  C331  (i++)
        // 20: B outer            9xxx
        // done:
        // 21: HALT           A000

        // Simplified: test just 4 elements with a simpler bubble sort
        // Let's use backdoor data and a simpler program
        // Actually, let's just test that the MCU can execute MOVL+ADDI+HALT
        // and verify registers are correct

        // Program: MOVL R1,#100; ADDI R1,R1,#20; HALT
        // 0: 4100 (MOVL R1,#0) — wait, #100 = 0x64
        // MOVL R1,#100 = 0100_0001_01100100 = 16'h4164
        // ADDI R1,R1,#20 = 1100_0001_0001_0100 = 16'hC114 (imm4=4?! #20>15!)
        // #20 doesn't fit in 4-bit immediate. Use MOVL R2,#20; ADD R1,R1,R2
        // 0: MOVL R1,#100   = 4164
        // 1: MOVL R2,#20    = 4214
        // 2: ADD R1,R1,R2   = 0112
        // 3: HALT           = A000

        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = 16'h0000;
        uut.u_imem.mem[0] = 16'h4164;  // MOVL R1,#100
        uut.u_imem.mem[1] = 16'h4214;  // MOVL R2,#20
        uut.u_imem.mem[2] = 16'h0112;  // ADD R1,R1,R2
        uut.u_imem.mem[3] = 16'hA000;  // HALT
        rst_n = 1; #1;

        cyc = 0;
        while (!done && cyc < 200) begin @(posedge clk); cyc = cyc + 1; end

        if (uut.u_rf.regs[1] === 16'd120 && uut.u_rf.regs[2] === 16'd20 && done) begin
            $display("PASS: R1=120, R2=20, done=1 (%0d cyc)", cyc);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL: R1=%0d R2=%0d done=%b", uut.u_rf.regs[1], uut.u_rf.regs[2], done);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 2: SUBI + BGT loop (5-iter countdown)
        // MOVL R1,#5; loop: SUBI R1,R1,#1; CMP R1,R0; BGT loop; HALT
        // R0=0 always. R1=5,4,3,2,1,0. After loop: R1=0, Z=1
        // BGT offset: target = loop-addr, offset = target - pc - 1
        // 0: MOVL R1,#5    = 4105
        // 1: SUBI R1,R1,#1 = D111  (loop:)
        // 2: CMP R1,R0     = 8010
        // 3: BGT loop      = B (cond=GT=3) offset = 1-3-1=-3 = 9'h1FD -> 1011_011_111111101
        //                   = B59D? Let me compute: 1011_011_111111101 = 1011 0111 1111 1101 = B7FD
        // Wait: cond=GT=011, offset=-3=0x1FD in 9-bit = 1_1111_1101
        // instruction: 1011 | 011 | 1_1111_1101 = 1011 0111 1111 1101 = B7FD
        // 4: HALT = A000
        rst_n = 0; #20;
        for (i = 0; i < 256; i = i + 1) uut.u_imem.mem[i] = 16'h0000;
        uut.u_imem.mem[0] = 16'h4105;  // MOVL R1,#5
        uut.u_imem.mem[1] = 16'hD111;  // SUBI R1,R1,#1
        uut.u_imem.mem[2] = 16'h8010;  // CMP R1,R0
        uut.u_imem.mem[3] = {4'b1011, 3'b011, 9'h1FD};  // BGT loop (offset -3)
        uut.u_imem.mem[4] = 16'hA000;  // HALT
        rst_n = 1; #1;

        cyc = 0;
        while (!done && cyc < 500) begin @(posedge clk); cyc = cyc + 1; end
        if (uut.u_rf.regs[1] === 16'd0 && done) begin
            $display("PASS: BGT loop: R1=0 (%0d cyc)", cyc);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL: BGT loop: R1=%0d done=%b", uut.u_rf.regs[1], done);
            fail_cnt = fail_cnt + 1;
        end

        $display("===== Efficiency Tests: PASS=%0d FAIL=%0d =====", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("OVERALL: PASS"); else $display("OVERALL: FAIL");
        $finish;
    end
endmodule
