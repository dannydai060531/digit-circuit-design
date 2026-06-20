// Compare-Swap Unit for Sorting Network
// Signed 16-bit ascending: a_out = min(a_in, b_in), b_out = max(a_in, b_in)
// Combinational (no clock)

module cmp_swap (
    input  wire signed [15:0] a_in,
    input  wire signed [15:0] b_in,
    output wire signed [15:0] a_out,
    output wire signed [15:0] b_out
);

    wire swap = ($signed(a_in) > $signed(b_in));

    assign a_out = swap ? b_in : a_in;   // min
    assign b_out = swap ? a_in : b_in;   // max

endmodule
