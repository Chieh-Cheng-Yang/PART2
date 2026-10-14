# Lab 2 Part 1: 5-stage pipelined MIPS (SystemVerilog)

## Files

| File | Contents |
|---|---|
| `top.sv` | `top` (interface unchanged), `mips`, `imem`, `dmem` |
| `controller.sv` | `controller`, `maindec`, `aludec` (decodes the Decode-stage instruction) |
| `datapath.sv` | pipelined datapath + hazard logic, `regfile`, `alu`, `mux2`, `mux3`, `signext`, `flopenr` |
| `testbench.sv` | self-checking testbench (expected memory writes + performance counters) |
| `memfile.dat` | default program = `tests/memfile_all.dat` (tests every instruction) |
| `tests/prog_*.asm` | assembly sources |
| `tests/prog_*.txt` | assembly listings: address, machine code, instruction |
| `tests/memfile_*.dat` | machine code loaded into imem |
| `tools/mips_tool.py` | assembler + instruction-level reference model that produced the expected values (optional) |
| `original/*.v` | the provided single-cycle design, used only by `make single` for comparison |
| `Makefile` | simulation targets (below) |
| `synth/` | synthesis scripts, `top_with_sram.sv`, Makefile (see Synthesis) |

Hierarchy: `MIPS_Testbench > top > { mips > { controller, datapath }, imem, dmem }`

## Test programs

| Test | Purpose | What makes it fail if the design is wrong |
|---|---|---|
| `all` | add, sub, and, or, slt (incl. signed), lw, sw (incl. base register), beq taken / not taken, addi, j | every result is stored and checked; wrong-path stores after the taken beq / j would be extra writes |
| `fwd` | ADD data hazards: operand from MEM, from WB, both at once, `$0` destination, two writes to the same register (newest wins), load-use ADD | forwarding a stale or wrong value changes a stored sum |
| `br` | BEQ control hazards: loop (beq not taken 5x then taken, j taken 5x), taken beq with wrong-path stores, not-taken beq, beq needing comparator forwarding, beq after an ALU op and after a lw | any wrong-path instruction that is not flushed either corrupts the loop sum or writes memory |
| `orig` | the program provided with the lab | regression |

The testbench checks, for every test:
1. every memory write (address and data, in order), including back-to-back stores;
2. that no unexpected write happens (an unflushed wrong-path store);
3. that the number of instructions executed equals the reference model's dynamic count (no instruction lost or executed twice);
4. a timeout (the pipeline must not hang).

It prints `TEST PASSED` / `TEST FAILED`, followed by `TEST COMPLETE`.

## How to run

Default simulator is VCS. Add `SIM=iverilog` to use Icarus Verilog instead.

```sh
make test TEST=all        # one program on the pipelined design (all | fwd | br | orig)
make regress              # all four programs, pass/fail summary (logs in log_<test>.txt)
make ipc                  # IPC comparisons used in the report
make single TEST=all      # same program on the ORIGINAL single-cycle design
make wave TEST=fwd        # also dump waveform.vcd   (DEFS="+define+FSDB" for Verdi .fsdb)
make clean
```

Without make (VCS), e.g. the forwarding test:
```sh
cp tests/memfile_fwd.dat memfile.dat
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all +define+TEST_FWD \
    testbench.sv top.sv controller.sv datapath.sv -o simv
./simv
```
(no define = `all`; `+define+TEST_BR`, `+define+TEST_ORIG` for the others)

### Experiment-only defines (for the IPC comparison; never used for the real design)

| Define | Effect |
|---|---|
| `NO_FORWARDING` | ADD does not use forwarding; it stalls like every other instruction |
| `BRANCH_STALL` | no flushing logic: fetch is stalled behind every beq until it resolves (costs a cycle even when not taken) |

## Expected results (Icarus Verilog and Verilator give identical numbers)

`make regress`: all four tests `TEST PASSED`.

| Program | Instr. | Single-cycle cycles (CPI) | Pipelined cycles | Pipelined CPI / IPC |
|---|---|---|---|---|
| all  | 33 | 33 (1.00) | 44 | 1.333 / 0.750 |
| fwd  | 29 | 29 (1.00) | 37 | 1.276 / 0.784 |
| br   | 36 | 36 (1.00) | 53 | 1.472 / 0.679 |
| orig | 16 | 16 (1.00) | 34 | 2.125 / 0.471 |

Cycles are counted from the first fetch to the last instruction's writeback, so the pipelined numbers include the 4-cycle pipeline fill (ideal = instructions + 4).

| Comparison (`make ipc`) | Cycles | IPC |
|---|---|---|
| fwd, with ADD forwarding | 37 | 0.784 |
| fwd, `NO_FORWARDING` | 56 | 0.518 |
| br, with flushing | 53 | 0.679 |
| br, `BRANCH_STALL` | 59 | 0.610 |

## Waveforms for the report

Run `make wave TEST=<test>` and open `waveform.vcd` (or use `+define+FSDB` with Verdi). Suggested signals, all under `MIPS_Testbench.dut.mips.dp` unless noted:

- **lw pipeline flow** (`TEST=all`, `lw $12, 4($0)` at pc 0x54):
  `clk, pc, instrD, rsD, signimmD, aluoutE, aluoutM` (= dmem address), `readdata` (dmem RD), `readdataW, memtoregW, resultW, writeregW, regwriteW`
- **ADD forwarding** (`TEST=fwd`, pc 0x08 to 0x14, then the load-use ADD after `lw $13`):
  `clk, pc, instrD, rsE, rtE, writeregM, writeregW, forwardaE, forwardbE, rd1E, aluoutM, resultW, srcaE, srcbE, aluoutE`, and for the load-use case `lwstallD, stallF, stallD, flushE`
- **BEQ flushing** (`TEST=br`, the taken `beq $3,$3,t1` at pc 0x24 and the loop exit at pc 0x0c):
  `clk, pc, dut.instr, instrD, branchD, equalD, pcsrcD, pcbranchD, flushD, stallD`, plus `forwardaD, branchstallD` for the beq at 0x34 / 0x40

Note: during a branch stall, `equalD`/`pcsrcD` may show X in simulation because the comparator reads a register that the stalled producer has not written yet (registers are not initialised). This is harmless: while `stallD`/`stallF` are 1 the PC and F/D register ignore these signals.

## Design notes

- Branches (and `j`) resolve in Decode (Fig. 7.56). A taken branch flushes the one wrong-path instruction in F/D.
- Fig. 7.57: `ALUOutM` is forwarded to the branch comparator. The branch stalls when its operand is still in Execute, or is a `lw` in Memory.
- ADD forwarding (Fig. 7.50): MEM has priority over WB; `$0` is never forwarded; only an ADD in Execute uses the forwarding muxes (handout requirement).
- Load-use (Fig. 7.53): 1-cycle stall, then forwarding from WB.
- Every other data hazard: stall in Decode until the producer reaches Writeback.
- The register file writes on the falling clock edge, so a value written in Writeback is read in Decode in the same cycle.

## Synthesis (Design Compiler)

Use the same environment setup as Lab 1 (so that `dc_shell` and `$PDK_DIR` are available), then:

```sh
cd synth
make orig     # original single-cycle design   -> run_orig/
make pipe     # pipelined design                -> run_pipe/
make sram     # pipelined design + SRAM macros  -> run_sram/
```

Each run directory holds `dc.log`, `timing.rep` (critical path), `area.rep`, `area_hier.rep` (area per block), `qor.rep` (summary), `power.rep`, `cell.rep`.

| File | Contents |
|---|---|
| `synth/compile_orig.tcl`, `compile_pipe.tcl` | provided script, SRAM lines removed, design files set |
| `synth/compile_with_sram.tcl` | provided script with the pipelined design + `top_with_sram.sv` |
| `synth/top_with_sram.sv` | `top.sv` with imem/dmem mapped to `SRAM_32x64_1rw` (synthesis only) |

All three use the same clock target (1000 MHz), `analyze -format sverilog`, and `set_dont_touch` on `imem`/`dmem`. Every line changed from the provided script is tagged `[MOD]`.

Max frequency from `timing.rep`: critical path delay = clock period − slack (slack is negative when the target is not met), f_max = 1 / delay.
