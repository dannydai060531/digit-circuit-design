; Efficiency version: Insertion Sort
; Sorts 64 signed 16-bit values in internal RAM[0:63]
; Registers: R0=i, R1=base(0), R2=n(64), R3=key, R4=j, R5=A[j], R6=j+1, R7=io_rom_addr
; R8=io_rom_data, R9=io_ram_addr, R10=io_ram_data, R11=io_control, R12=temp, R13=1

; --- Init ---
MOVL R1, #0        ; base = 0
MOVL R2, #64       ; n = 64
MOVL R13, #1       ; const 1
MOVL R7, #0x40     ; IO_ROM_ADDR
MOVL R8, #0x41     ; IO_ROM_DATA
MOVL R9, #0x42     ; IO_RAM_ADDR
MOVL R10, #0x43    ; IO_RAM_DATA
MOVL R11, #0x44    ; IO_CONTROL

; --- Phase 1: Load 64 from test_ROM ---
MOVL R0, #0        ; i = 0
load_loop:
CMP R0, R2
BGE load_done
STR R0, R7, R1     ; IO_ROM_ADDR = i
LDR R12, R8, R1    ; R12 = test_vector_in
STR R12, R1, R0    ; internal_RAM[i] = R12
CMP R0, R1         ; i == 0?
BNE load_skip
STR R13, R11, R1   ; cnt_start
load_skip:
ADDI R0, R0, #1    ; i++
B load_loop
load_done:

; --- Phase 2: Insertion Sort ---
MOVL R0, #1        ; i = 1
outer_loop:
CMP R0, R2
BGE sort_done
LDR R3, R1, R0     ; key = A[i]
SUBI R4, R0, #1    ; j = i - 1
while_loop:
CMP R4, R1         ; j >= 0?
BLT while_done
LDR R5, R1, R4     ; A[j]
CMP R5, R3         ; A[j] > key?
BLE while_done
ADDI R6, R4, #1    ; j + 1
STR R5, R1, R6     ; A[j+1] = A[j]
SUBI R4, R4, #1    ; j--
B while_loop
while_done:
ADDI R6, R4, #1    ; j + 1
STR R3, R1, R6     ; A[j+1] = key
ADDI R0, R0, #1    ; i++
B outer_loop
sort_done:

; --- Phase 3: Write to verify_RAM ---
MOVL R0, #0        ; i = 0
write_loop:
CMP R0, R2
BGE write_done
STR R0, R9, R1     ; IO_RAM_ADDR = i
LDR R12, R1, R0    ; R12 = internal_RAM[i]
STR R12, R10, R1   ; IO_RAM_DATA = R12 -> verify_RAM
ADDI R0, R0, #1
B write_loop
write_done:
MOVL R12, #2       ; bit1 = cnt_stop
STR R12, R11, R1
MOVL R12, #4       ; bit2 = done
STR R12, R11, R1
HALT
