`timescale 1ns / 1ps

module tb_program_counter;
    reg        clk, rst_n, pc_load, pc_hold;
    reg  [7:0] branch_target;
    wire [7:0] pc;

    program_counter uut (
        .clk(clk), .rst_n(rst_n),
        .pc_load(pc_load), .pc_hold(pc_hold),
        .branch_target(branch_target), .pc(pc)
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id;

    initial begin
        clk = 0; rst_n = 0; pc_load = 0; pc_hold = 0; branch_target = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        #22 rst_n = 1;  // release reset between edges (0ns→5ns→10ns→15ns→20ns→22ns)
        #0.1;            // let signal propagate

        // === Test 1: PC = 0 after reset, before first non-reset posedge ===
        test_id = 1;
        chk(test_id, "Reset: PC = 0", pc, 8'd0);

        // First posedge after reset release → PC increments to 1
        @(posedge clk); #1;
        test_id = 2;
        chk(test_id, "PC = 1 after first inc", pc, 8'd1);

        @(posedge clk); #1;
        test_id = 3;
        chk(test_id, "PC = 2", pc, 8'd2);

        @(posedge clk); #1;
        test_id = 4;
        chk(test_id, "PC = 3", pc, 8'd3);

        // === Test 5: Branch load ===
        test_id = 5;
        @(negedge clk);
        pc_load = 1; branch_target = 8'd100;
        @(posedge clk); #1;
        pc_load = 0;
        chk(test_id, "Branch: PC = 100", pc, 8'd100);

        // === Test 6: Sequential resumes from branch target ===
        test_id = 6;
        @(posedge clk); #1;
        chk(test_id, "PC = 101 after branch", pc, 8'd101);

        test_id = 7;
        @(posedge clk); #1;
        chk(test_id, "PC = 102", pc, 8'd102);

        // === Test 8: Hold prevents increment ===
        test_id = 8;
        @(negedge clk);
        pc_hold = 1;
        @(posedge clk); #1;
        chk(test_id, "Hold: PC stays 102 (not 103)", pc, 8'd102);

        // === Test 9: Hold continues ===
        test_id = 9;
        @(posedge clk); #1;
        chk(test_id, "Hold: PC still 102", pc, 8'd102);

        // === Test 10: Release hold, resume increment ===
        test_id = 10;
        pc_hold = 0;
        @(posedge clk); #1;
        chk(test_id, "Release hold: PC = 103", pc, 8'd103);

        // === Test 11: Branch to address 0 ===
        test_id = 11;
        @(negedge clk);
        pc_load = 1; branch_target = 8'd0;
        @(posedge clk); #1;
        pc_load = 0;
        chk(test_id, "Branch to 0", pc, 8'd0);

        // === Test 12: Branch to max address 255 ===
        test_id = 12;
        @(negedge clk);
        pc_load = 1; branch_target = 8'd255;
        @(posedge clk); #1;
        pc_load = 0;
        chk(test_id, "Branch to 255", pc, 8'd255);

        // === Test 13: Hold takes priority over load ===
        test_id = 13;
        @(negedge clk);
        pc_load = 1; branch_target = 8'd50;
        pc_hold = 1;
        @(posedge clk); #1;
        pc_load = 0; pc_hold = 0;
        chk(test_id, "Hold+Load: PC stays 255 (hold wins)", pc, 8'd255);

        // === Test 14: Normal increment after complex sequence ===
        test_id = 14;
        @(posedge clk); #1;
        chk(test_id, "PC = 0 after wrap from 255", pc, 8'd0);

        // === Test 15: Small branch forward ===
        test_id = 15;
        @(negedge clk);
        pc_load = 1; branch_target = 8'd20;
        @(posedge clk); #1;
        pc_load = 0;
        chk(test_id, "Branch to 20", pc, 8'd20);

        // === Final ===
        $display("========================================");
        $display("  Program Counter Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    task chk;
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

endmodule
