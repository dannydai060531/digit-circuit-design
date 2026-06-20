# MCU 排序工程 — 架构图与流程图

## 1. 顶层系统架构

```mermaid
graph TB
    subgraph FPGA["xc7k160tffg676-2"]
        subgraph IP_Cores["Vivado IP Cores"]
            ROM["test_ROM<br/>64×16 ROM<br/>(BRAM IP)"]
            RAM["verify_RAM<br/>64×16 RAM<br/>(BRAM IP)"]
            ILA["ila_mcu<br/>ILA Core<br/>Depth=16384"]
        end

        subgraph MCU_System["MCU System"]
            CORE["mcu_core<br/>(HAS_ACCEL=0/1)"]
            CNT["cnt_test<br/>20-bit Counter"]
        end
    end

    ROM -->|"test_vector_in[15:0]"| CORE
    CORE -->|"rom_addr[5:0]"| ROM
    CORE -->|"rom_rd_en"| ROM
    CORE -->|"verify_vector_out[15:0]"| RAM
    CORE -->|"verify_ram_addr[5:0]"| RAM
    CORE -->|"ram_we"| RAM
    CORE -->|"cnt_start"| CNT
    CORE -->|"cnt_stop"| CNT
    CNT -->|"cnt_test[19:0]"| ILA
    ROM -->|"test_vector_in"| ILA
    RAM -->|"verify_vector_out"| ILA
    CORE -->|"PC, IR, state"| ILA

    style ROM fill:#4A90D9,color:#fff
    style RAM fill:#4A90D9,color:#fff
    style ILA fill:#E67E22,color:#fff
    style CORE fill:#27AE60,color:#fff
    style CNT fill:#8E44AD,color:#fff
```

## 2. MCU Core 内部架构

```mermaid
graph TB
    subgraph MCU_Core["mcu_core 内部架构"]
        PC["Program Counter<br/>PC[7:0]"]
        IMEM["Instruction Memory<br/>256×16 ROM"]
        IR["Instruction Register<br/>IR[15:0]"]
        CU["Control Unit<br/>Decoder + FSM<br/>5-stage pipeline"]
        RF["Register File<br/>16×16-bit<br/>R0=0 hardwired"]
        ALU["ALU<br/>ADD/SUB/AND/OR<br/>NZCV flags"]
        DM["Data Memory + I/O Bridge<br/>64×16 RAM<br/>Memory-Mapped I/O"]
        WB_MUX["Writeback MUX<br/>ALU/MEM/MOVL/MOVH"]
        ACCEL["Sort Accelerator<br/>SORT8 + BMERGE<br/>(HAS_ACCEL=1 only)"]
    end

    PC -->|"pc[7:0]"| IMEM
    IMEM -->|"instruction[15:0]"| IR
    IR -->|"ir[15:0]"| CU
    CU -->|"control signals"| RF
    CU -->|"alu_op[2:0]"| ALU
    CU -->|"mem/reg control"| DM
    CU -->|"accel_start"| ACCEL
    RF -->|"rdata1, rdata2"| ALU
    ALU -->|"result[15:0]"| WB_MUX
    DM -->|"mem_rdata"| WB_MUX
    WB_MUX -->|"write_data"| RF
    CU -->|"pc_load/pc_hold"| PC
    ALU -->|"NZCV"| CU
    ACCEL -->|"busy/done"| CU
    ACCEL <-->|"addr/data"| DM

    style CU fill:#E74C3C,color:#fff
    style ALU fill:#3498DB,color:#fff
    style RF fill:#2ECC71,color:#fff
    style ACCEL fill:#F39C12,color:#fff
```

## 3. 指令流水线状态机

```mermaid
stateDiagram-v2
    [*] --> FETCH
    FETCH --> DECODE : pc_hold=1
    DECODE --> EXECUTE : normal
    DECODE --> DECODE : HALT opcode

    EXECUTE --> MEMORY : normal
    EXECUTE --> ACCEL_LOAD : SORT8/BMERGE
    EXECUTE --> FETCH : CMP (no WB)

    MEMORY --> WRITEBACK : normal
    MEMORY --> FETCH : B/BL/Bcc (branch)

    WRITEBACK --> FETCH : pc_hold=0

    ACCEL_LOAD --> ACCEL_STAGE
    ACCEL_STAGE --> ACCEL_STAGE : !accel_done
    ACCEL_STAGE --> ACCEL_WB : accel_done
    ACCEL_WB --> FETCH
```

## 4. 完整数据流

```mermaid
sequenceDiagram
    participant ROM as test_ROM
    participant MCU as MCU Core
    participant INT as Internal RAM
    participant ACC as Sort Accel
    participant RAM as verify_RAM
    participant CNT as cnt_test

    Note over MCU: Phase 1: Load
    MCU->>ROM: Set ROM_ADDR (0x40)
    ROM-->>MCU: test_vector_in
    MCU->>INT: Write internal_RAM[i]
    MCU->>CNT: cnt_start (first write)

    Note over MCU: Phase 2: Sort
    alt Efficiency Version
        loop Insertion Sort
            MCU->>INT: LDR A[j], A[j+1]
            MCU->>MCU: CMP, Bcc
            MCU->>INT: STR swap
        end
    else Speed Version
        loop SORT8 × 8
            MCU->>ACC: SORT8 opcode
            ACC->>INT: Read 8 elements
            ACC->>ACC: Batcher network
            ACC->>INT: Write sorted 8
        end
        loop BMERGE × 7
            MCU->>ACC: BMERGE opcode
            ACC->>INT: Merge sorted halves
        end
    end

    Note over MCU: Phase 3: Output
    MCU->>INT: LDR sorted[i]
    MCU->>RAM: Write verify_RAM[i]
    MCU->>CNT: cnt_stop (last write)
    MCU->>MCU: done = 1
```

## 5. SORT8 Batcher Odd-Even 排序网络

```mermaid
graph LR
    subgraph Input["8 × signed 16-bit"]
        D0["D[0]"]; D1["D[1]"]; D2["D[2]"]; D3["D[3]"]
        D4["D[4]"]; D5["D[5]"]; D6["D[6]"]; D7["D[7]"]
    end

    subgraph S0["Stage 0: dist=1"]
        CS0_0["cmp(0,1)"]; CS0_1["cmp(2,3)"]
        CS0_2["cmp(4,5)"]; CS0_3["cmp(6,7)"]
    end

    subgraph S1["Stage 1: dist=2"]
        CS1_0["cmp(0,2)"]; CS1_1["cmp(1,3)"]
        CS1_2["cmp(4,6)"]; CS1_3["cmp(5,7)"]
    end

    subgraph S2["Stage 2"]
        CS2_0["cmp(1,2)"]; CS2_1["cmp(5,6)"]
    end

    subgraph S3["Stage 3: dist=4"]
        CS3_0["cmp(0,4)"]; CS3_1["cmp(1,5)"]
        CS3_2["cmp(2,6)"]; CS3_3["cmp(3,7)"]
    end

    subgraph S4["Stage 4"]
        CS4_0["cmp(2,4)"]; CS4_1["cmp(3,5)"]
    end

    subgraph S5["Stage 5: dist=1"]
        CS5_0["cmp(1,2)"]; CS5_1["cmp(3,4)"]; CS5_2["cmp(5,6)"]
    end

    subgraph Output["Sorted ascending"]
        O0["O[0]"]; O1["O[1]"]; O2["O[2]"]; O3["O[3]"]
        O4["O[4]"]; O5["O[5]"]; O6["O[6]"]; O7["O[7]"]
    end

    D0-->CS0_0; D1-->CS0_0; D2-->CS0_1; D3-->CS0_1
    D4-->CS0_2; D5-->CS0_2; D6-->CS0_3; D7-->CS0_3

    CS0_0-->CS1_0; CS0_1-->CS1_0; CS0_1-->CS1_1; CS0_0-->CS1_1
    CS0_2-->CS1_2; CS0_3-->CS1_2; CS0_3-->CS1_3; CS0_2-->CS1_3

    CS1_0-->CS2_0; CS1_1-->CS2_0; CS1_2-->CS2_1; CS1_3-->CS2_1

    CS2_0-->CS3_0; CS2_0-->CS3_1; CS2_1-->CS3_2; CS2_1-->CS3_3

    CS3_0-->CS4_0; CS3_1-->CS4_1

    CS4_0-->CS5_0; CS4_1-->CS5_1; CS4_0-->CS5_2

    CS5_0-->O1; CS5_0-->O2; CS5_1-->O3; CS5_1-->O4; CS5_2-->O5; CS5_2-->O6

    style S0 fill:#3498DB,color:#fff
    style S1 fill:#2980B9,color:#fff
    style S2 fill:#1ABC9C,color:#fff
    style S3 fill:#27AE60,color:#fff
    style S4 fill:#F39C12,color:#fff
    style S5 fill:#E74C3C,color:#fff
```

## 6. BMERGE 合并流程 (N=64)

```mermaid
graph TB
    subgraph "64 elements"
        A["8 sorted groups of 8<br/>(after SORT8×8)"]
    end

    A --> B["BMERGE N=16 ×4<br/>4 sorted groups of 16"]
    B --> C["BMERGE N=32 ×2<br/>2 sorted groups of 32"]
    C --> D["BMERGE N=64 ×1<br/>1 fully sorted 64"]

    subgraph "BMERGE Internal"
        E["Load N elements<br/>(2nd half reversed)"]
        F["Stage 0: d=N/2<br/>N/2 parallel cmp-swap"]
        G["Stage 1: d=N/4"]
        H["..."]
        I["Final: d=1"]
        J["Write back sorted"]
    end

    E --> F --> G --> H --> I --> J

    style A fill:#3498DB,color:#fff
    style D fill:#27AE60,color:#fff
    style E fill:#F39C12,color:#fff
```

## 7. Memory-Mapped I/O 地址空间

```mermaid
graph LR
    subgraph "Memory Map (7-bit address)"
        RAM0["0x00-0x3F<br/>Internal RAM<br/>64×16 signed"]
        IO40["0x40<br/>IO_ROM_ADDR (W)"]
        IO41["0x41<br/>IO_ROM_DATA (R)"]
        IO42["0x42<br/>IO_RAM_ADDR (W)"]
        IO43["0x43<br/>IO_RAM_DATA (W)"]
        IO44["0x44<br/>IO_CONTROL (W)"]
        IO45["0x45<br/>IO_SORT_CTL<br/>(debug only)"]
        IO46["0x46<br/>IO_MERGE_CTL<br/>(debug only)"]
    end

    style RAM0 fill:#27AE60,color:#fff
    style IO40 fill:#3498DB,color:#fff
    style IO41 fill:#3498DB,color:#fff
    style IO42 fill:#3498DB,color:#fff
    style IO43 fill:#E74C3C,color:#fff
    style IO44 fill:#8E44AD,color:#fff
    style IO45 fill:#95A5A6,color:#fff
    style IO46 fill:#95A5A6,color:#fff
```

## 8. Efficiency vs Speed 对比流程

```mermaid
flowchart TB
    START["Start: 64 signed 16-bit<br/>in test_ROM"] --> LOAD["Load data into<br/>internal RAM[0:63]"]

    LOAD --> CHOOSE{"Version?"}

    CHOOSE -->|"Efficiency"| E_SORT["Insertion Sort<br/>~14,000 cycles<br/>Pure MCU instructions"]
    CHOOSE -->|"Speed"| S_SORT["SORT8 × 8<br/>(~64 cycles)"]

    E_SORT --> E_LOOP{"i < 64?"}
    E_LOOP -->|"yes"| E_CMP["key=A[i]; j=i-1"]
    E_CMP --> E_WHILE{"j>=0 && A[j]>key?"}
    E_WHILE -->|"yes"| E_SHIFT["A[j+1]=A[j]; j--"]
    E_SHIFT --> E_WHILE
    E_WHILE -->|"no"| E_INSERT["A[j+1]=key; i++"]
    E_INSERT --> E_LOOP

    S_SORT --> S_MERGE16["BMERGE N=16 ×4<br/>(~24 cycles)"]
    S_MERGE16 --> S_MERGE32["BMERGE N=32 ×2<br/>(~14 cycles)"]
    S_MERGE32 --> S_MERGE64["BMERGE N=64 ×1<br/>(~8 cycles)"]

    E_LOOP -->|"no"| OUTPUT
    S_MERGE64 --> OUTPUT

    OUTPUT["Write sorted data<br/>to verify_RAM[0:63]"] --> DONE["done=1<br/>cnt_test stops"]

    style START fill:#3498DB,color:#fff
    style CHOOSE fill:#F39C12,color:#fff
    style E_SORT fill:#E74C3C,color:#fff
    style S_SORT fill:#27AE60,color:#fff
    style OUTPUT fill:#8E44AD,color:#fff
    style DONE fill:#2ECC71,color:#fff
```

## 9. 地址位宽规范

| Signal | Width | Range |
|--------|-------|-------|
| `mcu_data_addr` | [6:0] | 0-127 |
| `internal_mem_addr` | [5:0] | 0-63 |
| `rom_addr` | [5:0] | 0-63 |
| `verify_ram_addr` | [5:0] | 0-63 |
| `PC` | [7:0] | 0-255 |
| `test_vector_in` | [15:0] | signed 16-bit |
| `verify_vector_out` | [15:0] | signed 16-bit |
| `cnt_test` | [19:0] | 0-1,048,575 |
| `instruction` | [15:0] | 16-bit fixed |

## 10. 指令编码 (16-bit)

| Opcode | Mnemonic | Format | Description |
|--------|----------|--------|-------------|
| 0000 | ADD | RRR | Rd = Rs1 + Rs2 |
| 0001 | SUB | RRR | Rd = Rs1 - Rs2 |
| 0010 | AND | RRR | Rd = Rs1 & Rs2 |
| 0011 | OR | RRR | Rd = Rs1 \| Rs2 |
| 0100 | MOVL | I8 | Rd = {8'h00, imm8} |
| 0101 | MOVH | I8 | Rd = {imm8, Rd[7:0]} |
| 0110 | LDR | RRR | Rd = mem[Rs1+Rs2] |
| 0111 | STR | RRR | mem[Rs1+Rs2] = Rd |
| 1000 | CMP | RRR | Rs1-Rs2 → NZCV |
| 1001 | B/BL | J12 | PC += sext(imm11), L=link |
| 1010 | HALT | — | done=1, stop |
| 1011 | Bcc | B | if(cond) branch |
| 1100 | ADDI | I4 | Rd = Rs1 + imm4(0-15) |
| 1101 | SUBI | I4 | Rd = Rs1 - imm4(0-15) |
| 1110 | SORT8 | RRR | HW sort 8 (speed) |
| 1111 | BMERGE | RRR | HW merge (speed) |
