// Sorting Accelerator — SORT8 + BMERGE (synthesis-safe)
// All compare-swap networks hardcoded per stage
module sort_accel (
    input  wire clk, rst_n, start, is_sort8,
    input  wire [5:0] base_addr,
    input  wire [3:0] merge_ncode,
    output reg  [6:0] mem_addr,
    output reg  mem_wr,
    output reg  [15:0] mem_wdata,
    input  wire [15:0] mem_rdata,
    output reg  busy, done
);
    reg signed [15:0] dbuf [0:63];
    integer ii;

    localparam S_IDLE=0, S_LOAD=1, S_SORT=2, S_WB=3;
    reg [2:0] state;
    reg [6:0] count, total_count;
    reg [5:0] stage;
    reg [6:0] dist;
    reg is_bmerge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; busy<=0; done<=0; mem_wr<=0; mem_addr<=0; mem_wdata<=0;
            count<=0; stage<=0; dist<=0;
            for (ii=0; ii<64; ii=ii+1) dbuf[ii]<=0;
        end else case (state)
            S_IDLE: begin
                done<=0; mem_wr<=0;
                $display("ACCEL S_IDLE: start=%b busy=%b", start, busy);
                if (start) begin
                    busy<=1; count<=0; stage<=0; is_bmerge<=~is_sort8;
                    if (is_sort8) begin total_count<=8; end
                    else case (merge_ncode)
                        4'd1: total_count<=16; 4'd2: total_count<=32;
                        4'd3: total_count<=64; default: total_count<=8;
                    endcase
                    mem_addr<={1'b0,base_addr}; state<=S_LOAD;
                end
            end
            S_LOAD: begin
                if (count>0) dbuf[count-1]<=mem_rdata;
                if (count<total_count) begin
                    if (is_bmerge && count>=(total_count>>1))
                        mem_addr<={1'b0,base_addr}+(total_count-1-(count-(total_count>>1)));
                    else mem_addr<={1'b0,base_addr}+{1'b0,count};
                    count<=count+1;
                end else begin
                    count<=0; stage<=0;
                    if (is_bmerge) dist<=total_count>>1;
                    state<=S_SORT;
                end
            end
            S_SORT: begin
                if (is_sort8) begin
                    case (stage)
                        0: begin cmp(0,1);cmp(2,3);cmp(4,5);cmp(6,7); end
                        1: begin cmp(0,2);cmp(1,3);cmp(4,6);cmp(5,7); end
                        2: begin cmp(1,2);cmp(5,6); end
                        3: begin cmp(0,4);cmp(1,5);cmp(2,6);cmp(3,7); end
                        4: begin cmp(2,4);cmp(3,5); end
                        5: begin cmp(1,2);cmp(3,4);cmp(5,6); end
                    endcase
                    if (stage<5) stage<=stage+1; else begin count<=0; state<=S_WB; mem_addr<={1'b0,base_addr}; end
                end else begin
                    case (total_count)
                        16: bm16(stage);
                        32: bm32(stage);
                        64: bm64(stage);
                    endcase
                    if (dist>1) begin dist<=dist>>1; stage<=stage+1; end
                    else begin count<=0; state<=S_WB; mem_addr<={1'b0,base_addr}; end
                end
            end
            S_WB: begin
                if (count<total_count) begin
                    mem_wr<=1; mem_addr<={1'b0,base_addr}+{1'b0,count};
                    mem_wdata<=dbuf[count]; count<=count+1;
                end else begin mem_wr<=0; busy<=0; done<=1; state<=S_IDLE; end
            end
        endcase
    end

    task cmp; input [5:0] a,b; reg signed [15:0] va,vb;
        begin va=dbuf[a]; vb=dbuf[b]; if (va>vb) begin dbuf[a]=vb; dbuf[b]=va; end end
    endtask

    task bm16; input [5:0] s;
        case (s)
            0: begin cmp(0,8);cmp(1,9);cmp(2,10);cmp(3,11);cmp(4,12);cmp(5,13);cmp(6,14);cmp(7,15); end
            1: begin cmp(0,4);cmp(1,5);cmp(2,6);cmp(3,7);cmp(8,12);cmp(9,13);cmp(10,14);cmp(11,15); end
            2: begin cmp(0,2);cmp(1,3);cmp(4,6);cmp(5,7);cmp(8,10);cmp(9,11);cmp(12,14);cmp(13,15); end
            3: begin cmp(0,1);cmp(2,3);cmp(4,5);cmp(6,7);cmp(8,9);cmp(10,11);cmp(12,13);cmp(14,15); end
        endcase endtask

    task bm32; input [5:0] s;
        case (s)
            0: begin cmp(0,16);cmp(1,17);cmp(2,18);cmp(3,19);cmp(4,20);cmp(5,21);cmp(6,22);cmp(7,23);
                cmp(8,24);cmp(9,25);cmp(10,26);cmp(11,27);cmp(12,28);cmp(13,29);cmp(14,30);cmp(15,31); end
            1: begin cmp(0,8);cmp(1,9);cmp(2,10);cmp(3,11);cmp(4,12);cmp(5,13);cmp(6,14);cmp(7,15);
                cmp(16,24);cmp(17,25);cmp(18,26);cmp(19,27);cmp(20,28);cmp(21,29);cmp(22,30);cmp(23,31); end
            2: begin cmp(0,4);cmp(1,5);cmp(2,6);cmp(3,7);cmp(8,12);cmp(9,13);cmp(10,14);cmp(11,15);
                cmp(16,20);cmp(17,21);cmp(18,22);cmp(19,23);cmp(24,28);cmp(25,29);cmp(26,30);cmp(27,31); end
            3: begin cmp(0,2);cmp(1,3);cmp(4,6);cmp(5,7);cmp(8,10);cmp(9,11);cmp(12,14);cmp(13,15);
                cmp(16,18);cmp(17,19);cmp(20,22);cmp(21,23);cmp(24,26);cmp(25,27);cmp(28,30);cmp(29,31); end
            4: begin cmp(0,1);cmp(2,3);cmp(4,5);cmp(6,7);cmp(8,9);cmp(10,11);cmp(12,13);cmp(14,15);
                cmp(16,17);cmp(18,19);cmp(20,21);cmp(22,23);cmp(24,25);cmp(26,27);cmp(28,29);cmp(30,31); end
        endcase endtask

    task bm64; input [5:0] s;
        case (s)
            0: begin cmp(0,32);cmp(1,33);cmp(2,34);cmp(3,35);cmp(4,36);cmp(5,37);cmp(6,38);cmp(7,39);
                cmp(8,40);cmp(9,41);cmp(10,42);cmp(11,43);cmp(12,44);cmp(13,45);cmp(14,46);cmp(15,47);
                cmp(16,48);cmp(17,49);cmp(18,50);cmp(19,51);cmp(20,52);cmp(21,53);cmp(22,54);cmp(23,55);
                cmp(24,56);cmp(25,57);cmp(26,58);cmp(27,59);cmp(28,60);cmp(29,61);cmp(30,62);cmp(31,63); end
            1: begin cmp(0,16);cmp(1,17);cmp(2,18);cmp(3,19);cmp(4,20);cmp(5,21);cmp(6,22);cmp(7,23);
                cmp(8,24);cmp(9,25);cmp(10,26);cmp(11,27);cmp(12,28);cmp(13,29);cmp(14,30);cmp(15,31);
                cmp(32,48);cmp(33,49);cmp(34,50);cmp(35,51);cmp(36,52);cmp(37,53);cmp(38,54);cmp(39,55);
                cmp(40,56);cmp(41,57);cmp(42,58);cmp(43,59);cmp(44,60);cmp(45,61);cmp(46,62);cmp(47,63); end
            2: begin cmp(0,8);cmp(1,9);cmp(2,10);cmp(3,11);cmp(4,12);cmp(5,13);cmp(6,14);cmp(7,15);
                cmp(16,24);cmp(17,25);cmp(18,26);cmp(19,27);cmp(20,28);cmp(21,29);cmp(22,30);cmp(23,31);
                cmp(32,40);cmp(33,41);cmp(34,42);cmp(35,43);cmp(36,44);cmp(37,45);cmp(38,46);cmp(39,47);
                cmp(48,56);cmp(49,57);cmp(50,58);cmp(51,59);cmp(52,60);cmp(53,61);cmp(54,62);cmp(55,63); end
            3: begin cmp(0,4);cmp(1,5);cmp(2,6);cmp(3,7);cmp(8,12);cmp(9,13);cmp(10,14);cmp(11,15);
                cmp(16,20);cmp(17,21);cmp(18,22);cmp(19,23);cmp(24,28);cmp(25,29);cmp(26,30);cmp(27,31);
                cmp(32,36);cmp(33,37);cmp(34,38);cmp(35,39);cmp(40,44);cmp(41,45);cmp(42,46);cmp(43,47);
                cmp(48,52);cmp(49,53);cmp(50,54);cmp(51,55);cmp(56,60);cmp(57,61);cmp(58,62);cmp(59,63); end
            4: begin cmp(0,2);cmp(1,3);cmp(4,6);cmp(5,7);cmp(8,10);cmp(9,11);cmp(12,14);cmp(13,15);
                cmp(16,18);cmp(17,19);cmp(20,22);cmp(21,23);cmp(24,26);cmp(25,27);cmp(28,30);cmp(29,31);
                cmp(32,34);cmp(33,35);cmp(36,38);cmp(37,39);cmp(40,42);cmp(41,43);cmp(44,46);cmp(45,47);
                cmp(48,50);cmp(49,51);cmp(52,54);cmp(53,55);cmp(56,58);cmp(57,59);cmp(60,62);cmp(61,63); end
            5: begin cmp(0,1);cmp(2,3);cmp(4,5);cmp(6,7);cmp(8,9);cmp(10,11);cmp(12,13);cmp(14,15);
                cmp(16,17);cmp(18,19);cmp(20,21);cmp(22,23);cmp(24,25);cmp(26,27);cmp(28,29);cmp(30,31);
                cmp(32,33);cmp(34,35);cmp(36,37);cmp(38,39);cmp(40,41);cmp(42,43);cmp(44,45);cmp(46,47);
                cmp(48,49);cmp(50,51);cmp(52,53);cmp(54,55);cmp(56,57);cmp(58,59);cmp(60,61);cmp(62,63); end
        endcase endtask
endmodule
