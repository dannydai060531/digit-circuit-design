// Instruction Memory for ARM-like MCU
// 256 x 16-bit ROM, initialized from .mem file via $readmemh
// PC[7:0] addresses 256 instruction words
// Instruction output is combinational (no clock needed for read)

module instruction_memory (
    input  wire  [7:0]  pc,
    output wire  [15:0] instruction
);

    reg [15:0] mem [0:255];
    integer i;

    // Initialize from .mem file if provided, otherwise zero
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 16'h0000;
        // $readmemh can be used by testbench to load program
    end

    // Combinational read
    assign instruction = mem[pc];

endmodule
