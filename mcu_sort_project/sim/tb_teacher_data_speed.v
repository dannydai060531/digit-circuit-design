`timescale 1ns / 1ps
module tb_teacher_data_speed;
    reg clk, rst_n;
    reg [15:0] tvi;
    wire done;
    wire [5:0] rom_addr; wire rom_rd_en;

    mcu_core #(.HAS_ACCEL(1)) uut (
        .clk(clk),.rst_n(rst_n),.test_vector_in(tvi),
        .rom_addr(rom_addr),.rom_rd_en(rom_rd_en),
        .verify_ram_addr(),.verify_vector_out(),.ram_we(),
        .cnt_start(),.cnt_stop(),.done(done),
        .debug_pc(),.debug_instruction(),.debug_state(),
        .debug_internal_mem_we(),.debug_internal_mem_addr(),.debug_internal_mem_wdata());

    always #5 clk = ~clk;
    reg [15:0] rom_data[0:639];
    reg [15:0] golden[0:639];
    integer i, j, cyc, pass, fail;
    always @(*) tvi = rom_data[rom_addr];

    initial begin
        clk=0; rst_n=0; tvi=0; pass=0; fail=0;
        $readmemh("C:/Users/danny/mcu_sort_project/coe/sort_input.mem", rom_data);
        $readmemh("C:/Users/danny/mcu_sort_project/coe/sort_output.mem", golden);
        $readmemh("C:/Users/danny/mcu_sort_project/asm/sort_speed.mem", uut.u_imem.mem);

        rst_n=0; #20; rst_n=1; #1;
        cyc=0; while(!done && cyc<200000) begin @(posedge clk); cyc=cyc+1; end

        if(done) begin
            j=0; for(i=0;i<64;i=i+1) if(uut.u_dm.int_ram[i]!==golden[i]) j=j+1;
            if(j==0) begin
                $display("PASS: Speed teacher data sorted correctly (%0d cycles)", cyc);
                pass=pass+1;
            end else begin
                $display("FAIL: %0d mismatches. Got[0:3]=%d,%d,%d,%d Exp[0:3]=%d,%d,%d,%d",
                    j,uut.u_dm.int_ram[0],uut.u_dm.int_ram[1],uut.u_dm.int_ram[2],uut.u_dm.int_ram[3],
                    golden[0],golden[1],golden[2],golden[3]);
                fail=fail+1;
            end
        end else begin
            $display("FAIL: Speed timeout after %0d cycles", cyc); fail=fail+1;
        end

        $display("===== Speed Teacher Test: PASS=%0d FAIL=%0d =====", pass, fail);
        if(fail==0) $display("OVERALL: PASS"); else $display("OVERALL: FAIL");
        $finish;
    end
endmodule
