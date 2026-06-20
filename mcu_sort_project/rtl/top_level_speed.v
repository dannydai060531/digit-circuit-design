// Top level for Speed MCU (HAS_ACCEL=1)
module top_level_speed (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [15:0]  test_vector_in,
    output wire [5:0]   rom_addr,
    output wire         rom_rd_en,
    output wire [5:0]   verify_ram_addr,
    output wire [15:0]  verify_vector_out,
    output wire         ram_we,
    output wire [19:0]  cnt_test,
    output wire         done,
    output wire [7:0]   debug_pc,
    output wire [15:0]  debug_instruction,
    output wire [2:0]   debug_state,
    output wire         debug_internal_mem_we,
    output wire [5:0]   debug_internal_mem_addr,
    output wire [15:0]  debug_internal_mem_wdata
);

    wire cnt_start, cnt_stop;

    mcu_core #(.HAS_ACCEL(1)) u_mcu (
        .clk(clk), .rst_n(rst_n),
        .test_vector_in(test_vector_in),
        .rom_addr(rom_addr), .rom_rd_en(rom_rd_en),
        .verify_ram_addr(verify_ram_addr), .verify_vector_out(verify_vector_out),
        .ram_we(ram_we),
        .cnt_start(cnt_start), .cnt_stop(cnt_stop), .done(done),
        .debug_pc(debug_pc), .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        .debug_internal_mem_we(debug_internal_mem_we),
        .debug_internal_mem_addr(debug_internal_mem_addr),
        .debug_internal_mem_wdata(debug_internal_mem_wdata)
    );

    cnt_test u_cnt (
        .clk(clk), .rst_n(rst_n),
        .cnt_start(cnt_start), .cnt_stop(cnt_stop),
        .count(cnt_test), .counting()
    );

endmodule
