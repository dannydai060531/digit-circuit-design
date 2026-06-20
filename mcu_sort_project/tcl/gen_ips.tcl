# Generate test_ROM, verify_RAM, and ILA IP cores
# Run before build_efficiency.tcl or build_speed.tcl
set part "xc7k160tffg676-2"
set proj_dir "C:/Users/danny/mcu_sort_project/vivado_ip"

create_project -force ip_gen $proj_dir -part $part

# --- test_ROM: 64x16 Single Port ROM ---
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name test_ROM
set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Width_A {16} \
    CONFIG.Depth_A {64} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File {C:/Users/danny/mcu_sort_project/coe/test_vector.coe} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
] [get_ips test_ROM]
generate_target all [get_ips test_ROM]

# --- verify_RAM: 64x16 Single Port RAM ---
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name verify_RAM
set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Width_A {16} \
    CONFIG.Depth_A {64} \
    CONFIG.Write_Mode_A {Write_First} \
] [get_ips verify_RAM]
generate_target all [get_ips verify_RAM]

# --- ILA: Integrated Logic Analyzer ---
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_mcu
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {16384} \
    CONFIG.C_NUM_OF_PROBES {25} \
    CONFIG.C_PROBE0_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {6} \
    CONFIG.C_PROBE4_WIDTH {16} \
    CONFIG.C_PROBE5_WIDTH {20} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {8} \
    CONFIG.C_PROBE8_WIDTH {16} \
    CONFIG.C_PROBE9_WIDTH {3} \
    CONFIG.C_PROBE10_WIDTH {6} \
    CONFIG.C_PROBE11_WIDTH {1} \
    CONFIG.C_PROBE12_WIDTH {1} \
    CONFIG.C_PROBE13_WIDTH {6} \
    CONFIG.C_PROBE14_WIDTH {16} \
    CONFIG.C_PROBE15_WIDTH {1} \
    CONFIG.C_PROBE16_WIDTH {1} \
    CONFIG.C_PROBE17_WIDTH {1} \
    CONFIG.C_PROBE18_WIDTH {4} \
    CONFIG.C_PROBE19_WIDTH {3} \
    CONFIG.C_PROBE20_WIDTH {6} \
    CONFIG.C_PROBE21_WIDTH {6} \
    CONFIG.C_PROBE22_WIDTH {6} \
    CONFIG.C_PROBE23_WIDTH {1} \
    CONFIG.C_PROBE24_WIDTH {1} \
] [get_ips ila_mcu]
generate_target all [get_ips ila_mcu]

close_project
puts "=== IP generation complete ==="
puts "Generated: test_ROM, verify_RAM, ila_mcu"
