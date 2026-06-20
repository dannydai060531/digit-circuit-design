// Control Unit for ARM-like MCU — Simplified, working version
// Key fixes retained: flag latch in module, reg_read_addr1=rd for accel, LDR/STR ADD, STR mem_wen in MEMORY
module control_unit #(parameter HAS_ACCEL = 0) (
    input  wire clk, rst_n,
    input  wire [15:0] instruction,
    input  wire [7:0]  pc,
    output reg  [2:0]  alu_op,
    output reg         reg_wen,
    output reg  [3:0]  reg_write_addr, reg_read_addr1, reg_read_addr2,
    output reg         mem_wen, mem_ren,
    output reg         pc_load, pc_hold,
    output reg  [7:0]  branch_target,
    output reg         halt,
    output reg  [2:0]  mcu_state,
    output reg         alu_src_a_sel,
    output reg  [1:0]  alu_src_b_sel,
    output reg         flags_update,
    input  wire [15:0] reg_rdata1_val,
    output reg  [7:0]  imm8,
    output reg  [3:0]  imm4,
    output reg         accel_start, accel_is_sort8,
    output reg  [5:0]  accel_base,
    output reg  [3:0]  accel_ncode,
    input  wire        accel_busy, accel_done,
    input  wire        n, z, c, v
);
    wire [3:0] opcode=instruction[15:12], rd=instruction[11:8], rs1=instruction[7:4], rs2=instruction[3:0];
    wire [2:0] cond=instruction[11:9];
    wire link=instruction[11];

    localparam ST_FETCH=0, ST_DECODE=1, ST_EXECUTE=2, ST_MEMORY=3, ST_WRITEBACK=4;
    localparam ST_ACCEL_LOAD=5, ST_ACCEL_STAGE=6, ST_ACCEL_WB=7;
    reg [2:0] state, next_state;

    // Pipelined flags (latched in this module)
    reg n_latched, z_latched, c_latched, v_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {n_latched,z_latched,c_latched,v_latched} <= 0;
        else if (state == ST_EXECUTE && opcode != 4'b1001 && opcode != 4'b1011 && opcode != 4'b0110 && opcode != 4'b0111 && opcode != 4'b1110 && opcode != 4'b1111)
            {n_latched,z_latched,c_latched,v_latched} <= {n,z,c,v};
    end

    wire cond_true = (cond==0)?z_latched:(cond==1)?~z_latched:(cond==2)?(n_latched!=v_latched):(cond==3)?(~z_latched&&n_latched==v_latched):(cond==4)?(z_latched||n_latched!=v_latched):(cond==5)?(n_latched==v_latched):1'b0;

    // Registered accel_start: set during DECODE, sort_accel sees at EXECUTE→ACCEL_LOAD
    reg accel_start_r;
    always @(*) accel_start = accel_start_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) accel_start_r <= 0;
        else if (state == ST_DECODE && (opcode == 4'b1110 || opcode == 4'b1111))
            accel_start_r <= 1;
        else
            accel_start_r <= 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_FETCH;
        else state <= next_state;
    end

    always @(*) begin
        alu_op=3'b100; reg_wen=0; reg_write_addr=rd; reg_read_addr1=rs1; reg_read_addr2=rs2;
        mem_wen=0; mem_ren=0; pc_load=0; pc_hold=1'b1; branch_target=0; halt=0; mcu_state=state;
        alu_src_a_sel=0; alu_src_b_sel=2'b00; flags_update=1'b1; imm8=instruction[7:0]; imm4=rs2;
        accel_is_sort8=0; accel_base=0; accel_ncode=0; next_state=ST_FETCH;

        if (opcode == 4'b1110 || opcode == 4'b1111) reg_read_addr1 = rd;

        case (state)
            ST_FETCH: next_state = ST_DECODE;
            ST_DECODE: begin
                if (opcode == 4'b1010) begin halt=1; next_state=ST_DECODE; end
                else next_state = ST_EXECUTE;
            end
            ST_EXECUTE: case (opcode)
                4'b0000: begin alu_op=0; alu_src_a_sel=0; alu_src_b_sel=0; next_state=ST_MEMORY; end
                4'b0001: begin alu_op=1; alu_src_a_sel=0; alu_src_b_sel=0; next_state=ST_MEMORY; end
                4'b0010: begin alu_op=2; alu_src_a_sel=0; alu_src_b_sel=0; next_state=ST_MEMORY; end
                4'b0011: begin alu_op=3; alu_src_a_sel=0; alu_src_b_sel=0; next_state=ST_MEMORY; end
                4'b0100: begin alu_op=4; alu_src_a_sel=0; alu_src_b_sel=2; next_state=ST_MEMORY; end
                4'b0101: begin alu_op=4; alu_src_a_sel=0; alu_src_b_sel=2; next_state=ST_MEMORY; end
                4'b0110: begin alu_op=0; alu_src_a_sel=0; alu_src_b_sel=0; flags_update=0; next_state=ST_MEMORY; mem_ren=1; end
                4'b0111: begin alu_op=0; alu_src_a_sel=0; alu_src_b_sel=0; flags_update=0; next_state=ST_MEMORY; end
                4'b1000: begin alu_op=1; alu_src_a_sel=0; alu_src_b_sel=0; pc_hold=0; next_state=ST_FETCH; end
                4'b1001: begin flags_update=0; next_state=ST_MEMORY; end
                4'b1011: begin flags_update=0; if(cond_true) next_state=ST_MEMORY; else begin pc_hold=0; next_state=ST_FETCH; end end
                4'b1100: begin alu_op=0; alu_src_a_sel=0; alu_src_b_sel=1; next_state=ST_MEMORY; end
                4'b1101: begin alu_op=1; alu_src_a_sel=0; alu_src_b_sel=1; next_state=ST_MEMORY; end
                4'b1110: if(HAS_ACCEL) begin accel_start=1; accel_is_sort8=1; accel_base=rd; next_state=ST_ACCEL_LOAD; end else next_state=ST_FETCH;
                4'b1111: if(HAS_ACCEL&&(rs1==1||rs1==2||rs1==3)) begin accel_start=1; accel_is_sort8=0; accel_base=rd; accel_ncode=rs1; next_state=ST_ACCEL_LOAD; end else next_state=ST_FETCH;
                default: next_state=ST_FETCH;
            endcase
            ST_MEMORY: begin
                if(opcode==4'b0111) begin mem_wen=1; reg_read_addr2=rd; end
                if(opcode==4'b1001) begin branch_target=pc+1+{{5{instruction[10]}},instruction[10:0]}; pc_hold=0; pc_load=1; if(link) begin reg_wen=1; reg_write_addr=15; end end
                if(opcode==4'b1011&&cond_true) begin branch_target=pc+1+{{7{instruction[8]}},instruction[8:0]}; pc_hold=0; pc_load=1; end
                next_state = ST_WRITEBACK;
                if(opcode==4'b1001||(opcode==4'b1011&&cond_true)) next_state=ST_FETCH;
            end
            ST_WRITEBACK: begin
                pc_hold=0; if(opcode==4'b0110) mem_ren=1;
                case(opcode) 4'b0000,4'b0001,4'b0010,4'b0011,4'b0100,4'b0101,4'b0110,4'b1100,4'b1101: reg_wen=1; endcase
                next_state=ST_FETCH;
            end
            ST_ACCEL_LOAD: begin pc_hold=1; next_state=ST_ACCEL_STAGE; end
            ST_ACCEL_STAGE: begin pc_hold=1; if(accel_done) next_state=ST_ACCEL_WB; else next_state=ST_ACCEL_STAGE; end
            ST_ACCEL_WB: begin pc_hold=0; next_state=ST_FETCH; end
            default: next_state=ST_FETCH;
        endcase
    end
endmodule
