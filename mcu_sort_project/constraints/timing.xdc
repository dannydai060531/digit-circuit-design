# Timing constraint: 50 MHz clock (20 ns period)
create_clock -period 20.000 -name sys_clk [get_ports clk]

# Disable I/O constraint DRC checks for prototype builds without board pin assignment
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
