`timescale 1ns / 1ps

module tb_register_file;
    reg         clk;
    reg         rst_n;
    reg         write_enable;
    reg  [3:0]  read_addr1;
    reg  [3:0]  read_addr2;
    reg  [3:0]  write_addr;
    reg  [15:0] write_data;
    wire [15:0] read_data1;
    wire [15:0] read_data2;

    register_file uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .write_enable (write_enable),
        .read_addr1   (read_addr1),
        .read_addr2   (read_addr2),
        .write_addr   (write_addr),
        .write_data   (write_data),
        .read_data1   (read_data1),
        .read_data2   (read_data2)
    );

    // 10ns clock
    always #5 clk = ~clk;

    integer pass_cnt, fail_cnt, test_id;
    integer i;

    task check;
        input integer     tid;
        input [127:0]     tname;
        input [15:0]      exp_data1;
        input [15:0]      exp_data2;
        begin
            #1; // small delay for combinational read
            if (read_data1 !== exp_data1 || read_data2 !== exp_data2) begin
                $display("[%0d] FAIL: %s", tid, tname);
                $display("       rd1: got %h, expected %h", read_data1, exp_data1);
                $display("       rd2: got %h, expected %h", read_data2, exp_data2);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tname);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task check_single;
        input integer     tid;
        input [127:0]     tname;
        input [3:0]       addr;
        input [15:0]      exp_data;
        begin
            read_addr1 = addr;
            read_addr2 = 4'd0;  // unused
            #1;
            if (read_data1 !== exp_data) begin
                $display("[%0d] FAIL: %s", tid, tname);
                $display("       read R%d: got %h, expected %h", addr, read_data1, exp_data);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tname);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        write_enable = 0;
        read_addr1 = 4'd0;
        read_addr2 = 4'd0;
        write_addr = 4'd0;
        write_data = 16'd0;
        pass_cnt = 0;
        fail_cnt = 0;
        test_id = 0;

        // ============================================
        // Reset
        // ============================================
        #20 rst_n = 1; #10;
        $display("--- Reset complete ---");

        // ============================================
        // Test 1: After reset, all registers = 0
        // ============================================
        test_id = test_id + 1;
        begin : test_reset_all_zero
            integer err;
            err = 0;
            for (i = 0; i < 16; i = i + 1) begin
                read_addr1 = i[3:0];
                #1;
                if (read_data1 !== 16'd0) err = err + 1;
            end
            if (err == 0) begin
                $display("[%0d] PASS: After reset, all 16 registers = 0", test_id);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[%0d] FAIL: After reset, %0d registers non-zero", test_id, err);
                fail_cnt = fail_cnt + 1;
            end
        end

        // ============================================
        // Test 2: Write to R1, read back
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd1;
        write_data = 16'hABCD;
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R1=ABCD, read back", 4'd1, 16'hABCD);

        // ============================================
        // Test 3: Write to R2, read back
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd2;
        write_data = 16'h1234;
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R2=1234, read back", 4'd2, 16'h1234);

        // ============================================
        // Test 4: Write to R15 (LR), read back
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd15;
        write_data = 16'hDEAD;
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R15=DEAD, read back", 4'd15, 16'hDEAD);

        // ============================================
        // Test 5: Simultaneous dual-read from different registers
        // ============================================
        test_id = test_id + 1;
        read_addr1 = 4'd1;
        read_addr2 = 4'd2;
        check(test_id, "Dual-read: R1=ABCD, R2=1234", 16'hABCD, 16'h1234);

        // ============================================
        // Test 6: Dual-read R1 + R15
        // ============================================
        test_id = test_id + 1;
        read_addr1 = 4'd1;
        read_addr2 = 4'd15;
        check(test_id, "Dual-read: R1=ABCD, R15=DEAD", 16'hABCD, 16'hDEAD);

        // ============================================
        // Test 7: R0 always reads as 0
        // ============================================
        test_id = test_id + 1;
        read_addr1 = 4'd0;
        read_addr2 = 4'd0;
        check(test_id, "Dual-read: R0=0, R0=0", 16'd0, 16'd0);

        // ============================================
        // Test 8: Attempted write to R0 must be ignored
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd0;
        write_data = 16'hFFFF;
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write to R0=FFFF ignored, still 0", 4'd0, 16'd0);

        // ============================================
        // Test 9: write_enable=0 prevents write
        // ============================================
        test_id = test_id + 1;
        // R1 currently = ABCD
        @(posedge clk);
        write_enable = 0;
        write_addr = 4'd1;
        write_data = 16'h5555;
        @(posedge clk);
        #1;
        check_single(test_id, "WE=0: R1=ABCD unchanged (not 5555)", 4'd1, 16'hABCD);

        // ============================================
        // Test 10: Consecutive writes to R3, R4, R5
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd3; write_data = 16'hA001; @(posedge clk);
        write_addr = 4'd4; write_data = 16'hA002; @(posedge clk);
        write_addr = 4'd5; write_data = 16'hA003; @(posedge clk);
        write_enable = 0;
        #1;
        read_addr1 = 4'd3; read_addr2 = 4'd4; #1;
        if (read_data1 === 16'hA001 && read_data2 === 16'hA002) begin
            check_single(test_id, "R3,R4,R5 consecutive writes", 4'd5, 16'hA003);
            // R3/R4 already verified; R5 is checked here, all good if we reach
            pass_cnt = pass_cnt; // already counted in check_single
        end else begin
            $display("[%0d] FAIL: consecutive writes R3/R4/R5", test_id);
            $display("       R3=%h (exp A001), R4=%h (exp A002)", read_data1, read_data2);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================
        // Test 11: Signed-pattern 16'h8000
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd6;
        write_data = 16'h8000;   // -32768 signed
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R6=8000 (signed min), read back", 4'd6, 16'h8000);

        // ============================================
        // Test 12: Signed-pattern 16'hFFFF
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd7;
        write_data = 16'hFFFF;   // -1 signed
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R7=FFFF (signed -1), read back", 4'd7, 16'hFFFF);

        // ============================================
        // Test 13: Signed-pattern 16'h7FFF
        // ============================================
        test_id = test_id + 1;
        @(posedge clk);
        write_enable = 1;
        write_addr = 4'd8;
        write_data = 16'h7FFF;   // 32767 signed max
        @(posedge clk);
        write_enable = 0;
        #1;
        check_single(test_id, "Write R8=7FFF (signed max), read back", 4'd8, 16'h7FFF);

        // ============================================
        // Test 14: Verify R0 still 0 after many writes
        // ============================================
        test_id = test_id + 1;
        check_single(test_id, "R0 still 0 after many ops", 4'd0, 16'd0);

        // ============================================
        // Test 15: Dual-read signed patterns R6+R8
        // ============================================
        test_id = test_id + 1;
        read_addr1 = 4'd6;
        read_addr2 = 4'd8;
        check(test_id, "Dual-read: R6=8000, R8=7FFF", 16'h8000, 16'h7FFF);

        // ============================================
        // Final report
        // ============================================
        $display("========================================");
        $display("  Register File Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt + fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  OVERALL: PASS");
        else
            $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

endmodule
