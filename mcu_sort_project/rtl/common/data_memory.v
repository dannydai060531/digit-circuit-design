// Data Memory + Memory-Mapped I/O Bridge for ARM-like MCU
// Internal RAM: 64 x 16-bit (addresses 0x00–0x3F)
// I/O registers: 0x40–0x46
//
// Address map:
//   0x00–0x3F: internal data RAM (R/W)
//   0x40: IO_ROM_ADDR   (W)  -> rom_addr[5:0]
//   0x41: IO_ROM_DATA   (R)  <- test_vector_in[15:0]
//   0x42: IO_RAM_ADDR   (W)  -> verify_ram_addr[5:0]
//   0x43: IO_RAM_DATA   (W)  -> verify_vector_out[15:0], ram_we pulse
//   0x44: IO_CONTROL    (W)  -> cnt_start, cnt_stop, done
//   0x45: IO_SORT_CTL   (W)  debug only
//   0x46: IO_MERGE_CTL  (W)  debug only

module data_memory (
    input  wire         clk,
    input  wire         rst_n,

    // MCU-side interface
    input  wire  [6:0]  addr,          // mcu_data_addr[6:0]
    input  wire  [15:0] wdata,
    output wire  [15:0] rdata,
    input  wire         write_enable,
    input  wire         read_enable,

    // test_ROM interface
    input  wire  [15:0] test_vector_in,
    output reg   [5:0]  rom_addr,
    output reg          rom_rd_en,

    // verify_RAM interface
    output reg   [5:0]  verify_ram_addr,
    output reg   [15:0] verify_vector_out,
    output reg          ram_we,

    // Control signals
    output reg          cnt_start,
    output reg          cnt_stop,
    output reg          done,

    // Internal RAM debug (for ILA)
    output wire         internal_mem_we,
    output wire  [5:0]  internal_mem_addr,
    output wire  [15:0] internal_mem_wdata
);

    // Internal RAM: 64 x 16-bit
    reg [15:0] int_ram [0:63];
    integer i;

    // Address decode
    wire is_internal = (addr >= 7'd0  && addr <= 7'd63);   // 0x00–0x3F
    wire is_rom_addr = (addr == 7'd64);                     // 0x40
    wire is_rom_data = (addr == 7'd65);                     // 0x41
    wire is_ram_addr = (addr == 7'd66);                     // 0x42
    wire is_ram_data = (addr == 7'd67);                     // 0x43
    wire is_control  = (addr == 7'd68);                     // 0x44
    wire is_sort_ctl = (addr == 7'd69);                     // 0x45 debug
    wire is_merge_ctl= (addr == 7'd70);                     // 0x46 debug

    // Synchronous write + reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 64; i = i + 1)
                int_ram[i] <= 16'd0;
            rom_addr        <= 6'd0;
            rom_rd_en       <= 1'b0;
            verify_ram_addr <= 6'd0;
            verify_vector_out <= 16'd0;
            ram_we          <= 1'b0;
            cnt_start       <= 1'b0;
            cnt_stop        <= 1'b0;
            done            <= 1'b0;
        end else begin
            // Default: deassert pulsed signals
            rom_rd_en <= 1'b0;
            ram_we    <= 1'b0;

            if (write_enable) begin
                if (is_internal) begin
                    int_ram[addr[5:0]] <= wdata;
                end
                else if (is_rom_addr) begin
                    rom_addr  <= wdata[5:0];
                    rom_rd_en <= 1'b1;          // pulse ROM read
                end
                else if (is_ram_addr) begin
                    verify_ram_addr <= wdata[5:0];
                end
                else if (is_ram_data) begin
                    verify_vector_out <= wdata;
                    ram_we <= 1'b1;             // pulse RAM write
                end
                else if (is_control) begin
                    cnt_start <= wdata[0];
                    cnt_stop  <= wdata[1];
                    done      <= wdata[2];
                end
                // 0x45, 0x46: debug only, store but no external effect
            end
        end
    end

    // Combinational read
    assign rdata = (read_enable && is_internal)  ? int_ram[addr[5:0]] :
                   (read_enable && is_rom_data)  ? test_vector_in :
                   16'd0;

    // Debug outputs (combinational, for ILA)
    assign internal_mem_we    = write_enable && is_internal;
    assign internal_mem_addr  = addr[5:0];
    assign internal_mem_wdata = wdata;

endmodule
