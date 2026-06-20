# MCU Sorting Project — Efficiency vs Speed

Vivado 2020.2 FPGA project for xc7k160tffg676-2.

Two ARM-like MCU versions sort 64 signed 16-bit integers from test_ROM to verify_RAM.

## Versions
- **Efficiency**: Insertion Sort, pure MCU instructions (HAS_ACCEL=0)
- **Speed**: SORT8 + BMERGE hardware accelerator (HAS_ACCEL=1)

## Quick Build
```powershell
# Efficiency
vivado -mode batch -source tcl/build_efficiency.tcl

# Speed
vivado -mode batch -source tcl/build_speed.tcl
```

## Simulation
```powershell
# Module-level (example)
xvlog sim/tb_alu.v rtl/common/alu.v
xelab tb_alu -s snap; xsim snap -R
```

## Reports
After build, run:
```powershell
python scripts/parse_reports.py
```
