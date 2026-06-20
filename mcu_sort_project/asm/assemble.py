#!/usr/bin/env python3
"""Assembler for MCU sorting project — .asm to .mem conversion.
Supports all instructions from CLAUDE.md opcode map.
BMERGE N_code: 1=16, 2=32, 3=64.
"""
import sys, re

# Opcode map
OPCODES = {
    'ADD': 0x0, 'SUB': 0x1, 'AND': 0x2, 'OR':  0x3,
    'MOVL':0x4, 'MOVH':0x5, 'LDR': 0x6, 'STR': 0x7,
    'CMP': 0x8, 'B':   0x9, 'BL':  0x9,  # B/BL share opcode, L=link bit
    'HALT':0xA,
    'Bcc': 0xB,  # cond in bits[11:9]
    'ADDI':0xC, 'SUBI':0xD,
    'SORT8':0xE, 'BMERGE':0xF,
}

# Bcc condition codes
COND = {'EQ':0, 'NE':1, 'LT':2, 'GT':3, 'LE':4, 'GE':5}
BCOND = {'BEQ':0, 'BNE':1, 'BLT':2, 'BGT':3, 'BLE':4, 'BGE':5}

REG_RE = re.compile(r'^[rR](\d+)$')

def parse_reg(s):
    m = REG_RE.match(s.strip())
    if not m: raise ValueError(f"Invalid register: {s}")
    r = int(m.group(1))
    if r > 15: raise ValueError(f"Register out of range: {r}")
    return r

def parse_imm(s, bits):
    s = s.strip().lstrip('#')
    v = int(s, 0)
    mask = (1 << bits) - 1
    if v < 0: v = v & mask  # two's complement
    return v & mask

def sext(val, bits):
    """Sign-extend val to 16 bits"""
    mask = (1 << bits) - 1
    if val & (1 << (bits - 1)):
        val = val | (~mask & 0xFFFF)
    return val & 0xFFFF

def assemble_line(line, labels, pc):
    """Assemble one line, return 16-bit machine code or None if label-only."""
    line = line.strip()
    if not line or line.startswith(';') or line.startswith('#'):
        return None
    # Remove comments (; only — # is used for immediate values)
    if ';' in line: line = line[:line.index(';')]
    line = line.strip()
    if not line: return None

    # Label?
    if line.endswith(':'):
        name = line[:-1].strip()
        labels[name] = pc
        return None

    parts = line.replace(',', ' ').split()
    if not parts: return None

    mnemonic = parts[0].upper()

    if mnemonic == 'HALT':
        return 0xA000

    elif mnemonic == 'ADD':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2]); rs2 = parse_reg(parts[3])
        return (0x0 << 12) | (rd << 8) | (rs1 << 4) | rs2

    elif mnemonic == 'SUB':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2]); rs2 = parse_reg(parts[3])
        return (0x1 << 12) | (rd << 8) | (rs1 << 4) | rs2

    elif mnemonic == 'AND':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2]); rs2 = parse_reg(parts[3])
        return (0x2 << 12) | (rd << 8) | (rs1 << 4) | rs2

    elif mnemonic == 'OR':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2]); rs2 = parse_reg(parts[3])
        return (0x3 << 12) | (rd << 8) | (rs1 << 4) | rs2

    elif mnemonic == 'MOVL':
        rd = parse_reg(parts[1])
        imm = parse_imm(parts[2], 8)
        return (0x4 << 12) | (rd << 8) | imm

    elif mnemonic == 'MOVH':
        rd = parse_reg(parts[1])
        imm = parse_imm(parts[2], 8)
        return (0x5 << 12) | (rd << 8) | imm

    elif mnemonic == 'LDR':
        rd = parse_reg(parts[1]); base = parse_reg(parts[2]); idx = parse_reg(parts[3])
        return (0x6 << 12) | (rd << 8) | (base << 4) | idx

    elif mnemonic == 'STR':
        rs = parse_reg(parts[1]); base = parse_reg(parts[2]); idx = parse_reg(parts[3])
        return (0x7 << 12) | (rs << 8) | (base << 4) | idx

    elif mnemonic == 'CMP':
        rs1 = parse_reg(parts[1]); rs2 = parse_reg(parts[2])
        return (0x8 << 12) | (rs1 << 4) | rs2

    elif mnemonic in ('B', 'BL'):
        if parts[1].upper() in labels:
            target_pc = labels[parts[1].upper()]
            offset = target_pc - pc - 1
        else:
            offset = parse_imm(parts[1], 11)
        link = 1 if mnemonic == 'BL' else 0
        return (0x9 << 12) | (link << 11) | (offset & 0x7FF)

    elif mnemonic == 'ADDI':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2])
        imm = parse_imm(parts[3], 4)
        return (0xC << 12) | (rd << 8) | (rs1 << 4) | imm

    elif mnemonic == 'SUBI':
        rd = parse_reg(parts[1]); rs1 = parse_reg(parts[2])
        imm = parse_imm(parts[3], 4)
        return (0xD << 12) | (rd << 8) | (rs1 << 4) | imm

    elif mnemonic == 'SORT8':
        rbase = parse_reg(parts[1])
        return (0xE << 12) | (rbase << 8)

    elif mnemonic == 'BMERGE':
        rbase = parse_reg(parts[1])
        n_str = parts[2].lstrip('#')
        n = int(n_str, 0)
        if n == 16: ncode = 1
        elif n == 32: ncode = 2
        elif n == 64: ncode = 3
        else: raise ValueError(f"BMERGE N must be 16/32/64, got {n}")
        return (0xF << 12) | (rbase << 8) | (ncode << 4)

    elif mnemonic in BCOND:
        cond_code = BCOND[mnemonic]
        if parts[1].upper() in labels:
            target_pc = labels[parts[1].upper()]
            offset = target_pc - pc - 1
        else:
            offset = parse_imm(parts[1], 9)
        return (0xB << 12) | (cond_code << 9) | (offset & 0x1FF)

    elif mnemonic in COND:
        cond_code = COND[mnemonic]
        if parts[1].upper() in labels:
            target_pc = labels[parts[1].upper()]
            offset = target_pc - pc - 1
        else:
            offset = parse_imm(parts[1], 9)
        return (0xB << 12) | (cond_code << 9) | (offset & 0x1FF)

    else:
        raise ValueError(f"Unknown mnemonic: {mnemonic}")

def assemble(infile, outfile):
    labels = {}
    instructions = []

    with open(infile) as f:
        lines = [l.rstrip() for l in f]

    # Pass 1: collect labels
    pc = 0
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith(';') or stripped.startswith('#'): continue
        if ';' in stripped: stripped = stripped[:stripped.index(';')].strip()
        if not stripped: continue
        if stripped.endswith(':'):
            labels[stripped[:-1].strip().upper()] = pc
        else:
            parts = stripped.replace(',', ' ').split()
            if parts and (parts[0].upper() in OPCODES or parts[0].upper() in COND or parts[0].upper() in BCOND):
                pc += 1

    # Pass 2: assemble
    pc = 0
    for line in lines:
        code = assemble_line(line, labels, pc)
        if code is not None:
            instructions.append(code)
            pc += 1
        elif line.strip().endswith(':'):
            pass  # label-only line

    # Write .mem file
    with open(outfile, 'w') as f:
        for instr in instructions:
            f.write(f"{instr:04X}\n")
        # Pad to 256
        for _ in range(len(instructions), 256):
            f.write("0000\n")

    print(f"Assembled {len(instructions)} instructions -> {outfile}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python assemble.py input.asm output.mem")
        sys.exit(1)
    assemble(sys.argv[1], sys.argv[2])
