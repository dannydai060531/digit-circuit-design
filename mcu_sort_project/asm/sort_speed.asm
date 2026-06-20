; Speed version: SORT8 + BMERGE Batcher odd-even merge
; Sorts 64 signed 16-bit values in internal RAM[0:63]
; Phase 1: Load ROM, Phase 2: SORT8x8, Phase 3-5: BMERGE, Phase 6: Write RAM

; Registers:
; R0=i/offset, R1=base(0), R2=n(64), R14=16

; --- Init ---
MOVL R1, #0
MOVL R2, #64
MOVL R14, #16
MOVL R7, #0x40
MOVL R8, #0x41
MOVL R9, #0x42
MOVL R10, #0x43
MOVL R11, #0x44

; --- Phase 1: Load from test_ROM ---
MOVL R0, #0
load_s:
CMP R0, R2
BGE load_done_s
STR R0, R7, R1
LDR R12, R8, R1
STR R12, R1, R0
CMP R0, R1
BNE load_skip_s
MOVL R12, #1
STR R12, R11, R1     ; cnt_start
load_skip_s:
ADDI R0, R0, #1
B load_s
load_done_s:

; --- Phase 2: SORT8 x 8 ---
; Offsets: 0,8,16,24,32,40,48,56
MOVL R0, #0
sort8_loop:
CMP R0, R2
BGE sort8_done
SORT8 R0
ADDI R0, R0, #8
B sort8_loop
sort8_done:

; --- Phase 3: BMERGE N=16 x 4 ---
MOVL R0, #0
merge16_lp:
CMP R0, R2
BGE merge16_dn
BMERGE R0, #16
ADD R0, R0, R14      ; +16 via preloaded R14
B merge16_lp
merge16_dn:

; --- Phase 4: BMERGE N=32 x 2 ---
MOVL R0, #0
BMERGE R0, #32
MOVL R0, #32
BMERGE R0, #32

; --- Phase 5: BMERGE N=64 x 1 ---
MOVL R0, #0
BMERGE R0, #64

; --- Phase 6: Write to verify_RAM ---
MOVL R0, #0
write_s:
CMP R0, R2
BGE write_done_s
STR R0, R9, R1
LDR R12, R1, R0
STR R12, R10, R1
ADDI R0, R0, #1
B write_s
write_done_s:
MOVL R12, #2
STR R12, R11, R1     ; cnt_stop
MOVL R12, #4
STR R12, R11, R1     ; done
HALT
