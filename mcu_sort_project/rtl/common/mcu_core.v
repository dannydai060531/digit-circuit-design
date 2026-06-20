module mcu_core #(parameter HAS_ACCEL = 0) (
    input  wire clk, rst_n,
    input  wire [15:0] test_vector_in,
    output wire [5:0]  rom_addr, verify_ram_addr,
    output wire        rom_rd_en, ram_we, cnt_start, cnt_stop, done,
    output wire [15:0] verify_vector_out,
    output wire [7:0]  debug_pc,
    output wire [15:0] debug_instruction,
    output wire [2:0]  debug_state,
    output wire        debug_internal_mem_we,
    output wire [5:0]  debug_internal_mem_addr,
    output wire [15:0] debug_internal_mem_wdata
);
    wire [7:0] pc, branch_target;
    wire pc_load, pc_hold, halt, reg_wen, mem_wen, mem_ren;
    wire [15:0] instruction, reg_rdata1, reg_rdata2, reg_wdata, alu_a, alu_b, alu_result, mem_rdata, mem_wdata_real;
    wire [6:0] mem_addr;
    wire [2:0] alu_op, mcu_state;
    wire [3:0] reg_write_addr, reg_read_addr1, reg_read_addr2;
    wire alu_src_a_sel; wire [1:0] alu_src_b_sel;
    wire [7:0] imm8; wire [3:0] imm4; wire n,z,c,v;
    wire dm_done;

    program_counter u_pc (
        .clk(clk), .rst_n(rst_n), .pc_load(pc_load), .pc_hold(pc_hold),
        .branch_target(branch_target), .pc(pc));
    instruction_memory u_imem (.pc(pc), .instruction(instruction));

    reg [15:0] ir;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ir <= 16'h0000;
        else if (mcu_state == 3'd0) ir <= instruction;
    end

    wire accel_start, accel_is_sort8, accel_busy, accel_done;
    wire [5:0] accel_base;
    wire [3:0] accel_ncode;
    wire [6:0] accel_mem_addr;
    wire accel_mem_wr;
    wire [15:0] accel_mem_wdata;

    control_unit #(.HAS_ACCEL(HAS_ACCEL)) u_ctrl (
        .clk(clk), .rst_n(rst_n), .instruction(ir), .pc(pc),
        .alu_op(alu_op), .reg_wen(reg_wen), .reg_write_addr(reg_write_addr),
        .reg_read_addr1(reg_read_addr1), .reg_read_addr2(reg_read_addr2),
        .mem_wen(mem_wen), .mem_ren(mem_ren),
        .pc_load(pc_load), .pc_hold(pc_hold), .branch_target(branch_target),
        .halt(halt), .mcu_state(mcu_state),
        .alu_src_a_sel(alu_src_a_sel), .alu_src_b_sel(alu_src_b_sel),
        .imm8(imm8), .imm4(imm4),
        .accel_start(accel_start), .accel_base(accel_base),
        .accel_ncode(accel_ncode), .accel_is_sort8(accel_is_sort8),
        .accel_busy(accel_busy), .accel_done(accel_done),
        .n(n), .z(z), .c(c), .v(v));

    register_file u_rf (
        .clk(clk), .rst_n(rst_n), .write_enable(reg_wen),
        .read_addr1(reg_read_addr1), .read_addr2(reg_read_addr2),
        .write_addr(reg_write_addr), .write_data(reg_wdata),
        .read_data1(reg_rdata1), .read_data2(reg_rdata2));

    assign alu_a = alu_src_a_sel ? {8'd0, pc} : reg_rdata1;
    wire [15:0] zext_imm4 = {12'h000, imm4};  // ADDI/SUBI use unsigned 0-15
    wire [10:0] imm11 = ir[10:0];
    wire [15:0] sext_imm11 = {{5{imm11[10]}}, imm11};
    assign alu_b = (alu_src_b_sel==2'b00) ? reg_rdata2 :
                   (alu_src_b_sel==2'b01) ? zext_imm4 :
                   (alu_src_b_sel==2'b10) ? {8'h00, imm8} : sext_imm11;

    alu u_alu (.alu_op(alu_op), .a(alu_a), .b(alu_b), .result(alu_result),
               .n(n), .z(z), .c(c), .v(v));

    // Pipeline register: latch ALU result during EXECUTE
    reg [15:0] alu_result_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) alu_result_reg <= 16'd0;
        else if (mcu_state == 3'd2) alu_result_reg <= alu_result;  // latch in EXECUTE
    end
    wire [15:0] alu_result_pipe = (mcu_state == 3'd2) ? alu_result : alu_result_reg;

    assign mem_addr = alu_result_pipe[6:0];
    assign mem_wdata_real = (ir[15:12]==4'b0111) ? reg_rdata2 : alu_result_pipe;

    generate if (HAS_ACCEL) begin : gen_accel
        sort_accel u_accel (
            .clk(clk), .rst_n(rst_n),
            .start(accel_start), .is_sort8(accel_is_sort8),
            .base_addr(accel_base), .merge_ncode(accel_ncode),
            .mem_addr(accel_mem_addr), .mem_wr(accel_mem_wr),
            .mem_wdata(accel_mem_wdata), .mem_rdata(mem_rdata),
            .busy(accel_busy), .done(accel_done));
    end else begin : gen_no_accel
        assign accel_busy = 1'b0;
        assign accel_done = 1'b0;
        assign accel_mem_addr = 7'd0;
        assign accel_mem_wr = 1'b0;
        assign accel_mem_wdata = 16'd0;
    end endgenerate

    wire accel_active = (HAS_ACCEL && accel_busy);
    wire [6:0]  dm_addr  = accel_active ? accel_mem_addr  : mem_addr;
    wire        dm_wen   = accel_active ? accel_mem_wr    : mem_wen;
    wire [15:0] dm_wdata = accel_active ? accel_mem_wdata : mem_wdata_real;
    wire        dm_ren   = accel_active ? 1'b1            : mem_ren;

    data_memory u_dm (
        .clk(clk), .rst_n(rst_n), .addr(dm_addr),
        .wdata(dm_wdata), .rdata(mem_rdata),
        .write_enable(dm_wen), .read_enable(dm_ren),
        .test_vector_in(test_vector_in),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(verify_ram_addr), .verify_vector_out(verify_vector_out),
        .ram_we(ram_we), .cnt_start(cnt_start), .cnt_stop(cnt_stop),
        .done(dm_done),
        .internal_mem_we(debug_internal_mem_we),
        .internal_mem_addr(debug_internal_mem_addr),
        .internal_mem_wdata(debug_internal_mem_wdata));

    wire is_ldr  = (ir[15:12]==4'b0110);
    wire is_movl = (ir[15:12]==4'b0100);
    wire is_movh = (ir[15:12]==4'b0101);
    assign reg_wdata = is_ldr ? mem_rdata : is_movl ? {8'h00, imm8} :
                       is_movh ? {imm8, reg_rdata1[7:0]} : alu_result_pipe;
    assign done = dm_done | halt;

    // Reconnect data_memory with final muxed signals
    // (Need to redo the data_memory connection below... actually it's above,
    //  so move the mux logic before the instantiation)

    assign debug_pc = pc; assign debug_instruction = ir; assign debug_state = mcu_state;
endmodule
