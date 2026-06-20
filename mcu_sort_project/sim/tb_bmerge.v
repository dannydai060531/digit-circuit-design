`timescale 1ns / 1ps

module tb_bmerge;
    reg clk, rst_n, start, is_sort8;
    reg [5:0] base_addr;
    reg [3:0] merge_ncode;
    wire [6:0] mem_addr;
    wire mem_wr;
    wire [15:0] mem_wdata;
    reg  [15:0] mem_rdata;
    wire busy, done;
    reg signed [15:0] mock [0:127];
    integer pass_cnt, fail_cnt, test_id, i, j, k;
    reg signed [15:0] key, ref [0:63];
    reg signed [15:0] saved [0:63];

    sort_accel uut (.clk(clk),.rst_n(rst_n),.start(start),.is_sort8(is_sort8),
        .base_addr(base_addr),.merge_ncode(merge_ncode),
        .mem_addr(mem_addr),.mem_wr(mem_wr),.mem_wdata(mem_wdata),.mem_rdata(mem_rdata),
        .busy(busy),.done(done));
    always #5 clk = ~clk;
    always @(*) mem_rdata = mock[mem_addr];
    always @(negedge clk) if (mem_wr) mock[mem_addr] <= mem_wdata;

    task run_bmerge;
        input integer tid; input [127:0] tn;
        input [6:0] n; input [3:0] nc;
        integer e, err, v;
        begin
            err = 0;
            @(negedge clk); start = 1; is_sort8 = 0; merge_ncode = nc;
            @(posedge clk); #1; start = 0;
            while (!done) @(posedge clk); #1;
            for (e = 0; e < n - 1; e = e + 1) begin
                if (mock[base_addr + e] > mock[base_addr + e + 1]) err = err + 1;
            end
            if (err > 0) begin
                // Print all violations
                for (v = 0; v < n - 1; v = v + 1) begin
                    if (mock[base_addr+v] > mock[base_addr+v+1])
                        $display("  violation at [%0d]: %d > %d", v,
                            mock[base_addr+v], mock[base_addr+v+1]);
                end
                $display("[%0d] FAIL: %s — %0d ordering violations", tid, tn, err);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[%0d] PASS: %s", tid, tn);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; start = 0; is_sort8 = 0;
        base_addr = 6'd20; merge_ncode = 4'd0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        for (i = 0; i < 128; i = i + 1) mock[i] = 16'd0;
        #25 rst_n = 1; @(posedge clk); #1;

        // ============ N=16 tests (N_code=1) ============
        // Test 1: interleaved halves
        test_id = 1;
        for (i=0;i<8;i=i+1) mock[20+i] = i*2+1;      // 1,3,5,7,9,11,13,15
        for (i=0;i<8;i=i+1) mock[28+i] = (i+1)*2;     // 2,4,6,8,10,12,14,16
        run_bmerge(test_id, "N=16 interleaved", 16, 4'd1);

        // Test 2: all left < right
        test_id = 2;
        for (i=0;i<8;i=i+1) mock[20+i] = i+1;          // 1..8
        for (i=0;i<8;i=i+1) mock[28+i] = i+9;          // 9..16
        run_bmerge(test_id, "N=16 left<right", 16, 4'd1);

        // Test 3: all right < left
        test_id = 3;
        for (i=0;i<8;i=i+1) mock[20+i] = i+9;          // 9..16
        for (i=0;i<8;i=i+1) mock[28+i] = i+1;          // 1..8
        run_bmerge(test_id, "N=16 right<left", 16, 4'd1);

        // Test 4: negative mix
        test_id = 4;
        for (i=0;i<8;i=i+1) mock[20+i] = (i-4)*2;      // -8,-6,-4,-2,0,2,4,6
        for (i=0;i<8;i=i+1) mock[28+i] = (i-4)*2+1;    // -7,-5,-3,-1,1,3,5,7
        run_bmerge(test_id, "N=16 negatives", 16, 4'd1);

        // Test 5: duplicates
        test_id = 5;
        for (i=0;i<4;i=i+1) begin mock[20+i*2]=i+1; mock[20+i*2+1]=i+1; end
        for (i=0;i<4;i=i+1) begin mock[28+i*2]=i+1; mock[28+i*2+1]=i+1; end
        run_bmerge(test_id, "N=16 duplicates", 16, 4'd1);

        // Test 6: extremes
        test_id = 6;
        mock[20]=-32768;mock[21]=-100;mock[22]=0;mock[23]=1;mock[24]=2;mock[25]=3;mock[26]=100;mock[27]=32767;
        mock[28]=-32767;mock[29]=-50;mock[30]=-1;mock[31]=0;mock[32]=50;mock[33]=200;mock[34]=16384;mock[35]=32766;
        run_bmerge(test_id, "N=16 extremes", 16, 4'd1);

        // ============ N=32 tests (N_code=2) ============
        test_id = 7;
        for (i=0;i<16;i=i+1) mock[20+i] = i*2;       // 0,2,4,...,30
        for (i=0;i<16;i=i+1) mock[36+i] = i*2+1;      // 1,3,5,...,31
        run_bmerge(test_id, "N=32 sequential", 32, 4'd2);

        test_id = 8;
        for (i=0;i<16;i=i+1) mock[20+i] = i+1;
        for (i=0;i<16;i=i+1) mock[36+i] = i+17;
        run_bmerge(test_id, "N=32 left<right", 32, 4'd2);

        test_id = 9;
        for (i=0;i<16;i=i+1) mock[20+i] = i+17;
        for (i=0;i<16;i=i+1) mock[36+i] = i+1;
        run_bmerge(test_id, "N=32 right<left", 32, 4'd2);

        // ============ N=64 tests (N_code=3) ============
        test_id = 10;
        for (i=0;i<32;i=i+1) mock[20+i] = i*2;
        for (i=0;i<32;i=i+1) mock[52+i] = i*2+1;
        run_bmerge(test_id, "N=64 sequential", 64, 4'd3);

        test_id = 11;
        for (i=0;i<32;i=i+1) mock[20+i] = i+1;
        for (i=0;i<32;i=i+1) mock[52+i] = i+33;
        run_bmerge(test_id, "N=64 left<right", 64, 4'd3);

        test_id = 12;
        for (i=0;i<32;i=i+1) mock[20+i] = i+33;
        for (i=0;i<32;i=i+1) mock[52+i] = i+1;
        run_bmerge(test_id, "N=64 right<left", 64, 4'd3);

        $display("========================================");
        $display("  BMERGE Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end
endmodule
