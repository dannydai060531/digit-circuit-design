# MCU 排序工程 CLAUDE.md

## Project Goal

This is a Vivado 2020.2 FPGA project for an ARM-like MCU sorting system.

The project must implement two board-verifiable MCU versions:

1. efficiency version

* resource-oriented
* HAS_ACCEL=0
* insertion sort in MCU assembly
* no sorting accelerator

2. speed version

* performance-oriented
* HAS_ACCEL=1
* SORT8 + BMERGE hardware acceleration
* acceleration must be triggered by MCU instruction fetch/decode/execute

The target FPGA part is:

xc7k160tffg676-2

The system sorts 64 signed 16-bit integers from external ROM and writes sorted results to external RAM.

Final acceptance is based on board-level behavior, not simulation alone.

## Required External Names

These names are mandatory and must not be changed:

* ROM IP module: test_ROM
* ROM output signal: test_vector_in
* RAM IP module: verify_RAM
* RAM input signal: verify_vector_out
* counter module/signal: cnt_test

## Board-Level Acceptance

Final correctness is judged by:

1. test_vector_in observed from the ROM output
2. verify_RAM contents after execution
3. verify_vector_out during RAM writes
4. cnt_test final count
5. ILA waveform
6. implemented timing report with WNS >= 0

Simulation is only a development self-check. Do not claim final success based only on simulation.

## Counter Requirement

cnt_test must be an independent 20-bit counter module.

Rules:

1. cnt_test starts when the first input data from test_ROM is successfully stored into internal data memory.
2. cnt_test must not pause after starting.
3. cnt_test stops only after the final sorted output data is written into verify_RAM.
4. cnt_test must be connected to ILA.
5. cnt_test final count must be reported.

## Data Format

Input data: signed [15:0]

Output data: signed [15:0]

All comparisons and sorting operations must use signed 16-bit semantics.

The design sorts exactly 64 input elements.

## Address Width Rules

Use these widths exactly:

* mcu_data_addr[6:0]
* internal_mem_addr[5:0]
* rom_addr[5:0]
* verify_ram_addr[5:0]
* PC[7:0]
* test_vector_in[15:0]
* verify_vector_out[15:0]
* cnt_test[19:0]

Memory-mapped I/O requires 7-bit addressing because I/O registers are located at 0x40–0x46.

## Memory Map

Use this memory map:

0x00–0x3F: Internal data RAM, 64 x signed 16-bit
0x40: IO_ROM_ADDR   write, rom_addr[5:0] <= wdata[5:0]
0x41: IO_ROM_DATA   read, returns test_vector_in
0x42: IO_RAM_ADDR   write, verify_ram_addr[5:0] <= wdata[5:0]
0x43: IO_RAM_DATA   write, verify_vector_out <= wdata, verify_RAM we pulse
0x44: IO_CONTROL    write, bit0=cnt_start, bit1=cnt_stop, bit2=done
0x45: IO_SORT_CTL   debug only, not official speed path
0x46: IO_MERGE_CTL  debug only, not official speed path

Official speed path must use SORT8 and BMERGE opcodes, not IO_SORT_CTL / IO_MERGE_CTL.

## Instruction Set

Instruction width: 16-bit fixed width.

Opcode map:

0000 ADD
0001 SUB
0010 AND
0011 OR
0100 MOVL
0101 MOVH
0110 LDR
0111 STR
1000 CMP
1001 B/BL
1010 HALT
1011 Bcc
1100 ADDI
1101 SUBI
1110 reserved in efficiency / SORT8 in speed
1111 reserved in efficiency / BMERGE in speed

B/BL format:

[15:12] = 1001
[11]    = L flag, 0=B, 1=BL
[10:0]  = signed offset

ADDI/SUBI format:

[15:12] opcode
[11:8]  rd
[7:4]   rs1
[3:0]   imm4 unsigned, 0–15

BMERGE encoding must be consistent across assemble.py, control_unit, and sort_accel:

N_code = 4'd1 -> N=16
N_code = 4'd2 -> N=32
N_code = 4'd3 -> N=64
other values -> NOP

## Efficiency Version

The efficiency version must use:

* top_level_efficiency.v
* HAS_ACCEL=0
* sort_efficiency.asm
* sort_efficiency.mem
* insertion sort
* no sort_accel
* no SORT8/BMERGE use

The insertion sort assembly must guarantee that negative index j=-1 is checked before any memory access. RTL data_memory does not need to handle negative addresses; assembly must guarantee legal access.

## Speed Version

The speed version must use:

* top_level_speed.v
* HAS_ACCEL=1
* sort_speed.asm
* sort_speed.mem
* SORT8 + BMERGE acceleration
* sort_accel.v
* cmp_swap.v

SORT8 and BMERGE must be triggered only by MCU fetch/decode/execute of dedicated opcodes in the official path.

Do not bypass the MCU with hidden standalone sorting logic.

## SORT8 Network

SORT8 uses a verified 8-input Batcher odd-even merge sorting network:

Stage 0: (0,1)(2,3)(4,5)(6,7)
Stage 1: (0,2)(1,3)(4,6)(5,7)
Stage 2: (1,2)(5,6)
Stage 3: (0,4)(1,5)(2,6)(3,7)
Stage 4: (2,4)(3,5)
Stage 5: (1,2)(3,4)(5,6)

Total: 6 stages, 19 compare-swap units.

Before integrating SORT8 into the MCU, tb_sort8.v must pass all required tests.

## SORT8 Blocking Test Requirement

tb_sort8.v must pass at least these categories:

1. already sorted
2. reverse sorted
3. duplicates
4. positive/negative mixed
5. signed 16-bit extremes: 0x7FFF, 0x8000, 0
6. random signed 16-bit tests

Minimum: 35 total tests, all PASS.

SORT8 integration into mcu_core is blocked until tb_sort8.v passes.

## BMERGE Requirement

BMERGE must support:

BMERGE Rbase, #16
BMERGE Rbase, #32
BMERGE Rbase, #64

It must use N_code:

1 = 16
2 = 32
3 = 64

BMERGE must be independently tested before full speed MCU integration.

## ILA Requirement

ILA depth: 16384.

Efficiency version probes: 18 routes minimum.

Speed version probes: 25 routes minimum.

Required probes:

test_vector_in
verify_vector_out
verify_ram_we
verify_ram_addr
verify_ram_wdata
cnt_test
cnt_counting
PC
instruction
mcu_state
rom_addr
rom_rd_en
internal_mem_we
internal_mem_addr
internal_mem_wdata
cnt_start
cnt_stop
done

Additional speed probes:

sort_state
sort_stage
sort_base
sort_size
compare_index
accel_busy
accel_done

ILA trigger strategy:

1. speed: cnt_start rising edge, expected to capture full execution
2. efficiency: done rising edge with pre-trigger, or segmented capture
3. if full instruction trace is required, prioritize speed version

## Vivado Requirements

Vivado flow must include:

1. create project
2. generate test_ROM IP
3. generate verify_RAM IP
4. generate ILA IP
5. add RTL
6. synth_design
7. impl_design
8. report_timing_summary
9. report_utilization
10. write_bitstream

Two bitstreams are required:

mcu_efficiency.bit
mcu_speed.bit

WNS must be >= 0.

Target initial clock: 50 MHz.

Resource cost:

cost = 6 * LUT + 10 * FF

Reports must include:

1. LUT
2. FF
3. cost
4. WNS
5. cnt_test estimate or measured value
6. final comparison between efficiency and speed

## Directory Structure

Use this structure:

mcu_sort_project/
├── CLAUDE.md
├── README.md
├── rtl/
│   ├── common/
│   │   ├── alu.v
│   │   ├── register_file.v
│   │   ├── instruction_memory.v
│   │   ├── data_memory.v
│   │   ├── program_counter.v
│   │   ├── control_unit.v
│   │   └── mcu_core.v
│   ├── sort_accel.v
│   ├── cmp_swap.v
│   ├── cnt_test.v
│   ├── top_level_efficiency.v
│   └── top_level_speed.v
├── asm/
│   ├── sort_efficiency.asm
│   ├── sort_efficiency.mem
│   ├── sort_speed.asm
│   ├── sort_speed.mem
│   └── assemble.py
├── coe/
│   └── test_vector.coe
├── sim/
│   ├── tb_sort8.v
│   ├── tb_efficiency.v
│   └── tb_speed.v
├── scripts/
│   ├── gen_sort8_network.py
│   └── parse_reports.py
├── constraints/
│   └── timing.xdc
├── tcl/
│   ├── 01_create_project.tcl
│   ├── 02_gen_ip.tcl
│   ├── 03_add_rtl_efficiency.tcl
│   ├── 03_add_rtl_speed.tcl
│   ├── 04_synth.tcl
│   ├── 05_impl.tcl
│   ├── 06_bitstream.tcl
│   ├── 07_reports.tcl
│   ├── build_efficiency.tcl
│   ├── build_speed.tcl
│   └── run_all.tcl
├── reports/
├── bitstream/
└── vivado_*/

## Implementation Order

Implement in this order only:

1. create directory structure and this CLAUDE.md
2. alu.v + ALU testbench
3. register_file.v + testbench
4. data_memory.v + address decoder testbench
5. program_counter.v + testbench
6. instruction_memory.v + testbench
7. control_unit.v opcode decode testbench
8. cnt_test.v + counter testbench
9. cmp_swap.v
10. tb_sort8.v and SORT8 35-test blocking gate
11. BMERGE independent tests
12. mcu_core HAS_ACCEL=0
13. mcu_core HAS_ACCEL=1
14. assemble.py
15. efficiency assembly and full development simulation
16. speed assembly and full development simulation
17. Vivado IP generation
18. synthesis for both versions
19. implementation for both versions
20. bitstream generation for both versions
21. report parsing and comparison
22. board-level validation with ILA

Do not skip steps.

## Per-Step Reporting

After each step, report:

1. files created or modified
2. commands executed
3. simulation/check result
4. warnings/errors
5. next step

Pause after each major step for user approval.

## Safety Rules

1. Work only inside mcu_sort_project.
2. Do not modify files outside the project.
3. Do not delete user files.
4. Do not modify Windows system environment variables.
5. Do not install software unless explicitly approved.
6. Do not claim final success without bitstream, WNS >= 0, ILA probes, and reports.
7. Do not treat simulation as final acceptance.
8. Do not bypass MCU instruction execution.

After writing CLAUDE.md, reread the file and confirm that these keywords exist:

mcu_data_addr[6:0]
SORT8
BMERGE
N_code = 4'd1 -> N=16
cnt_test
test_ROM
test_vector_in
verify_RAM
verify_vector_out
ILA depth: 16384
WNS >= 0
