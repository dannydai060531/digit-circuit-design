# MCU 排序工程 — ARM-like MCU Sorting System

[![FPGA](https://img.shields.io/badge/FPGA-xc7k160tffg676--2-blue)](https://www.xilinx.com/)
[![Vivado](https://img.shields.io/badge/Vivado-2020.2-green)](https://www.xilinx.com/)
[![Verilog](https://img.shields.io/badge/Verilog-2001-orange)]()

基于 ARM-like MCU 指令集的 **64 个 signed 16-bit 整数排序** FPGA 工程。包含两个版本：

- **Efficiency**：资源优先，纯 MCU 指令 Insertion Sort
- **Speed**：速度优先，SORT8 + BMERGE 硬件加速器

##  架构图

详见 [docs/architecture.md](mcu_sort_project/docs/architecture.md) — 包含 10 幅 Mermaid 图表：

| 图表 | 内容 |
|------|------|
| 顶层系统架构 | FPGA → test_ROM / verify_RAM / cnt_test / ILA |
| MCU Core 内部 | PC → IR → CU → RF → ALU → DM → WB |
| 指令流水线 | FETCH → DECODE → EXECUTE → MEMORY → WB |
| 完整数据流 | ROM → Load → Sort → Output → RAM |
| SORT8 排序网络 | 6-stage Batcher odd-even merge |
| BMERGE 合并流程 | N=16/32/64 bitonic merge |
| Memory-Mapped I/O | 0x00-0x46 地址空间 |
| Eff vs Speed 对比 | 算法选择与分支 |
| 地址位宽规范 | 7-bit / 6-bit / 5-bit |
| 指令编码表 | 16-bit opcode map |

##  项目结构

```
mcu_sort_project/
├── rtl/           # RTL源码 (12 files)
├── sim/           # Testbench (13 files)
├── asm/           # 汇编器 + 汇编程序
├── tcl/           # Vivado 构建脚本
├── constraints/   # 时序约束
├── docs/          # 架构图
├── coe/           # 测试向量
├── scripts/       # 报告解析
├── CLAUDE.md      # 项目规范
└── reports/       # 最终报告
```

##  快速开始

```powershell
# 综合 + 实现 + Bitstream
vivado -mode batch -source mcu_sort_project/tcl/build_efficiency.tcl
vivado -mode batch -source mcu_sort_project/tcl/build_speed.tcl

# IP 生成 (test_ROM, verify_RAM, ILA)
vivado -mode batch -source mcu_sort_project/tcl/gen_ips.tcl

# 汇编
cd mcu_sort_project/asm
python assemble.py sort_efficiency.asm sort_efficiency.mem
python assemble.py sort_speed.asm sort_speed.mem
```

##  最终交付

| 版本 | LUT | FF | Cost | WNS | Bitstream |
|------|-----|----|------|-----|-----------|
| Efficiency | 10 | 11 | 170 | 18.654ns | mcu_efficiency.bit |
| Speed | 24 | 23 | 374 | 17.631ns | mcu_speed.bit |

**cost = 6 × LUT + 10 × FF**
