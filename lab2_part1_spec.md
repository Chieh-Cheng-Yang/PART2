# Lab 2 Part 1 – Pipelined MIPS: Build Spec & Checklist

Goal: turn `original/*.v` (single-cycle) into a 5-stage pipelined SystemVerilog design **that you write yourself**. Work milestone by milestone; each has an acceptance test so you know when to move on.

---
## 0. Facts about the starting design (from original/)

- Hierarchy (must be kept): `testbench > top > {mips > {controller, datapath}, imem, dmem}`
- `top` ports (DO NOT CHANGE): `clk, reset, writedata[31:0], dataadr[31:0], memwrite`
- `mips` ports: `clk, reset, pc, instr, memwrite, aluout, writedata, readdata`
- `imem`: 64 words, indexed `pc[7:2]`, combinational read, loaded from `memfile.dat`
- `dmem`: 64 words, combinational read, synchronous write on `posedge clk` when `we`
- Regfile: combinational read, write on `posedge clk`, $0 reads as 0
- Controller: `maindec` (op -> regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop) + `aludec` (funct/aluop -> 3-bit alucontrol). `pcsrc = branch & zero` is in the controller today.
- ISA required by handout: add, sub, and, or, slt, lw, sw, beq. The original also decodes addi and j, and the test program uses them, so keep them.
- Testbench: checks every `memwrite` against `expected_addr/expected_data[1..N]`, prints PASS/ERROR, `$finish`.

---
## 1. Milestones

### M1 – SystemVerilog conversion (still single-cycle)
- Rename `.v` -> `.sv`; `wire/reg` -> `logic`; `always @(*)` -> `always_comb`; `always @(posedge clk)` -> `always_ff`; use `always_comb` for decoders.
- Optional extras: `typedef enum` for ALU control, `localparam`, packed structs. Not required.
- **Accept:** original testbench still prints both writes OK (7 @ 0x50, 7 @ 0x54) and TEST COMPLETE.

### M2 – Plan the pipeline on paper
Draw the Harris&Harris pipelined datapath and decide:
1. **Where branch resolves** (recommended: Execute, using ALU `zero`). Flush penalty = instructions behind it in F and D (2 bubbles).
2. **Jump handling**: resolve with `beq` (flush) or in Decode. Either is fine; document it.
3. **Regfile write/read same cycle**: pick ONE: (a) write on negedge, (b) internal bypass (`if we3 && wa3==ra`), or (c) stall. (a)/(b) give better IPC.
4. **Stall mechanism**: freeze PC and IF/ID, inject a bubble (all control = 0) into ID/EX.
5. Signal naming: suffix every signal with its stage (`aluoutE`, `writeregM`, ...).

### M3 – Pipeline registers + control, NO hazard handling
Datapath must follow the handout order exactly:
`Fetch -> F/D regs -> Decode+RF -> D/E regs -> Execute+ALU -> E/M regs -> Memory -> M/W regs -> Writeback`

| Register | Carries |
|---|---|
| F/D | `instrD`, `pcplus4D` |
| D/E | `rd1E, rd2E, signimmE, rsE, rtE, rdE` (or `writeregE`), `pcplus4E`, controls: `regwriteE, memtoregE, memwriteE, branchE, alusrcE, regdstE, alucontrolE` |
| E/M | `aluoutM, writedataM, writeregM`, `zeroM` (if branch in M), `regwriteM, memtoregM, memwriteM, branchM` |
| M/W | `aluoutW, readdataW, writeregW`, `regwriteW, memtoregW` |

Rules:
- Controller decodes in the **Decode** stage; controls ride with the instruction through the registers.
- Register-write address travels with the instruction (**not** the current instruction's bits).
- `top`'s `memwrite`, `dataadr`, `writedata` come from the **Memory** stage.
- Move `pcsrc = branch & zero` out of the controller; the datapath computes it in the resolve stage. Controller drops `zero`.
- **Accept:** a hand-written test with 3 NOPs (`00000000`) between dependent instructions runs correctly.

### M4 – Data hazards
- **ADD forwarding (required):** forward from M (`aluoutM`) and W (`resultW`) to the E-stage ALU inputs for R-type `add`. M has priority over W; ignore $0; require `regwrite`.
- **Everything else: stall** until the producer has written back (or until safe by your regfile choice).
- **Load-use**: if an `add` depends on an immediately preceding `lw`, stall 1 cycle (data is not available until W).
- Standard form: `forwardAE/BE` 2-bit mux selects. You may restrict forwarding to instructions where `funct==ADD` (the handout says ADD only) or apply to all R-type, but state which in the report.
- **Accept:** `add` chains back-to-back produce correct results with no NOPs and no stalls; `sub/and/or/slt/lw/sw` with a hazard still give correct results (via stalls).

### M5 – Control hazards
- On taken `beq` (or `j`): flush F/D and D/E (zero their valid/controls), load PC with target.
- Non-taken branch: no penalty.
- **Accept:** instructions in the shadow of a taken branch never write the regfile or dmem.

### M6 – Test programs and testbench
Create (all with expected values in `expected_addr/expected_data`, bump `N`):
1. `memfile.dat` – all 8 instructions (add, sub, and, or, slt, lw, sw, beq). Observable through `sw` only, so make each result get stored.
2. `memfile_fwd.dat` – back-to-back dependent adds, e.g. `add $3,$1,$2; add $4,$3,$1; add $5,$4,$3; sw $5,...`. Run IPC comparison with forwarding on/off.
3. `memfile_br.dat` – taken `beq` followed by instructions that would `sw` garbage if not flushed, plus a not-taken `beq`.
4. Provide `.txt` assembly for each.
5. Also add a cycle counter in the testbench so you can report CPI/IPC: count cycles from reset release to `TEST COMPLETE`, divide by instruction count executed.

### M7 – Synthesis
- Use `analyze -format sverilog` (handout hint).
- Synthesize `original` (as `.v`) and pipelined. Add `set_dont_touch [get_cells imem]` / `dmem`.
- Collect: area, critical path (slack, start/end point), max frequency.
- SRAM variant: top_with_sram.sv + `compile_with_sram.tcl`; locate the lines in the script that specify the memory cell library (`.db` / `link_library`) for the report.

---
## 2. Report/Deliverable checklist (Part 1 = 60 pts)

**PDF**
- [ ] Hand-annotated pipelined microarchitecture diagram, critical path highlighted, signal names per stage for `lw`
- [ ] Description of code changes: pipelining; forwarding; flushing
- [ ] Table: non-pipelined vs pipelined – CPI, IPC, area, clock freq/critical-path
- [ ] IPC improvement with ADD forwarding sequence
- [ ] IPC improvement with BEQ flushing sequence (vs stall-only baseline)
- [ ] Lines in synthesis script that specify the memory cell library
- [ ] Waveforms (annotated, clean signal list): lw flow; add-forwarding; beq-flush; terminal output screenshot

**ZIP**: README (how to run), Makefile (if any), assembly `.txt`s, `memfile*.dat`, testbench, `.sv` files. No `csrc/`, `simv.daidir`, `.fsdb`.

Also: documentation comments in code (points deducted if poor). Filename: `first_last_first_last_lab1.pdf/.zip`.

---
## 3. Common pitfalls
- Using `instr` bits (current fetch) instead of the pipelined write-register in W -> corrupts the regfile.
- Bubble must zero `regwrite`, `memwrite`, `branch`, `jump`; otherwise "ghost" writes appear.
- Don't forward when `rd == 0`, or from a `lw` in M (data isn't ready).
- Forward `writedata` for `sw` too (the store-data register value is `rd2` after forwarding), or stall for it.
- `dmem` write enable must come from M stage and the testbench's `@(posedge memwrite)` check needs a clean pulse; a bubble in M must have `memwrite = 0`.
- Reset: clear valid bits/controls so garbage at power-up cannot write.
- `maindec` default outputs `x`; in a pipeline X controls propagate. Use `default` = all 0 (NOP).
