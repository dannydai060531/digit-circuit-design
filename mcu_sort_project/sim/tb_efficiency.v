`timescale 1ns / 1ps
module tb_efficiency;
    reg clk, rst_n, test_vector_in;
    wire done;
    wire [7:0] debug_pc;
    wire [15:0] debug_instruction;

    mcu_core #(.HAS_ACCEL(0)) uut (
        .clk(clk), .rst_n(rst_n), .test_vector_in(16'd0),
        .rom_addr(), .rom_rd_en(), .verify_ram_addr(), .verify_vector_out(),
        .ram_we(), .cnt_start(), .cnt_stop(), .done(done),
        .debug_pc(debug_pc), .debug_instruction(debug_instruction),
        .debug_state(), .debug_internal_mem_we(), .debug_internal_mem_addr(),
        .debug_internal_mem_wdata());

    always #5 clk = ~clk;
    integer pass, fail, i, cyc;

    task load_prog; input integer n;
        begin
            rst_n = 0; #20;
            for (i=0; i<256; i=i+1) uut.u_imem.mem[i] = 16'h0000;
        end
    endtask

    task run_wait;
        begin
            rst_n = 1; #1; cyc = 0;
            while (!done && cyc < 500) begin @(posedge clk); cyc = cyc + 1; end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; test_vector_in = 0; pass = 0; fail = 0;

        // Test 1: MOVL R1,#100; MOVL R2,#20; ADD R1,R1,R2; HALT
        load_prog(0);
        uut.u_imem.mem[0] = 16'h4164;  // MOVL R1,#100
        uut.u_imem.mem[1] = 16'h4214;  // MOVL R2,#20
        uut.u_imem.mem[2] = 16'h0112;  // ADD R1,R1,R2
        uut.u_imem.mem[3] = 16'hA000;  // HALT
        run_wait();
        if (uut.u_rf.regs[1] === 16'd120 && uut.u_rf.regs[2] === 16'd20 && done) begin
            $display("PASS T1: R1=120 R2=20 done=1 (%0d cyc)", cyc); pass = pass + 1;
        end else begin $display("FAIL T1: R1=%0d R2=%0d done=%b", uut.u_rf.regs[1], uut.u_rf.regs[2], done); fail = fail + 1; end

        // Test 2: CMP+BGT loop (countdown 5→0)
        // 0:MOVL R1,#5  1:SUBI R1,#1  2:CMP R1,R0  3:BGT -3(offset=-3,cond=GT=011)  4:HALT
        load_prog(0);
        uut.u_imem.mem[0] = 16'h4105;
        uut.u_imem.mem[1] = 16'hD111;
        uut.u_imem.mem[2] = 16'h8010;  // CMP R1,R0
        uut.u_imem.mem[3] = {4'b1011, 3'b011, 9'h1FD};  // BGT offset=-3
        uut.u_imem.mem[4] = 16'hA000;
        run_wait();
        if (uut.u_rf.regs[1] === 16'd0 && done) begin
            $display("PASS T2: BGT loop R1=0 (%0d cyc)", cyc); pass = pass + 1;
        end else begin $display("FAIL T2: R1=%0d done=%b", uut.u_rf.regs[1], done); fail = fail + 1; end

        // Test 3: SUBI + CMP negative: MOVL R1,#10; SUBI R1,R1,#15; HALT
        load_prog(0);
        uut.u_imem.mem[0] = 16'h410A;  // MOVL R1,#10
        uut.u_imem.mem[1] = {4'b1101, 4'd1, 4'd1, 4'd15};  // SUBI R1,R1,#15
        uut.u_imem.mem[2] = 16'hA000;
        run_wait();
        if ($signed(uut.u_rf.regs[1]) === -5 && done) begin
            $display("PASS T3: R1=-5 (%0d cyc)", cyc); pass = pass + 1;
        end else begin $display("FAIL T3: R1=%0d", $signed(uut.u_rf.regs[1])); fail = fail + 1; end

        // Test 4: B +2 branch skip
        load_prog(0);
        uut.u_imem.mem[0] = {4'b1001, 1'b0, 11'd2};  // B +2 → PC=3
        uut.u_imem.mem[1] = 16'h4163;  // MOVL R1,#99 (skipped)
        uut.u_imem.mem[2] = 16'h4163;  // MOVL R1,#99 (skipped)
        uut.u_imem.mem[3] = 16'h422A;  // MOVL R2,#42
        uut.u_imem.mem[4] = 16'hA000;
        run_wait();
        if (uut.u_rf.regs[2] === 16'd42 && uut.u_rf.regs[1] === 16'd0 && done) begin
            $display("PASS T4: B+2: R2=42 R1=0 (%0d cyc)", cyc); pass = pass + 1;
        end else begin $display("FAIL T4: R1=%0d R2=%0d", uut.u_rf.regs[1], uut.u_rf.regs[2]); fail = fail + 1; end

        $display("===== Efficiency Simulation: PASS=%0d FAIL=%0d =====", pass, fail);
        if (fail == 0) $display("OVERALL: PASS"); else $display("OVERALL: FAIL");
        $finish;
    end
endmodule
