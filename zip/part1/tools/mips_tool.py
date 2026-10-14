#!/usr/bin/env python3
"""
mips_tool.py - tiny assembler + reference (single-cycle) simulator for Lab 2.

Usage:
    python3 tools/mips_tool.py tests/prog_all.asm

For prog_X.asm it writes, next to the source:
    memfile_X.dat   machine code, one 32-bit hex word per line ($readmemh)
    prog_X.txt      annotated listing: address, machine code, assembly
and prints the SystemVerilog lines for expected_addr / expected_data,
obtained by running the program on an instruction-level reference model
(independent of the RTL), plus the dynamic instruction count.

Supported: add sub and or slt lw sw beq addi j   (labels: "name:")
"""
import sys, os, re

RFUNCT = {'add': 0x20, 'sub': 0x22, 'and': 0x24, 'or': 0x25, 'slt': 0x2a}
M32 = 0xffffffff

def reg(t):
    t = t.strip()
    assert t.startswith('$'), f"bad register {t}"
    return int(t[1:])

def s32(x):
    x &= M32
    return x - (1 << 32) if x & 0x80000000 else x

def parse(path):
    """returns list of (asm_text, comment) and label table"""
    labels, prog = {}, []
    for raw in open(path):
        code, _, cmt = raw.partition('#')
        code = code.strip()
        while code:
            m = re.match(r'^(\w+):\s*(.*)$', code)
            if m:                                   # label (maybe followed by code)
                labels[m.group(1)] = 4 * len(prog)
                code = m.group(2).strip()
                continue
            prog.append((code, cmt.strip()))
            break
    return prog, labels

def encode(text, pc, labels):
    op, *a = text.replace(',', ' ').split()
    if op in RFUNCT:
        d, s, t = map(reg, a)
        return (s << 21) | (t << 16) | (d << 11) | RFUNCT[op]
    if op == 'addi':
        t, s, imm = reg(a[0]), reg(a[1]), int(a[2], 0)
        return (0x08 << 26) | (s << 21) | (t << 16) | (imm & 0xffff)
    if op in ('lw', 'sw'):
        t = reg(a[0])
        off, base = a[1].rstrip(')').split('(')
        opc = 0x23 if op == 'lw' else 0x2b
        return (opc << 26) | (reg(base) << 21) | (t << 16) | (int(off, 0) & 0xffff)
    if op == 'beq':
        s, t = reg(a[0]), reg(a[1])
        off = (labels[a[2]] - (pc + 4)) // 4
        return (0x04 << 26) | (s << 21) | (t << 16) | (off & 0xffff)
    if op == 'j':
        return (0x02 << 26) | ((labels[a[0]] >> 2) & 0x3ffffff)
    raise ValueError(f"unsupported instruction: {text}")

def simulate(words, max_steps=10000):
    """Instruction-level model. Program ends when PC runs past the last word."""
    R, MEM, stores, pc, n = [0] * 32, {}, [], 0, 0
    while pc // 4 < len(words):
        w = words[pc // 4]; n += 1
        assert n < max_steps, "reference model: too many steps (infinite loop?)"
        op, rs, rt, rd = w >> 26, (w >> 21) & 31, (w >> 16) & 31, (w >> 11) & 31
        imm = s32(w & 0xffff if not (w & 0x8000) else (w & 0xffff) | 0xffff0000)
        npc = pc + 4
        if op == 0:
            f = w & 0x3f
            a, b = R[rs], R[rt]
            v = {0x20: a + b, 0x22: a - b, 0x24: a & b, 0x25: a | b,
                 0x2a: int(s32(a) < s32(b))}[f]
            if rd: R[rd] = v & M32
        elif op == 0x08:
            if rt: R[rt] = (R[rs] + imm) & M32
        elif op == 0x23:
            addr = (R[rs] + imm) & M32
            assert addr in MEM, f"lw from uninitialized dmem address 0x{addr:x} (RTL would read X)"
            if rt: R[rt] = MEM[addr]
        elif op == 0x2b:
            addr = (R[rs] + imm) & M32
            MEM[addr] = R[rt]; stores.append((addr, R[rt]))
        elif op == 0x04:
            if R[rs] == R[rt]: npc = pc + 4 + (imm << 2)
        elif op == 0x02:
            npc = ((pc + 4) & 0xf0000000) | ((w & 0x3ffffff) << 2)
        pc = npc
    return stores, n

def main(path):
    prog, labels = parse(path)
    words = [encode(t, 4 * i, labels) for i, (t, _) in enumerate(prog)]
    d = os.path.dirname(path) or '.'
    name = os.path.splitext(os.path.basename(path))[0].replace('prog_', '')
    with open(os.path.join(d, f'memfile_{name}.dat'), 'w') as f:
        f.writelines(f'{w:08x}\n' for w in words)
    inv = {v: k for k, v in labels.items()}
    with open(os.path.join(d, f'prog_{name}.txt'), 'w') as f:
        f.write(f'# {os.path.basename(path)}: addr  machine-code  assembly\n')
        for i, ((t, c), w) in enumerate(zip(prog, words)):
            if 4 * i in inv: f.write(f'{inv[4*i]}:\n')
            f.write(f'  0x{4*i:02x}  {w:08x}   {t:<24}' + (f'# {c}' if c else '') + '\n')
    stores, n = simulate(words)
    print(f'// {name}: {len(words)} static, {n} dynamic instructions, {len(stores)} stores')
    print(f'localparam int N = {len(stores)};')
    for i, (a, v) in enumerate(stores, 1):
        print(f"expected_addr[{i}] = 32'h{a:08x};  expected_data[{i}] = 32'h{v:08x};  // {s32(v)}")
    print(f'localparam int DYN_INSTR = {n};')

if __name__ == '__main__':
    main(sys.argv[1])
