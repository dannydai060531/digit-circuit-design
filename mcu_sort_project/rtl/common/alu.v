module alu (
    input  wire        [2:0]  alu_op,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [15:0] result,
    output reg                n,
    output reg                z,
    output reg                c,
    output reg                v
);

    wire [16:0] add_17 = {1'b0, a} + {1'b0, b};
    wire [16:0] sub_17 = {1'b0, a} - {1'b0, b};

    always @(*) begin
        case (alu_op)
            3'b000: begin
                result = add_17[15:0];
                n = result[15];
                z = (result == 16'd0);
                c = add_17[16];
                v = (a[15] == b[15]) && (result[15] != a[15]);
            end

            3'b001: begin
                result = sub_17[15:0];
                n = result[15];
                z = (result == 16'd0);
                c = ({1'b0, a} >= {1'b0, b});
                v = (a[15] != b[15]) && (result[15] != a[15]);
            end

            3'b010: begin
                result = a & b;
                n = result[15];
                z = (result == 16'd0);
                c = 1'b0;
                v = 1'b0;
            end

            3'b011: begin
                result = a | b;
                n = result[15];
                z = (result == 16'd0);
                c = 1'b0;
                v = 1'b0;
            end

            3'b100: begin
                result = a;
                n = result[15];
                z = (result == 16'd0);
                c = 1'b0;
                v = 1'b0;
            end

            default: begin
                result = 16'd0;
                n = 1'b0;
                z = 1'b1;
                c = 1'b0;
                v = 1'b0;
            end
        endcase
    end

endmodule
