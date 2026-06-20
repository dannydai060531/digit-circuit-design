// Control Unit for ARM-like MCU
// Decodes 16-bit instructions, generates control signals, manages main FSM
// Parameter HAS_ACCEL: 0 = no SORT8/BMERGE, 1 = enable accelerator opcodes
//
// Main FSM (non-pipelined, 1 cycle per state):
//   FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK → FETCH
//   HALT stops at DECODE
//   SORT8/BMERGE insert multi-cycle sub-states during EXECUTE

module control_unit #(
    parameter HAS_ACCEL = 0
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [15:0]  instruction,
    input  wire [7:0]   pc,

    // ALU control
    output reg  [2:0]   alu_op,

    // Register file control
    output reg           reg_wen,
    output reg  [3:0]    reg_write_addr,
    output reg  [3:0]    reg_read_addr1,
    output reg  [3:0]    reg_read_addr2,

    // Data memory control
    output reg           mem_wen,
    output reg           mem_ren,

    // PC control
    output reg           pc_load,
    output reg           pc_hold,
    output reg  [7:0]    branch_target,

    // Misc
    output reg           halt,
    output reg  [2:0]    mcu_state,     // for ILA

    input  wire [15:0]  reg_rdata1_val, // register value for accel base

    // ALU source selects
    output reg           alu_src_a_sel,
    output reg  [1:0]    alu_src_b_sel,
    output reg           flags_update,

    // Immediate extraction
    output reg  [7:0]    imm8,
    output reg  [3:0]    imm4,

    // Accelerator control (only when HAS_ACCEL=1)
    output reg           accel_start,
    output reg  [5:0]    accel_base,
    output reg  [3:0]    accel_ncode,    // BMERGE N_code
    output reg           accel_is_sort8, // 1=SORT8, 0=BMERGE
    input  wire          accel_busy,
    input  wire          accel_done,

    // NZCV flags from ALU (for Bcc)
    input  wire          n, z, c, v
);

    // Opcode extraction
    wire [3:0] opcode   = instruction[15:12];
    wire [3:0] rd       = instruction[11:8];
    wire [3:0] rs1      = instruction[7:4];
    wire [3:0] rs2      = instruction[3:0];
    wire [2:0] cond     = instruction[11:9];
    wire [8:0] imm9     = instruction[8:0];
    wire [10:0] imm11  = instruction[10:0];
    wire        link    = instruction[11];

    // State encoding
    localparam ST_FETCH     = 3'd0;
    localparam ST_DECODE    = 3'd1;
    localparam ST_EXECUTE   = 3'd2;
    localparam ST_MEMORY    = 3'd3;
    localparam ST_WRITEBACK = 3'd4;
    // Accelerator sub-states (extend EXECUTE)
    localparam ST_ACCEL_LOAD  = 3'd5;
    localparam ST_ACCEL_STAGE = 3'd6;
    localparam ST_ACCEL_WB    = 3'd7;

    reg [2:0] state, next_state;
    reg [5:0] accel_stage_cnt;
    reg [5:0] accel_stage_max;

    // Pipelined flags (latched in this module to avoid NBA timing issues)
    reg n_latched, z_latched, c_latched, v_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_latched <= 1'b0; z_latched <= 1'b0; c_latched <= 1'b0; v_latched <= 1'b0;
        end else if (state == ST_EXECUTE && opcode != 4'b1001 && opcode != 4'b1011 && opcode != 4'b0110 && opcode != 4'b0111) begin
            n_latched <= n; z_latched <= z; c_latched <= c; v_latched <= v;
        end
    end

    wire cond_true;
    assign cond_true =
        (cond == 3'd0) ? z_latched :
        (cond == 3'd1) ? ~z_latched :
        (cond == 3'd2) ? (n_latched != v_latched) :
        (cond == 3'd3) ? (~z_latched && (n_latched == v_latched)) :
        (cond == 3'd4) ? (z_latched || (n_latched != v_latched)) :
        (cond == 3'd5) ? (n_latched == v_latched) :
        1'b0;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_FETCH;
            accel_stage_cnt <= 6'd0;
            accel_stage_max <= 6'd0;
        end else begin
            state <= next_state;
            if (state == ST_ACCEL_LOAD)
                accel_stage_cnt <= 6'd0;
            else if (state == ST_ACCEL_STAGE)
                accel_stage_cnt <= accel_stage_cnt + 6'd1;
        end
    end

    // Next state logic + control signal generation
    always @(*) begin
        // Defaults
        alu_op         = 3'b100;  // PASSA
        reg_wen        = 1'b0;
        reg_write_addr = rd;
        reg_read_addr1 = rs1;
        reg_read_addr2 = rs2;
        mem_wen        = 1'b0;
        mem_ren        = 1'b0;
        pc_load        = 1'b0;
        pc_hold        = 1'b1;  // hold PC except when explicitly released
        branch_target  = 8'd0;
        halt           = 1'b0;
        mcu_state      = state;
        alu_src_a_sel  = 1'b0;   // register
        alu_src_b_sel  = 2'b00;  // register rs2
        imm8           = instruction[7:0];
        imm4           = rs2;
        flags_update   = 1'b1;
        accel_start    = 1'b0;
        // Pre-set reg_read_addr1 for SORT8/BMERGE base register
        if (opcode == 4'b1110 || opcode == 4'b1111) reg_read_addr1 = rd;
        accel_base     = 6'd0;
        accel_ncode    = 4'd0;
        accel_is_sort8 = 1'b0;
        next_state     = ST_FETCH;

        case (state)
            ST_FETCH: begin
                next_state = ST_DECODE;
            end

            ST_DECODE: begin
                next_state = ST_EXECUTE;
                // HALT stops here
                if (opcode == 4'b1010) begin  // HALT
                    halt = 1'b1;
                    next_state = ST_DECODE;  // stay here
                end
            end

            ST_EXECUTE: begin
                case (opcode)
                    4'b0000: begin  // ADD
                        alu_op = 3'b000;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        next_state = ST_MEMORY;
                    end
                    4'b0001: begin  // SUB
                        alu_op = 3'b001;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        next_state = ST_MEMORY;
                    end
                    4'b0010: begin  // AND
                        alu_op = 3'b010;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        next_state = ST_MEMORY;
                    end
                    4'b0011: begin  // OR
                        alu_op = 3'b011;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        next_state = ST_MEMORY;
                    end
                    4'b0100: begin  // MOVL
                        alu_op = 3'b100;  // PASSA: pass imm8 through
                        alu_src_a_sel = 1'b0;  // dummy, result comes from ALU PASSA
                        alu_src_b_sel = 2'b10; // imm8
                        next_state = ST_MEMORY;
                    end
                    4'b0101: begin  // MOVH
                        alu_op = 3'b100;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b10; // imm8
                        next_state = ST_MEMORY;
                    end
                    4'b0110: begin  // LDR: addr = base + index
                        alu_op = 3'b000;  // ADD
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        flags_update = 1'b0;
                        next_state = ST_MEMORY;
                        mem_ren = 1'b1;
                    end
                    4'b0111: begin  // STR: addr=base+index (rs1+rs2)
                        alu_op = 3'b000;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        flags_update = 1'b0;
                        next_state = ST_MEMORY;
                    end
                    4'b1000: begin  // CMP
                        alu_op = 3'b001;
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b00;
                        pc_hold = 1'b0;  // advance PC
                        next_state = ST_FETCH;
                    end
                    4'b1001: begin  // B/BL
                        flags_update = 1'b0;
                        next_state = ST_MEMORY;
                    end
                    4'b1011: begin  // Bcc
                        flags_update = 1'b0;
                        if (cond_true) begin
                            next_state = ST_MEMORY;
                        end else begin
                            pc_hold = 1'b0;  // advance PC past branch
                            next_state = ST_FETCH;
                        end
                    end
                    4'b1100: begin  // ADDI
                        alu_op = 3'b000;  // ADD
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b01; // imm4
                        next_state = ST_MEMORY;
                    end
                    4'b1101: begin  // SUBI
                        alu_op = 3'b001;  // SUB
                        alu_src_a_sel = 1'b0;
                        alu_src_b_sel = 2'b01; // imm4
                        next_state = ST_MEMORY;
                    end
                    4'b1110: begin  // SORT8
                        if (HAS_ACCEL) begin
                            reg_read_addr1 = rd;  // Rbase register is at [11:8]
                            accel_start = 1'b1;
                            accel_base = reg_rdata1_val[5:0];
                            accel_is_sort8 = 1'b1;
                            next_state = ST_ACCEL_LOAD;
                        end else begin
                            next_state = ST_FETCH;
                        end
                    end
                    4'b1111: begin  // BMERGE
                        if (HAS_ACCEL && (rs1 == 4'd1 || rs1 == 4'd2 || rs1 == 4'd3)) begin
                            reg_read_addr1 = rd;  // Rbase register at [11:8]
                            accel_start = 1'b1;
                            accel_base = reg_rdata1_val[5:0];
                            accel_ncode = rs1;
                            accel_is_sort8 = 1'b0;
                            next_state = ST_ACCEL_LOAD;
                        end else begin
                            next_state = ST_FETCH;
                        end
                    end
                    default: begin
                        next_state = ST_FETCH;
                    end
                endcase
            end

            ST_MEMORY: begin
                if (opcode == 4'b0111) begin
                    mem_wen = 1'b1;
                    reg_read_addr2 = rd;  // keep STR source reg active
                end
                if (opcode == 4'b1001) begin  // B/BL
                    branch_target = pc + 8'd1 + {{5{imm11[10]}}, imm11[10:0]};
                    pc_hold = 1'b0;
                    pc_load = 1'b1;
                    reg_wen = link;
                    if (link) reg_write_addr = 4'd15;
                end
                if (opcode == 4'b1011 && cond_true) begin  // Bcc taken
                    branch_target = pc + 8'd1 + {{7{imm9[8]}}, imm9[8:0]};
                    pc_hold = 1'b0;
                    pc_load = 1'b1;
                end
                next_state = ST_WRITEBACK;
                if (opcode == 4'b1001 || (opcode == 4'b1011 && cond_true))
                    next_state = ST_FETCH;  // branches go to fetch
            end

            ST_WRITEBACK: begin
                pc_hold = 1'b0;
                // Keep mem_ren active during WB for LDR data capture
                if (opcode == 4'b0110) mem_ren = 1'b1;
                case (opcode)
                    4'b0000, 4'b0001, 4'b0010, 4'b0011,
                    4'b0100, 4'b0101, 4'b0110,
                    4'b1100, 4'b1101: begin
                        reg_wen = 1'b1;
                    end
                endcase
                next_state = ST_FETCH;
            end

            ST_ACCEL_LOAD: begin
                accel_start = 1'b1;
                accel_is_sort8 = (opcode == 4'b1110);
                if (opcode == 4'b1111) accel_ncode = rs1;
                pc_hold = 1'b1;
                next_state = ST_ACCEL_STAGE;
            end

            ST_ACCEL_STAGE: begin
                accel_start = 1'b1;
                accel_is_sort8 = (opcode == 4'b1110);
                if (accel_done) begin
                    next_state = ST_ACCEL_WB;
                end else begin
                    next_state = ST_ACCEL_STAGE;
                end
            end

            ST_ACCEL_WB: begin
                // Accelerator writes results to data memory internally
                // No register writeback needed (SORT8/BMERGE operate on memory)
                pc_hold = 1'b0;
                next_state = ST_FETCH;
            end

            default: next_state = ST_FETCH;
        endcase
    end

endmodule
