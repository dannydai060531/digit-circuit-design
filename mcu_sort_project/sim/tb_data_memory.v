`timescale 1ns / 1ps

module tb_data_memory;
    reg         clk, rst_n, write_enable, read_enable;
    reg  [6:0]  addr;
    reg  [15:0] wdata, test_vector_in;
    wire [15:0] rdata;
    wire [5:0]  rom_addr, verify_ram_addr, internal_mem_addr;
    wire        rom_rd_en, ram_we, cnt_start, cnt_stop, done, internal_mem_we;
    wire [15:0] verify_vector_out, internal_mem_wdata;

    data_memory uut (
        .clk(clk), .rst_n(rst_n),
        .addr(addr), .wdata(wdata), .rdata(rdata),
        .write_enable(write_enable), .read_enable(read_enable),
        .test_vector_in(test_vector_in),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(verify_ram_addr), .verify_vector_out(verify_vector_out), .ram_we(ram_we),
        .cnt_start(cnt_start), .cnt_stop(cnt_stop), .done(done),
        .internal_mem_we(internal_mem_we), .internal_mem_addr(internal_mem_addr),
        .internal_mem_wdata(internal_mem_wdata)
    );

    always #5 clk = ~clk;
    integer pass_cnt, fail_cnt, test_id;

    initial begin
        clk = 0; rst_n = 0; write_enable = 0; read_enable = 0;
        addr = 0; wdata = 0; test_vector_in = 0;
        pass_cnt = 0; fail_cnt = 0; test_id = 0;
        #30 rst_n = 1;
        @(posedge clk); #1;

        // ============ Test 1-2: Reset ============
        test_id = 1; read_enable = 1; addr = 7'd0; @(negedge clk);
        chk(test_id, "Reset: internal addr 0 = 0", rdata, 16'd0);

        test_id = 2; addr = 7'd63; @(negedge clk);
        chk(test_id, "Reset: internal addr 63 = 0", rdata, 16'd0);
        read_enable = 0;

        // ============ Test 3-5: Internal RAM write/read ============
        test_id = 3;
        @(negedge clk); write_enable = 1; addr = 7'd5; wdata = 16'hABCD;
        @(posedge clk); #1; write_enable = 0;
        read_enable = 1; addr = 7'd5; @(negedge clk);
        chk(test_id, "Internal write/read addr 5=ABCD", rdata, 16'hABCD);
        read_enable = 0;

        test_id = 4;
        @(negedge clk); write_enable = 1; addr = 7'd0; wdata = 16'h1234;
        @(posedge clk); #1; write_enable = 0;
        read_enable = 1; addr = 7'd0; @(negedge clk);
        chk(test_id, "Internal write/read addr 0=1234", rdata, 16'h1234);
        read_enable = 0;

        test_id = 5;
        @(negedge clk); write_enable = 1; addr = 7'd63; wdata = 16'h7FFF;
        @(posedge clk); #1; write_enable = 0;
        read_enable = 1; addr = 7'd63; @(negedge clk);
        chk(test_id, "Internal write/read addr 63=7FFF", rdata, 16'h7FFF);
        read_enable = 0;

        // ============ Test 6: WE=0 prevents write ============
        test_id = 6;
        @(negedge clk); write_enable = 0; addr = 7'd5; wdata = 16'hFFFF;
        @(posedge clk);
        read_enable = 1; addr = 7'd5; @(negedge clk);
        chk(test_id, "WE=0: addr 5 unchanged (ABCD)", rdata, 16'hABCD);
        read_enable = 0;

        // ============ Test 7: IO_ROM_ADDR (0x40) ============
        test_id = 7;
        @(negedge clk); write_enable = 1; addr = 7'd64; wdata = 16'h002A;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_6b(test_id, "IO_ROM_ADDR: rom_addr=42", rom_addr, 6'd42);

        // ============ Test 8-9: IO_ROM_DATA (0x41) ============
        test_id = 8;
        test_vector_in = 16'hBEEF;
        read_enable = 1; addr = 7'd65; @(negedge clk);
        chk(test_id, "IO_ROM_DATA read = BEEF", rdata, 16'hBEEF);
        read_enable = 0;

        test_id = 9;
        test_vector_in = 16'h8000;
        read_enable = 1; addr = 7'd65; @(negedge clk);
        chk(test_id, "IO_ROM_DATA read = 8000", rdata, 16'h8000);
        read_enable = 0;

        // ============ Test 10: IO_RAM_ADDR (0x42) ============
        test_id = 10;
        @(negedge clk); write_enable = 1; addr = 7'd66; wdata = 16'h003F;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_6b(test_id, "IO_RAM_ADDR: verify_ram_addr=63", verify_ram_addr, 6'd63);

        // ============ Test 11: IO_RAM_DATA (0x43) ============
        test_id = 11;
        @(negedge clk); write_enable = 1; addr = 7'd67; wdata = 16'hCAFE;
        @(posedge clk); #1; write_enable = 0; #1;
        chk(test_id, "IO_RAM_DATA: verify_vector_out=CAFE", verify_vector_out, 16'hCAFE);

        // ============ Test 12-14: IO_CONTROL (0x44) ============
        test_id = 12;
        @(negedge clk); write_enable = 1; addr = 7'd68; wdata = 16'h0001;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_1b(test_id, "IO_CONTROL[0]: cnt_start=1", cnt_start, 1'b1);

        test_id = 13;
        @(negedge clk); write_enable = 1; addr = 7'd68; wdata = 16'h0002;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_1b(test_id, "IO_CONTROL[1]: cnt_stop=1", cnt_stop, 1'b1);

        test_id = 14;
        @(negedge clk); write_enable = 1; addr = 7'd68; wdata = 16'h0004;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_1b(test_id, "IO_CONTROL[2]: done=1", done, 1'b1);

        // ============ Test 15: Invalid address ============
        test_id = 15;
        read_enable = 1; addr = 7'd127; @(negedge clk);
        chk(test_id, "Invalid addr 127: rdata=0", rdata, 16'd0);
        read_enable = 0;

        // ============ Test 16: read_enable=0 ============
        test_id = 16;
        read_enable = 0; addr = 7'd63; @(negedge clk);
        chk(test_id, "read_enable=0: rdata=0", rdata, 16'd0);

        // ============ Test 17: Debug internal_mem_we ============
        test_id = 17;
        @(negedge clk); write_enable = 1; addr = 7'd10; wdata = 16'hDEAD;
        @(posedge clk); #1; write_enable = 0; #1;
        chk_1b(test_id, "internal_mem_we deasserted after write", internal_mem_we, 1'b0);

        // ============ Test 18-19: Signed patterns ============
        test_id = 18;
        @(negedge clk); write_enable = 1; addr = 7'd20; wdata = 16'h8000;
        @(posedge clk); #1; write_enable = 0;
        read_enable = 1; addr = 7'd20; @(negedge clk);
        chk(test_id, "Write/read signed 8000", rdata, 16'h8000);
        read_enable = 0;

        test_id = 19;
        @(negedge clk); write_enable = 1; addr = 7'd21; wdata = 16'hFFFF;
        @(posedge clk); #1; write_enable = 0;
        read_enable = 1; addr = 7'd21; @(negedge clk);
        chk(test_id, "Write/read signed FFFF", rdata, 16'hFFFF);
        read_enable = 0;

        // ============ Final ============
        $display("========================================");
        $display("  Data Memory Testbench Results");
        $display("  PASS: %0d / %0d", pass_cnt, pass_cnt+fail_cnt);
        $display("  FAIL: %0d", fail_cnt);
        if (fail_cnt == 0) $display("  OVERALL: PASS");
        else               $display("  OVERALL: FAIL");
        $display("========================================");
        $finish;
    end

    task chk;
        input integer tid; input [127:0] tn;
        input [15:0] act, exp;
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

    task chk_6b;
        input integer tid; input [127:0] tn;
        input [5:0] act, exp;
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

endmodule
