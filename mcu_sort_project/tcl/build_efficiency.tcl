set proj_name "mcu_efficiency"
set proj_dir  "C:/Users/danny/mcu_sort_project/vivado_efficiency"
set part      "xc7k160tffg676-2"
set rtl_dir   "C:/Users/danny/mcu_sort_project/rtl"
set rpt_dir   "C:/Users/danny/mcu_sort_project/reports"
set bit_dir   "C:/Users/danny/mcu_sort_project/bitstream"
set cons_dir  "C:/Users/danny/mcu_sort_project/constraints"

file mkdir $rpt_dir
file mkdir $bit_dir

create_project -force $proj_name $proj_dir -part $part

set rtl_files [glob -nocomplain $rtl_dir/common/*.v]
lappend rtl_files $rtl_dir/cnt_test.v
lappend rtl_files $rtl_dir/top_level_efficiency.v
add_files -norecurse $rtl_files
set_property top top_level_efficiency [current_fileset]
add_files -fileset constrs_1 $cons_dir/timing.xdc

synth_design -top top_level_efficiency -part $part
opt_design
place_design
route_design

report_utilization      -file $rpt_dir/efficiency_util.rpt
report_timing_summary   -file $rpt_dir/efficiency_timing.rpt

write_bitstream -force $bit_dir/mcu_efficiency.bit

close_project
puts "=== Efficiency build complete ==="
