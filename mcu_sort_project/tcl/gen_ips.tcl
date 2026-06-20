set part "xc7k160tffg676-2"
set proj_dir "C:/Users/danny/mcu_sort_project/vivado_ip"
set coe_path "C:/Users/danny/mcu_sort_project/coe/test_vector.coe"

create_project -force ip_gen $proj_dir -part $part

# test_ROM: 64x16 ROM
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name test_ROM
set_property -dict [list \
    CONFIG.Component_Name {test_ROM} \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Write_Width_A {16} \
    CONFIG.Write_Depth_A {64} \
    CONFIG.Read_Width_A {16} \
    CONFIG.Operating_Mode_A {WRITE_FIRST} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File $coe_path \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Port_A_Write_Rate {0} \
    CONFIG.Port_A_Clock {100} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Use_RSTA_Pin {false} \
] [get_ips test_ROM]
generate_target all [get_ips test_ROM]
puts "test_ROM generated"

# verify_RAM: 64x16 RAM
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name verify_RAM
set_property -dict [list \
    CONFIG.Component_Name {verify_RAM} \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Write_Width_A {16} \
    CONFIG.Write_Depth_A {64} \
    CONFIG.Read_Width_A {16} \
    CONFIG.Operating_Mode_A {WRITE_FIRST} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Use_RSTA_Pin {false} \
] [get_ips verify_RAM]
generate_target all [get_ips verify_RAM]
puts "verify_RAM generated"

# ILA: 16384 depth, 25 probes
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_mcu
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {16384} \
    CONFIG.C_NUM_OF_PROBES {25} \
    CONFIG.C_PROBE0_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE2_WIDTH {1}  \
    CONFIG.C_PROBE3_WIDTH {6}  \
    CONFIG.C_PROBE4_WIDTH {16} \
    CONFIG.C_PROBE5_WIDTH {20} \
    CONFIG.C_PROBE6_WIDTH {1}  \
    CONFIG.C_PROBE7_WIDTH {8}  \
    CONFIG.C_PROBE8_WIDTH {16} \
    CONFIG.C_PROBE9_WIDTH {3}  \
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
puts "ila_mcu generated"

close_project
puts "=== All IPs generated successfully ==="
