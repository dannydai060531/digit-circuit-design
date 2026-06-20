`timescale 1ns / 1ps

module tb_alu;
    reg        [2:0]  alu_op;
    reg signed [15:0] a;
    reg signed [15:0] b;
    wire signed [15:0] result;
    wire               n, z, c, v;

    alu uut (
        .alu_op (alu_op),
        .a      (a),
        .b      (b),
        .result (result),
        .n      (n),
        .z      (z),
        .c      (c),
        .v      (v)
    );

    integer pass_cnt, fail_cnt, test_id;
    reg [63:0] test_name;

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        test_id  = 0;

        // ============================================
        // ADD tests
        // ============================================

        // ADD: normal positive
        test_id = test_id + 1;
        test_name = "ADD: 5 + 3 = 8";
        alu_op = 3'b000; a = 16'd5; b = 16'd3; #10;
        check(test_id, test_name, 16'd8, 1'b0, 1'b0, 1'b0, 1'b0);

        // ADD: negative + negative
        test_id = test_id + 1;
        test_name = "ADD: -5 + -3 = -8";
        alu_op = 3'b000; a = -16'd5; b = -16'd3; #10;
        check(test_id, test_name, -16'd8, 1'b1, 1'b0, 1'b1, 1'b0);

        // ADD: positive + negative, positive result
        test_id = test_id + 1;
        test_name = "ADD: 10 + -3 = 7, C=1 (-3 unsigned=65533, 10+65533 carries)";
        alu_op = 3'b000; a = 16'd10; b = -16'd3; #10;
        check(test_id, test_name, 16'd7, 1'b0, 1'b0, 1'b1, 1'b0);

        // ADD: zero
        test_id = test_id + 1;
        test_name = "ADD: 0 + 0 = 0, Z=1";
        alu_op = 3'b000; a = 16'd0; b = 16'd0; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b0, 1'b0);

        // ADD: carry out (unsigned wrap)
        test_id = test_id + 1;
        test_name = "ADD: 16'hFFFF + 1 -> carry=1";
        alu_op = 3'b000; a = 16'hFFFF; b = 16'd1; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b1, 1'b0);

        // ADD: signed overflow max positive
        test_id = test_id + 1;
        test_name = "ADD: 16'h7FFF + 1 -> overflow V=1";
        alu_op = 3'b000; a = 16'h7FFF; b = 16'd1; #10;
        check(test_id, test_name, 16'h8000, 1'b1, 1'b0, 1'b0, 1'b1);

        // ADD: signed overflow max negative
        test_id = test_id + 1;
        test_name = "ADD: 16'h8000 + 16'hFFFF (-1) -> overflow V=1";
        alu_op = 3'b000; a = 16'h8000; b = -16'd1; #10;
        check(test_id, test_name, 16'h7FFF, 1'b0, 1'b0, 1'b1, 1'b1);

        // ADD: narrow positive, carry=0
        test_id = test_id + 1;
        test_name = "ADD: 100 + 200 = 300";
        alu_op = 3'b000; a = 16'd100; b = 16'd200; #10;
        check(test_id, test_name, 16'd300, 1'b0, 1'b0, 1'b0, 1'b0);

        // ============================================
        // SUB tests
        // ============================================

        // SUB: normal, no borrow
        test_id = test_id + 1;
        test_name = "SUB: 16'h0002 - 16'h0001 -> C=1 (no borrow)";
        alu_op = 3'b001; a = 16'h0002; b = 16'h0001; #10;
        check(test_id, test_name, 16'd1, 1'b0, 1'b0, 1'b1, 1'b0);

        // SUB: borrow
        test_id = test_id + 1;
        test_name = "SUB: 16'h0000 - 16'h0001 -> C=0 (borrow)";
        alu_op = 3'b001; a = 16'h0000; b = 16'h0001; #10;
        check(test_id, test_name, -16'd1, 1'b1, 1'b0, 1'b0, 1'b0);

        // SUB: equal -> Z=1, C=1
        test_id = test_id + 1;
        test_name = "SUB: 5 - 5 = 0, Z=1, C=1";
        alu_op = 3'b001; a = 16'd5; b = 16'd5; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b1, 1'b0);

        // SUB: negative result
        test_id = test_id + 1;
        test_name = "SUB: 3 - 7 = -4";
        alu_op = 3'b001; a = 16'd3; b = 16'd7; #10;
        check(test_id, test_name, -16'd4, 1'b1, 1'b0, 1'b0, 1'b0);

        // SUB: no borrow large
        test_id = test_id + 1;
        test_name = "SUB: 1000 - 1, C=1";
        alu_op = 3'b001; a = 16'd1000; b = 16'd1; #10;
        check(test_id, test_name, 16'd999, 1'b0, 1'b0, 1'b1, 1'b0);

        // SUB: signed overflow (max negative minus 1)
        test_id = test_id + 1;
        test_name = "SUB: 16'h8000 - 1 -> overflow V=1";
        alu_op = 3'b001; a = 16'h8000; b = 16'd1; #10;
        check(test_id, test_name, 16'h7FFF, 1'b0, 1'b0, 1'b1, 1'b1);

        // SUB: no overflow, negative minus negative
        test_id = test_id + 1;
        test_name = "SUB: -5 - -3 = -2, no overflow";
        alu_op = 3'b001; a = -16'd5; b = -16'd3; #10;
        check(test_id, test_name, -16'd2, 1'b1, 1'b0, 1'b0, 1'b0);

        // SUB: no overflow, negative minus positive
        test_id = test_id + 1;
        test_name = "SUB: -1 - 32767 = -32768, C=1 (no borrow: 65535 >= 32767), V=0";
        alu_op = 3'b001; a = -16'd1; b = 16'd32767; #10;
        check(test_id, test_name, -16'd32768, 1'b1, 1'b0, 1'b1, 1'b0);

        // ============================================
        // CMP tests (uses SUB path, flags only)
        // ============================================

        test_id = test_id + 1;
        test_name = "CMP: 5 vs 3 -> N=0, Z=0, C=1, V=0 (5>3)";
        alu_op = 3'b001; a = 16'd5; b = 16'd3; #10;
        check_flags(test_id, test_name, 1'b0, 1'b0, 1'b1, 1'b0);

        test_id = test_id + 1;
        test_name = "CMP: 3 vs 5 -> N=1, Z=0, C=0, V=0 (3<5)";
        alu_op = 3'b001; a = 16'd3; b = 16'd5; #10;
        check_flags(test_id, test_name, 1'b1, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "CMP: -1 vs 0 -> N=1, Z=0, C=1, V=0 (-1<0 signed)";
        alu_op = 3'b001; a = -16'd1; b = 16'd0; #10;
        check_flags(test_id, test_name, 1'b1, 1'b0, 1'b1, 1'b0);

        test_id = test_id + 1;
        test_name = "CMP: 0 vs -1 -> N=0, Z=0, C=0, V=0 (0>-1 signed)";
        alu_op = 3'b001; a = 16'd0; b = -16'd1; #10;
        check_flags(test_id, test_name, 1'b0, 1'b0, 1'b0, 1'b0);

        // ============================================
        // AND tests
        // ============================================

        test_id = test_id + 1;
        test_name = "AND: 16'hFF00 & 16'h0FF0 = 16'h0F00";
        alu_op = 3'b010; a = 16'hFF00; b = 16'h0FF0; #10;
        check(test_id, test_name, 16'h0F00, 1'b0, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "AND: 0 & anything = 0, Z=1";
        alu_op = 3'b010; a = 16'd0; b = 16'hABCD; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "AND: 16'hFFFF & 16'h8000 = 16'h8000, N=1";
        alu_op = 3'b010; a = 16'hFFFF; b = 16'h8000; #10;
        check(test_id, test_name, 16'h8000, 1'b1, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "AND: 16'h7FFF & 16'h7FFF = 16'h7FFF, N=0";
        alu_op = 3'b010; a = 16'h7FFF; b = 16'h7FFF; #10;
        check(test_id, test_name, 16'h7FFF, 1'b0, 1'b0, 1'b0, 1'b0);

        // ============================================
        // OR tests
        // ============================================

        test_id = test_id + 1;
        test_name = "OR: 16'hF000 | 16'h0F00 = 16'hFF00";
        alu_op = 3'b011; a = 16'hF000; b = 16'h0F00; #10;
        check(test_id, test_name, 16'hFF00, 1'b1, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "OR: 0 | 0 = 0, Z=1";
        alu_op = 3'b011; a = 16'd0; b = 16'd0; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "OR: 16'h0001 | 16'h0002 = 16'h0003";
        alu_op = 3'b011; a = 16'h0001; b = 16'h0002; #10;
        check(test_id, test_name, 16'h0003, 1'b0, 1'b0, 1'b0, 1'b0);

        // ============================================
        // PASSA tests
        // ============================================

        test_id = test_id + 1;
        test_name = "PASSA: pass 16'h7FFF, N=0, Z=0, C=0, V=0";
        alu_op = 3'b100; a = 16'h7FFF; b = 16'd0; #10;
        check(test_id, test_name, 16'h7FFF, 1'b0, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "PASSA: pass 16'h8000, N=1, Z=0, C=0, V=0";
        alu_op = 3'b100; a = 16'h8000; b = 16'd0; #10;
        check(test_id, test_name, 16'h8000, 1'b1, 1'b0, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "PASSA: pass 0, N=0, Z=1, C=0, V=0";
        alu_op = 3'b100; a = 16'd0; b = 16'd0; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b0, 1'b0);

        test_id = test_id + 1;
        test_name = "PASSA: pass -32768 (16'h8000), N=1";
        alu_op = 3'b100; a = 16'h8000; b = 16'd0; #10;
        check(test_id, test_name, 16'h8000, 1'b1, 1'b0, 1'b0, 1'b0);

        // ============================================
        // Edge cases: 0x7FFF, 0x8000
        // ============================================

        test_id = test_id + 1;
        test_name = "ADD: 16'h7FFF + 16'h7FFF -> -2, V=1";
        alu_op = 3'b000; a = 16'h7FFF; b = 16'h7FFF; #10;
        check(test_id, test_name, -16'd2, 1'b1, 1'b0, 1'b0, 1'b1);

        test_id = test_id + 1;
        test_name = "ADD: 16'h8000 + 16'h8000 -> 0, V=1, C=1";
        alu_op = 3'b000; a = 16'h8000; b = 16'h8000; #10;
        check(test_id, test_name, 16'd0, 1'b0, 1'b1, 1'b1, 1'b1);

        test_id = test_id + 1;
        test_name = "SUB: 16'h7FFF - 16'hFFFF (-1) -> V=1 overflow";
        alu_op = 3'b001; a = 16'h7FFF; b = -16'd1; #10;
        check(test_id, test_name, 16'h8000, 1'b1, 1'b0, 1'b0, 1'b1);

        // ============================================
        // Final report
        // ============================================
        $display("========================================");
        $display("  ALU Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt + fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  OVERALL: PASS");
        else
            $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    task check;
        input integer     tid;
        input [63:0]      tname;
        input signed [15:0] exp_result;
        input             exp_n, exp_z, exp_c, exp_v;
        begin
            if (result !== exp_result || n !== exp_n || z !== exp_z || c !== exp_c || v !== exp_v) begin
                $display("[%0d] FAIL: %s", tid, tname);
                $display("       result: got %h, expected %h", result, exp_result);
                $display("       flags:  got N=%b Z=%b C=%b V=%b, expected N=%b Z=%b C=%b V=%b",
                         n, z, c, v, exp_n, exp_z, exp_c, exp_v);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tname);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task check_flags;
        input integer     tid;
        input [63:0]      tname;
        input             exp_n, exp_z, exp_c, exp_v;
        begin
            if (n !== exp_n || z !== exp_z || c !== exp_c || v !== exp_v) begin
                $display("[%0d] FAIL: %s", tid, tname);
                $display("       flags: got N=%b Z=%b C=%b V=%b, expected N=%b Z=%b C=%b V=%b",
                         n, z, c, v, exp_n, exp_z, exp_c, exp_v);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tname);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

endmodule
