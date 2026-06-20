// Program Counter for ARM-like MCU
// PC[7:0] — 8-bit, addresses 256 instruction words
// Supports: reset, increment (PC+1), branch target load, hold (during stall)

module program_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_load,       // load branch target
    input  wire        pc_hold,       // stall PC (e.g. during multi-cycle ops)
    input  wire [7:0]  branch_target,
    output reg  [7:0]  pc
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 8'd0;
        end else if (pc_hold) begin
            pc <= pc;                    // stall
        end else if (pc_load) begin
            pc <= branch_target;         // branch / jump
        end else begin
            pc <= pc + 8'd1;             // sequential
        end
    end

endmodule
