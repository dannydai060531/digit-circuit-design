set proj_name "mcu_speed"
set proj_dir  "C:/Users/danny/mcu_sort_project/vivado_speed"
set part      "xc7k160tffg676-2"
set rtl_dir   "C:/Users/danny/mcu_sort_project/rtl"
set rpt_dir   "C:/Users/danny/mcu_sort_project/reports"
set bit_dir   "C:/Users/danny/mcu_sort_project/bitstream"
set cons_dir  "C:/Users/danny/mcu_sort_project/constraints"

file mkdir $rpt_dir
file mkdir $bit_dir

create_project -force $proj_name $proj_dir -part $part

set rtl_files [glob -nocomplain $rtl_dir/common/*.v]
lappend rtl_files $rtl_dir/cmp_swap.v
lappend rtl_files $rtl_dir/sort_accel.v
lappend rtl_files $rtl_dir/cnt_test.v
lappend rtl_files $rtl_dir/top_level_speed.v
add_files -norecurse $rtl_files
set_property top top_level_speed [current_fileset]
add_files -fileset constrs_1 $cons_dir/timing.xdc

synth_design -top top_level_speed -part $part
opt_design
place_design
route_design

report_utilization      -file $rpt_dir/speed_util.rpt
report_timing_summary   -file $rpt_dir/speed_timing.rpt

write_bitstream -force $bit_dir/mcu_speed.bit

close_project
puts "=== Speed build complete ==="
