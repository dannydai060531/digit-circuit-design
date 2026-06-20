`timescale 1ns / 1ps

module tb_sort8;
    reg clk, rst_n, start, is_sort8;
    reg [5:0] base_addr;
    reg [3:0] merge_ncode;
    wire [6:0] mem_addr;
    wire mem_wr;
    wire [15:0] mem_wdata;
    reg  [15:0] mem_rdata;
    wire busy, done;

    // Mock memory: 128 x 16-bit
    reg signed [15:0] mock_mem [0:127];
    integer i;

    sort_accel uut (
        .clk(clk), .rst_n(rst_n), .start(start), .is_sort8(is_sort8),
        .base_addr(base_addr), .merge_ncode(merge_ncode),
        .mem_addr(mem_addr), .mem_wr(mem_wr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .busy(busy), .done(done)
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id;
    reg signed [15:0] expected [0:7];

    // Combinational mock memory read
    always @(*) mem_rdata = mock_mem[mem_addr];

    // Capture writes
    // Capture writes at negedge to avoid race with sort_accel NBA
    always @(negedge clk) if (mem_wr) mock_mem[mem_addr] <= mem_wdata;

    // Run one SORT8 test
    task test_sort8;
        input integer tid;
        input [127:0] tname;
        input signed [15:0] d0, d1, d2, d3, d4, d5, d6, d7;
        integer k, ii, jj;
        reg signed [15:0] key;
        reg signed [15:0] r0, r1, r2, r3, r4, r5, r6, r7;
        begin
            // Load test data into mock memory at base_addr
            mock_mem[base_addr + 0] = d0; mock_mem[base_addr + 1] = d1;
            mock_mem[base_addr + 2] = d2; mock_mem[base_addr + 3] = d3;
            mock_mem[base_addr + 4] = d4; mock_mem[base_addr + 5] = d5;
            mock_mem[base_addr + 6] = d6; mock_mem[base_addr + 7] = d7;

            // Reference sorted (insertion sort on 8 scalars)
            r0 = d0; r1 = d1; r2 = d2; r3 = d3;
            r4 = d4; r5 = d5; r6 = d6; r7 = d7;
            // Unrolled insertion sort on the 8-element array via scalars
            // (Using mock_mem as a workspace for simplicity)
            for (ii = 1; ii < 8; ii = ii + 1) begin
                key = mock_mem[base_addr + ii];
                jj = ii - 1;
                while (jj >= 0 && mock_mem[base_addr + jj] > key) begin
                    mock_mem[base_addr + jj + 1] = mock_mem[base_addr + jj];
                    jj = jj - 1;
                end
                mock_mem[base_addr + jj + 1] = key;
            end
            // Save reference
            r0 = mock_mem[base_addr + 0]; r1 = mock_mem[base_addr + 1];
            r2 = mock_mem[base_addr + 2]; r3 = mock_mem[base_addr + 3];
            r4 = mock_mem[base_addr + 4]; r5 = mock_mem[base_addr + 5];
            r6 = mock_mem[base_addr + 6]; r7 = mock_mem[base_addr + 7];

            // Re-load original data (reference sort overwrote it)
            mock_mem[base_addr + 0] = d0; mock_mem[base_addr + 1] = d1;
            mock_mem[base_addr + 2] = d2; mock_mem[base_addr + 3] = d3;
            mock_mem[base_addr + 4] = d4; mock_mem[base_addr + 5] = d5;
            mock_mem[base_addr + 6] = d6; mock_mem[base_addr + 7] = d7;

            // Start SORT8
            @(negedge clk); start = 1; is_sort8 = 1;
            @(posedge clk); #1; start = 0;

            // Wait for done
            while (!done) @(posedge clk); #1;

            // Check results against reference
            if (mock_mem[base_addr+0] !== r0 || mock_mem[base_addr+1] !== r1 ||
                mock_mem[base_addr+2] !== r2 || mock_mem[base_addr+3] !== r3 ||
                mock_mem[base_addr+4] !== r4 || mock_mem[base_addr+5] !== r5 ||
                mock_mem[base_addr+6] !== r6 || mock_mem[base_addr+7] !== r7) begin
                $display("[%0d] FAIL: %s", tid, tname);
                $display("  got:      %d,%d,%d,%d,%d,%d,%d,%d",
                         mock_mem[base_addr+0], mock_mem[base_addr+1],
                         mock_mem[base_addr+2], mock_mem[base_addr+3],
                         mock_mem[base_addr+4], mock_mem[base_addr+5],
                         mock_mem[base_addr+6], mock_mem[base_addr+7]);
                $display("  expected: %d,%d,%d,%d,%d,%d,%d,%d",
                         r0, r1, r2, r3, r4, r5, r6, r7);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tname);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; start = 0; is_sort8 = 0;
        base_addr = 6'd10; merge_ncode = 4'd0;
        for (i = 0; i < 128; i = i + 1) mock_mem[i] = 16'd0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        #25 rst_n = 1; @(posedge clk); #1;

        // ============================================
        // Category 1: Already sorted (1 test)
        // ============================================
        test_id = 1;
        test_sort8(test_id, "Already sorted: 0,1,2,3,4,5,6,7",
                   0, 1, 2, 3, 4, 5, 6, 7);

        // ============================================
        // Category 2: Reverse sorted (1 test)
        // ============================================
        test_id = 2;
        test_sort8(test_id, "Reverse sorted: 7,6,5,4,3,2,1,0",
                   7, 6, 5, 4, 3, 2, 1, 0);

        // ============================================
        // Category 3: Duplicates (3 tests)
        // ============================================
        test_id = 3;
        test_sort8(test_id, "Dup: 5,5,5,1,1,1,9,9",
                   5, 5, 5, 1, 1, 1, 9, 9);

        test_id = 4;
        test_sort8(test_id, "Dup: all same 3,3,3,3,3,3,3,3",
                   3, 3, 3, 3, 3, 3, 3, 3);

        test_id = 5;
        test_sort8(test_id, "Dup: pairs 1,1,2,2,3,3,4,4",
                   1, 1, 2, 2, 3, 3, 4, 4);

        // ============================================
        // Category 4: Mixed positive/negative (5 tests)
        // ============================================
        test_id = 6;
        test_sort8(test_id, "Mixed: -5,3,-2,8,-1,0,7,-3",
                   -5, 3, -2, 8, -1, 0, 7, -3);

        test_id = 7;
        test_sort8(test_id, "Mixed: 100,-50,200,-150,50,0,-100,150",
                   100, -50, 200, -150, 50, 0, -100, 150);

        test_id = 8;
        test_sort8(test_id, "Mixed: -1,1,-1,1,-1,1,-1,1",
                   -1, 1, -1, 1, -1, 1, -1, 1);

        test_id = 9;
        test_sort8(test_id, "Mixed: all negative -10,-20,-30,-40,-50,-60,-70,-80",
                   -10, -20, -30, -40, -50, -60, -70, -80);

        test_id = 10;
        test_sort8(test_id, "Mixed: 32767,-32768,0,1,-1,100,-100,50",
                   32767, -32768, 0, 1, -1, 100, -100, 50);

        // ============================================
        // Category 5: Signed extremes (5 tests)
        // ============================================
        test_id = 11;
        test_sort8(test_id, "Extreme: 0x7FFF x8",
                   32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767);

        test_id = 12;
        test_sort8(test_id, "Extreme: 0x8000 x8",
                   -32768, -32768, -32768, -32768, -32768, -32768, -32768, -32768);

        test_id = 13;
        test_sort8(test_id, "Extreme: 0,0x7FFF,0x8000,0x7FFF,0x8000,0,1,-1",
                   0, 32767, -32768, 32767, -32768, 0, 1, -1);

        test_id = 14;
        test_sort8(test_id, "Extreme: 0x7FFF,0x7FFE,0x8000,0x8001,0,1,-1,2",
                   32767, 32766, -32768, -32767, 0, 1, -1, 2);

        test_id = 15;
        test_sort8(test_id, "Extreme: 0xFFFF(-1),0xFFFE(-2),0,1,2,0x7FFF,0x8000,3",
                   -1, -2, 0, 1, 2, 32767, -32768, 3);

        // ============================================
        // Category 6: Random (20 tests)
        // ============================================
        test_id = 16;
        test_sort8(test_id, "Rand1: 3,1,4,1,5,9,2,6",
                   3, 1, 4, 1, 5, 9, 2, 6);

        test_id = 17;
        test_sort8(test_id, "Rand2: 8,7,6,5,4,3,2,1",
                   8, 7, 6, 5, 4, 3, 2, 1);

        test_id = 18;
        test_sort8(test_id, "Rand3: 42,17,99,3,55,23,88,1",
                   42, 17, 99, 3, 55, 23, 88, 1);

        test_id = 19;
        test_sort8(test_id, "Rand4: -42,17,-99,3,-55,23,-88,1",
                   -42, 17, -99, 3, -55, 23, -88, 1);

        test_id = 20;
        test_sort8(test_id, "Rand5: 256,128,64,32,16,8,4,2",
                   256, 128, 64, 32, 16, 8, 4, 2);

        test_id = 21;
        test_sort8(test_id, "Rand6: 0,0,0,1,0,0,0,0",
                   0, 0, 0, 1, 0, 0, 0, 0);

        test_id = 22;
        test_sort8(test_id, "Rand7: 1,0,0,0,0,0,0,0",
                   1, 0, 0, 0, 0, 0, 0, 0);

        test_id = 23;
        test_sort8(test_id, "Rand8: 0,0,0,0,0,0,0,1",
                   0, 0, 0, 0, 0, 0, 0, 1);

        test_id = 24;
        test_sort8(test_id, "Rand9: -1,-2,-4,-8,-16,-32,-64,-128",
                   -1, -2, -4, -8, -16, -32, -64, -128);

        test_id = 25;
        test_sort8(test_id, "Rand10: 128,64,0,-64,-128,32,-32,16",
                   128, 64, 0, -64, -128, 32, -32, 16);

        test_id = 26;
        test_sort8(test_id, "Rand11: 1000,2000,500,1500,3000,0,2500,100",
                   1000, 2000, 500, 1500, 3000, 0, 2500, 100);

        test_id = 27;
        test_sort8(test_id, "Rand12: 12345,23456,3456,7890,1111,22222,5555,9999",
                   12345, 23456, 3456, 7890, 1111, 22222, 5555, 9999);

        test_id = 28;
        test_sort8(test_id, "Rand13: 1,10,100,1000,10000,2,20,200",
                   1, 10, 100, 1000, 10000, 2, 20, 200);

        test_id = 29;
        test_sort8(test_id, "Rand14: -32767,-16384,-8192,-4096,-2048,-1024,-512,-256",
                   -32767, -16384, -8192, -4096, -2048, -1024, -512, -256);

        test_id = 30;
        test_sort8(test_id, "Rand15: all zero",
                   0, 0, 0, 0, 0, 0, 0, 0);

        test_id = 31;
        test_sort8(test_id, "Rand16: alternating hi/lo",
                   32767, -32768, 32767, -32768, 32767, -32768, 32767, -32768);

        test_id = 32;
        test_sort8(test_id, "Rand17: powers of 2",
                   1, 2, 4, 8, 16, 32, 64, 128);

        test_id = 33;
        test_sort8(test_id, "Rand18: neg powers of 2",
                   -1, -2, -4, -8, -16, -32, -64, -128);

        test_id = 34;
        test_sort8(test_id, "Rand19: 5,-5,5,-5,0,0,0,0",
                   5, -5, 5, -5, 0, 0, 0, 0);

        test_id = 35;
        test_sort8(test_id, "Rand20: 16384,8192,4096,-16384,-8192,0,24576,-4096",
                   16384, 8192, 4096, -16384, -8192, 0, 24576, -4096);

        // ============================================
        $display("========================================");
        $display("  SORT8 Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0 && pass_cnt >= 35) $display("  OVERALL: PASS (BLOCKING GATE MET)");
        else begin
            $display("  OVERALL: FAIL");
            $display("  SORT8 integration into MCU is BLOCKED");
        end
        $display("========================================");
        $finish;
    end

endmodule
