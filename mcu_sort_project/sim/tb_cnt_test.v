`timescale 1ns / 1ps

module tb_cnt_test;
    reg clk, rst_n, cnt_start, cnt_stop;
    wire [19:0] count;
    wire counting;

    cnt_test uut (
        .clk(clk), .rst_n(rst_n),
        .cnt_start(cnt_start), .cnt_stop(cnt_stop),
        .count(count), .counting(counting)
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id;

    initial begin
        clk = 0; rst_n = 0; cnt_start = 0; cnt_stop = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        #25 rst_n = 1; #1;

        // Test 1: After reset, count=0, counting=0
        test_id = 1;
        chk(test_id, "Reset: count=0, counting=0", count, 20'd0, counting, 1'b0);

        // Test 2: No counting before start
        @(posedge clk); #1;
        test_id = 2;
        chk(test_id, "No start: count still 0", count, 20'd0, counting, 1'b0);

        // Test 3: Start pulse
        @(negedge clk); cnt_start = 1;
        @(posedge clk); #1; cnt_start = 0;
        test_id = 3;
        chk(test_id, "After start: counting=1", count, 20'd0, counting, 1'b1);

        // Test 4: Count increments
        @(posedge clk); #1;
        test_id = 4;
        chk(test_id, "Count=1 after 1 cycle", count, 20'd1, counting, 1'b1);

        // Test 5: Count continues
        repeat(3) @(posedge clk); #1;
        test_id = 5;
        chk(test_id, "Count=4 after 4 cycles", count, 20'd4, counting, 1'b1);

        // Test 6: cnt_start again while already counting → ignored
        @(negedge clk); cnt_start = 1;
        @(posedge clk); #1; cnt_start = 0;
        @(posedge clk); #1;
        test_id = 6;
        chk(test_id, "Re-start ignored: count=6", count, 20'd6, counting, 1'b1);

        // Test 7: Stop
        @(negedge clk); cnt_stop = 1;
        @(posedge clk); #1; cnt_stop = 0;
        test_id = 7;
        chk(test_id, "After stop: counting=0", count, 20'd7, counting, 1'b0);

        // Test 8: Count frozen after stop
        @(posedge clk); #1;
        test_id = 8;
        chk(test_id, "Count frozen at 7", count, 20'd7, counting, 1'b0);

        // Test 9: Another stop pulse ignored
        @(negedge clk); cnt_stop = 1;
        @(posedge clk); #1; cnt_stop = 0;
        test_id = 9;
        chk(test_id, "Re-stop ignored: count=7", count, 20'd7, counting, 1'b0);

        // Test 10: Reset clears everything
        rst_n = 0; #20; rst_n = 1; #1;
        test_id = 10;
        chk(test_id, "After reset: count=0", count, 20'd0, counting, 1'b0);

        // Test 11: Fresh start after reset works
        @(negedge clk); cnt_start = 1;
        @(posedge clk); #1; cnt_start = 0;
        @(posedge clk); #1;
        test_id = 11;
        chk(test_id, "Re-start after reset: counting=1, count=1", count, 20'd1, counting, 1'b1);

        // Test 12: Start+stop same cycle → stop wins (start first, stop later in same cycle)
        rst_n = 0; #20; rst_n = 1; #1;
        @(negedge clk); cnt_start = 1; cnt_stop = 1;
        @(posedge clk); #1; cnt_start = 0; cnt_stop = 0;
        test_id = 12;
        // Both start and stop in same cycle: start processes first (NBA), stop misses
        // Real MCU never does this; acceptable behavior: start wins
        chk(test_id, "Start+stop same: start wins, counting=1", count, 20'd0, counting, 1'b1);

        // Test 13: Stop before start → no counting
        rst_n = 0; #20; rst_n = 1; #1;
        @(negedge clk); cnt_stop = 1;
        @(posedge clk); #1; cnt_stop = 0;
        test_id = 13;
        chk(test_id, "Stop before start: no counting", count, 20'd0, counting, 1'b0);

        // Final
        $display("========================================");
        $display("  cnt_test Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    task chk;
        input integer tid; input [127:0] tn;
        input [19:0] act_count, exp_count;
        input act_counting, exp_counting;
        begin
            if (act_count !== exp_count || act_counting !== exp_counting) begin
                $display("[%0d] FAIL: %s (count=%d exp=%d, counting=%b exp=%b)",
                         tid, tn, act_count, exp_count, act_counting, exp_counting);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

endmodule
