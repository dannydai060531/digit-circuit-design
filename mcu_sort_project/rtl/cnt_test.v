// cnt_test — 20-bit Standalone Counter
// Independent module, NOT inside MCU
// Starts counting on cnt_start rising edge
// Must not pause after starting
// Stops only on cnt_stop rising edge
// Final count held after stop

module cnt_test (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         cnt_start,
    input  wire         cnt_stop,
    output reg  [19:0]  count,
    output reg           counting
);

    reg started;
    reg stopped;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= 20'd0;
            counting <= 1'b0;
            started  <= 1'b0;
            stopped  <= 1'b0;
        end else begin
            // Latch start (edge detect)
            if (cnt_start && !started && !stopped) begin
                started  <= 1'b1;
                counting <= 1'b1;
            end

            // Latch stop (edge detect)
            if (cnt_stop && started && !stopped) begin
                stopped  <= 1'b1;
                counting <= 1'b0;
            end

            // Count while active (use started/stopped to avoid NBA race)
            if (started && !stopped) begin
                count <= count + 20'd1;
            end
        end
    end

endmodule
