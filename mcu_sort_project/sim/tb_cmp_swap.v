`timescale 1ns / 1ps

module tb_cmp_swap;
    reg signed [15:0] a_in, b_in;
    wire signed [15:0] a_out, b_out;

    cmp_swap uut (.a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out));

    integer pass_cnt, fail_cnt, test_id;

    initial begin
        pass_cnt = 0; fail_cnt = 0; test_id = 0;

        // Test 1: already ordered
        test_id = 1; a_in = 5; b_in = 10; #1;
        chk(test_id, "5,10 → 5,10 (no swap)", a_out, 5, b_out, 10);

        // Test 2: swap needed
        test_id = 2; a_in = 10; b_in = 5; #1;
        chk(test_id, "10,5 → 5,10 (swap)", a_out, 5, b_out, 10);

        // Test 3: equal → no swap
        test_id = 3; a_in = 7; b_in = 7; #1;
        chk(test_id, "7,7 → 7,7 (equal)", a_out, 7, b_out, 7);

        // Test 4: both zero
        test_id = 4; a_in = 0; b_in = 0; #1;
        chk(test_id, "0,0 → 0,0", a_out, 0, b_out, 0);

        // Test 5: negative < positive
        test_id = 5; a_in = 100; b_in = -5; #1;
        chk(test_id, "100,-5 → -5,100", a_out, -5, b_out, 100);

        // Test 6: negative vs negative
        test_id = 6; a_in = -3; b_in = -8; #1;
        chk(test_id, "-3,-8 → -8,-3", a_out, -8, b_out, -3);

        // Test 7: max positive vs max negative
        test_id = 7; a_in = 16'h7FFF; b_in = 16'h8000; #1;  // 32767 vs -32768
        chk(test_id, "0x7FFF,0x8000 → 0x8000,0x7FFF", a_out, -32768, b_out, 32767);

        // Test 8: -1 vs 0
        test_id = 8; a_in = -1; b_in = 0; #1;
        chk(test_id, "-1,0 → -1,0", a_out, -1, b_out, 0);

        // Test 9: both max positive
        test_id = 9; a_in = 16'h7FFF; b_in = 16'h7FFF; #1;
        chk(test_id, "0x7FFF,0x7FFF → same", a_out, 32767, b_out, 32767);

        // Test 10: both max negative
        test_id = 10; a_in = 16'h8000; b_in = 16'h8000; #1;
        chk(test_id, "0x8000,0x8000 → same", a_out, -32768, b_out, -32768);

        // Test 11: 0xFFFF (-1) vs 0x0001 (1)
        test_id = 11; a_in = 16'hFFFF; b_in = 16'h0001; #1;
        chk(test_id, "0xFFFF(-1),1 → -1,1", a_out, -1, b_out, 1);

        // Test 12: -32768 vs -32767
        test_id = 12; a_in = -32767; b_in = -32768; #1;
        chk(test_id, "-32767,-32768 → -32768,-32767", a_out, -32768, b_out, -32767);

        $display("========================================");
        $display("  cmp_swap Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    task chk;
        input integer tid; input [127:0] tn;
        input signed [15:0] act_a, exp_a, act_b, exp_b;
        begin
            if (act_a !== exp_a || act_b !== exp_b) begin
                $display("[%0d] FAIL: %s (got %d,%d exp %d,%d)",
                         tid, tn, act_a, act_b, exp_a, exp_b);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

endmodule
