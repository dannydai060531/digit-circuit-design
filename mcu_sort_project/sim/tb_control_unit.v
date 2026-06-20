`timescale 1ns / 1ps

module tb_control_unit;
    reg clk, rst_n, accel_busy, accel_done;
    reg n, z, c, v;
    reg [15:0] instruction;
    reg [7:0]  pc;
    wire [2:0] alu_op, mcu_state;
    wire reg_wen, mem_wen, mem_ren, pc_load, pc_hold, halt;
    wire [7:0] branch_target;
    wire accel_start;
    wire [7:0] imm8;

    control_unit #(.HAS_ACCEL(0)) uut_eff (
        .clk(clk), .rst_n(rst_n), .instruction(instruction), .pc(pc),
        .alu_op(alu_op), .reg_wen(reg_wen), .mem_wen(mem_wen), .mem_ren(mem_ren),
        .pc_load(pc_load), .pc_hold(pc_hold), .branch_target(branch_target),
        .halt(halt), .mcu_state(mcu_state), .imm8(imm8),
        .accel_start(accel_start), .accel_busy(accel_busy), .accel_done(accel_done),
        .n(n), .z(z), .c(c), .v(v),
        // unused ports tied off
        .reg_write_addr(), .reg_read_addr1(), .reg_read_addr2(),
        .alu_src_a_sel(), .alu_src_b_sel(), .imm4(),
        .accel_base(), .accel_ncode(), .accel_is_sort8()
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id;
    reg [2:0] prev_state;

    // Monitor state changes and set instruction at the right time
    always @(posedge clk) prev_state <= mcu_state;

    initial begin
        clk = 0; rst_n = 0; pc = 8'd0; instruction = 16'h0000;
        accel_busy = 0; accel_done = 0;
        n = 0; z = 0; c = 0; v = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        #22 rst_n = 1; #0.1;

        // Wait for first full pipeline pass and reach FETCH
        wait_fetch();

        // ============================================
        // Test 1: ADD
        // ============================================
        test_id = 1;
        feed_instr({4'b0000, 4'd1, 4'd2, 4'd3});
        wait_exec();
        chk_alu(test_id, "ADD: alu_op=000", alu_op, 3'b000);

        // ============================================
        // Test 2: SUB
        // ============================================
        test_id = 2;
        feed_instr({4'b0001, 4'd4, 4'd5, 4'd6});
        wait_exec();
        chk_alu(test_id, "SUB: alu_op=001", alu_op, 3'b001);

        // ============================================
        // Test 3: AND
        // ============================================
        test_id = 3;
        feed_instr({4'b0010, 4'd7, 4'd8, 4'd9});
        wait_exec();
        chk_alu(test_id, "AND: alu_op=010", alu_op, 3'b010);

        // ============================================
        // Test 4: OR
        // ============================================
        test_id = 4;
        feed_instr({4'b0011, 4'd10, 4'd11, 4'd12});
        wait_exec();
        chk_alu(test_id, "OR: alu_op=011", alu_op, 3'b011);

        // ============================================
        // Test 5: CMP
        // ============================================
        test_id = 5;
        feed_instr({4'b1000, 4'd0, 4'd1, 4'd2});
        wait_exec();
        chk_alu(test_id, "CMP: alu_op=001 (SUB)", alu_op, 3'b001);

        // ============================================
        // Test 6: MOVL
        // ============================================
        test_id = 6;
        feed_instr({4'b0100, 4'd3, 8'hAB});
        wait_exec();
        chk(test_id, "MOVL: imm8=AB", imm8, 8'hAB);

        // ============================================
        // Test 7: MOVH
        // ============================================
        test_id = 7;
        feed_instr({4'b0101, 4'd5, 8'hCD});
        wait_exec();
        chk(test_id, "MOVH: imm8=CD", imm8, 8'hCD);

        // ============================================
        // Test 8: LDR
        // ============================================
        test_id = 8;
        feed_instr({4'b0110, 4'd2, 4'd0, 4'd4});
        wait_exec();
        chk_1b(test_id, "LDR: mem_ren=1", mem_ren, 1'b1);

        // ============================================
        // Test 9: STR
        // ============================================
        test_id = 9;
        feed_instr({4'b0111, 4'd3, 4'd0, 4'd5});
        wait_exec();
        chk_1b(test_id, "STR: mem_wen=1", mem_wen, 1'b1);

        // ============================================
        // Test 10: ADDI
        // ============================================
        test_id = 10;
        feed_instr({4'b1100, 4'd1, 4'd2, 4'd9});
        wait_exec();
        chk_alu(test_id, "ADDI: alu_op=000", alu_op, 3'b000);

        // ============================================
        // Test 11: SUBI
        // ============================================
        test_id = 11;
        feed_instr({4'b1101, 4'd1, 4'd2, 4'd3});
        wait_exec();
        chk_alu(test_id, "SUBI: alu_op=001", alu_op, 3'b001);

        // ============================================
        // Test 12: B (offset +5, pc=10 → target=16)
        // ============================================
        test_id = 12; pc = 8'd10;
        feed_instr({4'b1001, 1'b0, 11'd5});
        wait_exec();
        @(posedge clk); #1;  // MEMORY state (branch target computed)
        chk_pc(test_id, "B +5: target=16", branch_target, 8'd16);

        // ============================================
        // Test 13: BL (L=1)
        // ============================================
        test_id = 13; pc = 8'd10;
        feed_instr({4'b1001, 1'b1, 11'd3});
        wait_exec();
        @(posedge clk); #1;  // MEMORY
        chk_pc(test_id, "BL +3: target=14", branch_target, 8'd14);

        // ============================================
        // Test 14: BEQ taken (Z=1)
        // ============================================
        test_id = 14; z = 1; pc = 8'd20;
        feed_instr({4'b1011, 3'd0, 9'd10});  // BEQ
        wait_exec();
        @(posedge clk); #1;  // MEMORY
        chk_pc(test_id, "BEQ taken (Z=1): target=31", branch_target, 8'd31);

        // ============================================
        // Test 15: BNE not taken (Z=1)
        // ============================================
        test_id = 15; z = 1;
        feed_instr({4'b1011, 3'd1, 9'd10});  // BNE
        wait_exec();
        chk_1b(test_id, "BNE not taken: pc_load=0", pc_load, 1'b0);

        // ============================================
        // Test 16-19: remaining Bcc
        // ============================================
        test_id = 16; n = 1; v = 0; z = 0;
        feed_instr({4'b1011, 3'd2, 9'd5}); wait_exec();
        chk_1b(test_id, "BLT taken (N=1,V=0)", pc_load, 1'b1);

        test_id = 17; n = 0; v = 0; z = 0;
        feed_instr({4'b1011, 3'd3, 9'd5}); wait_exec();
        chk_1b(test_id, "BGT taken (N=0,V=0,Z=0)", pc_load, 1'b1);

        test_id = 18; z = 1; n = 0; v = 0;
        feed_instr({4'b1011, 3'd4, 9'd5}); wait_exec();
        chk_1b(test_id, "BLE taken (Z=1)", pc_load, 1'b1);

        test_id = 19; n = 0; v = 0; z = 0;
        feed_instr({4'b1011, 3'd5, 9'd5}); wait_exec();
        chk_1b(test_id, "BGE taken (N=0,V=0)", pc_load, 1'b1);

        // ============================================
        // Test 20: HALT
        // ============================================
        test_id = 20;
        feed_instr({4'b1010, 12'h000});
        @(posedge clk); #1;  // DECODE
        chk_1b(test_id, "HALT: halt=1", halt, 1'b1);

        // Exit HALT via reset
        rst_n = 0; #30; rst_n = 1; #0.1;
        wait_fetch();

        // ============================================
        // Test 21-23: Reserved opcodes with HAS_ACCEL=0
        // ============================================
        test_id = 21;
        feed_instr({4'b1110, 8'd0, 4'd0}); wait_exec();
        chk_1b(test_id, "SORT8(HAS_ACCEL=0): accel_start=0", accel_start, 1'b0);

        test_id = 22;
        feed_instr({4'b1111, 4'd5, 4'd1, 4'd0}); wait_exec();
        chk_1b(test_id, "BMERGE N_code=1(HAS_ACCEL=0): accel_start=0", accel_start, 1'b0);

        test_id = 23;
        feed_instr({4'b1111, 4'd5, 4'd5, 4'd0}); wait_exec();
        chk_1b(test_id, "BMERGE N_code=5 illegal: accel_start=0", accel_start, 1'b0);

        // ============================================
        $display("========================================");
        $display("  Control Unit (Efficiency) Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    // Wait until state reaches FETCH, then set instruction at negedge
    task feed_instr;
        input [15:0] instr;
        begin
            while (mcu_state != 3'd0) begin
                @(posedge clk); #1;  // #1 lets NBA settle so mcu_state updates
            end
            @(negedge clk);
            instruction = instr;
        end
    endtask

    // Wait until state reaches EXECUTE, then check
    task wait_exec;
        begin
            while (mcu_state != 3'd2) begin
                @(posedge clk); #1;
            end
            #1;
        end
    endtask

    // Initial drain
    task wait_fetch;
        begin
            while (mcu_state != 3'd0) begin
                @(posedge clk); #1;
            end
        end
    endtask

    task chk_alu;
        input integer tid; input [127:0] tn;
        input [2:0] act, exp;
        begin
            if (act !== exp) begin
                $display("[%0d] FAIL: %s (got %b exp %b)", tid, tn, act, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task chk_pc;
        input integer tid; input [127:0] tn;
        input [7:0] act, exp;
        begin
            if (act !== exp) begin
                $display("[%0d] FAIL: %s (got %d exp %d)", tid, tn, act, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task chk_1b;
        input integer tid; input [127:0] tn;
        input act, exp;
        begin
            if (act !== exp) begin
                $display("[%0d] FAIL: %s (got %b exp %b)", tid, tn, act, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task chk;
        input integer tid; input [127:0] tn;
        input [7:0] act, exp;
        begin
            if (act !== exp) begin
                $display("[%0d] FAIL: %s (got %h exp %h)", tid, tn, act, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

endmodule
