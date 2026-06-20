// Register File for ARM-like MCU
// 16 registers x 16-bit, dual read (combinational), single write (synchronous)
// R0 is hardwired to 16'd0 — writes to R0 are ignored
// All registers reset to 0

module register_file (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         write_enable,
    input  wire  [3:0]  read_addr1,
    input  wire  [3:0]  read_addr2,
    input  wire  [3:0]  write_addr,
    input  wire  [15:0] write_data,
    output wire  [15:0] read_data1,
    output wire  [15:0] read_data2
);

    reg [15:0] regs [0:15];
    integer i;

    // Synchronous write (posedge clk)
    // Writes to R0 are silently ignored
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 16'd0;
        end else if (write_enable && write_addr != 4'd0) begin
            regs[write_addr] <= write_data;
        end
    end

    // Combinational read: R0 is hardwired to 0
    assign read_data1 = (read_addr1 == 4'd0) ? 16'd0 : regs[read_addr1];
    assign read_data2 = (read_addr2 == 4'd0) ? 16'd0 : regs[read_addr2];

endmodule
