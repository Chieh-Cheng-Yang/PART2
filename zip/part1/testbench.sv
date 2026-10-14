///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Testbench for the 5-stage pipelined MIPS processor (Lab 2, Part 1)
//
// - Based on the provided template: expected_data / expected_addr arrays hold the expected memory writes, and every
//   memory write is checked against them in order.
// - One testbench, four programs. Select the program with a define (the Makefile also copies the matching
//   memfile_<test>.dat to memfile.dat, which imem loads):
//       (default)        memfile.dat = tests/memfile_all.dat   all instructions: add sub and or slt lw sw beq (+addi, j)
//       +define+TEST_FWD  tests/memfile_fwd.dat                  data hazards on ADD   -> forwarding
//       +define+TEST_BR   tests/memfile_br.dat                   control hazards (BEQ) -> flushing
//       +define+TEST_ORIG tests/memfile_orig.dat                 original program from the lab
// - Expected values are produced by tools/mips_tool.py, an instruction-level reference model independent of the RTL.
//
// Changes vs. the template:
//   * Writes are sampled on every falling clock edge while memwrite = 1 (instead of @(posedge memwrite)), so
//     back-to-back stores, where memwrite stays high for several cycles, are each checked.
//   * Reset is released on a falling clock edge (race-free in every simulator).
//   * Unexpected extra writes (e.g. a wrong-path store that was not flushed) are reported as errors.
//   * A timeout catches a processor that hangs (e.g. stalls forever).
//   * Performance counters: cycles, instructions, CPI, IPC, stall / flush / forwarding events.
//   * +define+SINGLE_CYCLE runs the same programs on the original single-cycle design (no pipeline probes).
//   * +define+DUMP writes waveform.vcd (+define+FSDB writes waveform.fsdb for Verdi).
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module MIPS_Testbench ();
    logic        clk;
    logic        reset;
    logic [31:0] writedata, dataadr;
    logic        memwrite;

    // ------------------------------------------------------------------------
    // Expected memory writes for the selected program
    // ------------------------------------------------------------------------
`ifdef TEST_FWD
    localparam string TEST_NAME = "FWD  (ADD forwarding)";
    localparam int    N         = 11;   // number of expected memory writes
    localparam int    DYN_INSTR = 29;   // dynamic instruction count (reference model)
`elsif TEST_BR
    localparam string TEST_NAME = "BR   (BEQ flushing)";
    localparam int    N         = 3;
    localparam int    DYN_INSTR = 36;
`elsif TEST_ORIG
    localparam string TEST_NAME = "ORIG (original lab program)";
    localparam int    N         = 2;
    localparam int    DYN_INSTR = 16;
`else
    localparam string TEST_NAME = "ALL  (all instructions)";
    localparam int    N         = 15;
    localparam int    DYN_INSTR = 33;
`endif

    logic [31:0] expected_data [1:N];
    logic [31:0] expected_addr [1:N];

    initial begin
`ifdef TEST_FWD
        expected_addr[1]  = 32'h00000028;  expected_data[1]  = 32'h00000003;  // sw $1 (data for the lw tests)
        expected_addr[2]  = 32'h00000000;  expected_data[2]  = 32'h00000007;  // add  $3 = 3+4         = 7
        expected_addr[3]  = 32'h00000004;  expected_data[3]  = 32'h0000000e;  // add  $4 = 7+7         = 14
        expected_addr[4]  = 32'h00000008;  expected_data[4]  = 32'h0000002a;  // add  $5 = (14+7)*2    = 42
        expected_addr[5]  = 32'h0000000c;  expected_data[5]  = 32'h00000038;  // add  $6 = 42+14       = 56
        expected_addr[6]  = 32'h00000010;  expected_data[6]  = 32'h00000038;  // add  $7 = $0+56       = 56 ($0 not forwarded)
        expected_addr[7]  = 32'h00000014;  expected_data[7]  = 32'h00000040;  // add $11 = 8+56        = 64 (newest $10)
        expected_addr[8]  = 32'h00000018;  expected_data[8]  = 32'h00000080;  // add $12 = 64+64       = 128
        expected_addr[9]  = 32'h0000001c;  expected_data[9]  = 32'h00000083;  // add $14 = lw(3)+128   = 131 (load-use)
        expected_addr[10] = 32'h00000020;  expected_data[10] = 32'h00000106;  // add $15 = 131+131     = 262
        expected_addr[11] = 32'h00000024;  expected_data[11] = 32'h00000109;  // add $17 = lw(262)+3   = 265 (load-use)
`elsif TEST_BR
        expected_addr[1]  = 32'h00000000;  expected_data[1]  = 32'h0000000a;  // loop sum 0+1+2+3+4 = 10
        expected_addr[2]  = 32'h00000008;  expected_data[2]  = 32'h00000005;  // after a NOT-taken beq
        expected_addr[3]  = 32'h00000018;  expected_data[3]  = 32'h0000000a;  // end (wrong-path stores to 4,12,16,20 absent)
`elsif TEST_ORIG
        expected_addr[1]  = 32'h00000050;  expected_data[1]  = 32'h00000007;
        expected_addr[2]  = 32'h00000054;  expected_data[2]  = 32'h00000007;
`else
        expected_addr[1]  = 32'h00000000;  expected_data[1]  = 32'h00000011;  // add   12 + 5     = 17
        expected_addr[2]  = 32'h00000004;  expected_data[2]  = 32'h00000007;  // sub   12 - 5     = 7
        expected_addr[3]  = 32'h00000008;  expected_data[3]  = 32'h00000004;  // and   12 & 5     = 4
        expected_addr[4]  = 32'h0000000c;  expected_data[4]  = 32'h0000000d;  // or    12 | 5     = 13
        expected_addr[5]  = 32'h00000010;  expected_data[5]  = 32'h00000001;  // slt   5 < 12     = 1
        expected_addr[6]  = 32'h00000014;  expected_data[6]  = 32'h00000000;  // slt   12 < 5     = 0
        expected_addr[7]  = 32'h00000018;  expected_data[7]  = 32'h00000001;  // slt   -3 < 5     = 1 (signed)
        expected_addr[8]  = 32'h0000001c;  expected_data[8]  = 32'hfffffff1;  // sub   -3 - 12    = -15
        expected_addr[9]  = 32'h00000020;  expected_data[9]  = 32'hfffffffd;  // addi  0 + (-3)   = -3
        expected_addr[10] = 32'h00000024;  expected_data[10] = 32'hfffffff8;  // lw 7, lw -15, add = -8
        expected_addr[11] = 32'h00000034;  expected_data[11] = 32'hfffffff1;  // sw with base reg: 12 + 40 = 52
        expected_addr[12] = 32'h0000002c;  expected_data[12] = 32'hfffffff1;  // lw with base reg reads it back
        expected_addr[13] = 32'h00000030;  expected_data[13] = 32'h00000005;  // after NOT-taken beq
        expected_addr[14] = 32'h0000003c;  expected_data[14] = 32'h00000007;  // after taken beq (56 skipped)
        expected_addr[15] = 32'h00000044;  expected_data[15] = 32'h0000000d;  // after j        (64 skipped)
`endif
    end

    // ------------------------------------------------------------------------
    // Device under test (top-level interface unchanged)
    // ------------------------------------------------------------------------
    top dut (
        .clk      (clk),
        .reset    (reset),
        .writedata(writedata),
        .dataadr  (dataadr),
        .memwrite (memwrite)
    );

    // ------------------------------------------------------------------------
    // Clock generation (period 10)
    // ------------------------------------------------------------------------
    always begin
        clk <= 1'b0; #5;
        clk <= 1'b1; #5;
    end

    // ------------------------------------------------------------------------
    // Reset: held for two rising edges, then released on a FALLING edge.
    // (The template released it exactly on a rising edge, which races with the
    //  flip-flops' async reset: some simulators start the CPU one cycle earlier.)
    // ------------------------------------------------------------------------
    initial begin
        reset = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
    end

    // ------------------------------------------------------------------------
    // Optional waveform dump
    // ------------------------------------------------------------------------
`ifdef DUMP
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, MIPS_Testbench);
    end
`endif
`ifdef FSDB
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars(0, MIPS_Testbench);
    end
`endif

    // ------------------------------------------------------------------------
    // Performance counters + checker, sampled 1 time unit after the falling edge.
    // The register file writes on the falling edge, so Decode-stage signals
    // (equalD, pcsrcD, stalls) settle just after it; sampling exactly at the
    // edge would race with that write.
    // ------------------------------------------------------------------------
    int cycles      = 0;   // clock cycles since reset was released
    int instrs      = 0;   // instructions accepted into Decode (excludes bubbles / flushed instructions)
    int stall_cyc   = 0;   // cycles in which Decode was stalled
    int lw_stall    = 0;   //   ... caused by a load-use hazard           (Fig. 7.53)
    int dep_stall   = 0;   //   ... caused by a non-ADD data dependency   (handout: "just stall")
    int br_stall    = 0;   //   ... caused by a beq operand not ready     (Fig. 7.57)
    int flushes     = 0;   // wrong-path instructions flushed from F/D    (Fig. 7.56)
    int fwd_alu_m   = 0;   // ALU operands forwarded from ALUOutM         (Fig. 7.50)
    int fwd_alu_w   = 0;   // ALU operands forwarded from ResultW         (Fig. 7.50)
    int fwd_cmp     = 0;   // comparator operands forwarded from ALUOutM  (Fig. 7.57)
    int i           = 0;   // index of the next expected memory write
    int errors      = 0;
    int total_cycles = 0;
    int br_taken    = 0;   // beq resolved taken
    int br_ntaken   = 0;   // beq resolved not taken

    always @(negedge clk) begin
        #1;
        if (!reset) begin
            cycles++;
`ifdef SINGLE_CYCLE
            // instruction count = cycle count, computed in report()
`else
            // An instruction leaves Fetch for Decode when F/D is enabled and not cleared.
            // imem is zero-filled past the program, so instr == 0 marks "no more instructions".
            if (!dut.mips.dp.stallD && !dut.mips.dp.flushD && dut.instr != 32'b0) instrs++;
            if (dut.mips.dp.stallD) begin
                stall_cyc++;
                if      (dut.mips.dp.lwstallD)     lw_stall++;
                else if (dut.mips.dp.branchstallD) br_stall++;
                else                               dep_stall++;
            end else begin
                if (dut.mips.dp.flushD)                          flushes++;
                if (dut.mips.dp.branchD &&  dut.mips.dp.pcsrcD)  br_taken++;
                if (dut.mips.dp.branchD && !dut.mips.dp.pcsrcD)  br_ntaken++;
                if (dut.mips.dp.branchD) fwd_cmp += dut.mips.dp.forwardaD + dut.mips.dp.forwardbD;
            end
            fwd_alu_m += (dut.mips.dp.forwardaE == 2'b10) + (dut.mips.dp.forwardbE == 2'b10);
            fwd_alu_w += (dut.mips.dp.forwardaE == 2'b01) + (dut.mips.dp.forwardbE == 2'b01);
`endif
        end

        // --------------------------------------------------------------------
        // Memory-write checker (same block, so it sees this cycle's counters)
        // --------------------------------------------------------------------
        if (!reset && memwrite) begin
            i++;
            if (i > N) begin
                $display("ERROR: unexpected memory write %0d : wrote %h to address %h", i, writedata, dataadr);
                errors++;
            end else if (dataadr == expected_addr[i] && writedata == expected_data[i]) begin
                $display("Memory write %0d successful : wrote %h to address %h", i, writedata, dataadr);
            end else begin
                $display("ERROR: Memory write %0d : wrote %h to address %h ; Expected %h to address %h",
                         i, writedata, dataadr, expected_data[i], expected_addr[i]);
                errors++;
            end
            if (i == N) begin
                // The last store is in Memory now and completes Writeback 1 cycle later.
`ifdef SINGLE_CYCLE
                total_cycles = cycles;
`else
                total_cycles = cycles + 1;
`endif
            end
        end
    end

    // ------------------------------------------------------------------------
    // End of test: report after the last expected write (+ a few cycles to catch stray writes)
    // ------------------------------------------------------------------------
    initial begin
        wait (i >= N);
        repeat (5) @(negedge clk);
        report();
        $finish;
    end

    initial begin                                           // timeout
        #20000;
        $display("ERROR: timeout, only %0d of %0d expected memory writes seen", i, N);
        errors++;
        report();
        $finish;
    end

    task automatic report();
        real cpi, ipc;
        if (i < N) total_cycles = cycles;          // timeout: report what we have
`ifdef SINGLE_CYCLE
        instrs = total_cycles;                     // one instruction per cycle
`endif
        cpi = real'(total_cycles) / instrs;
        ipc = real'(instrs) / total_cycles;
        $display("------------------------------------------------------------");
        $display(" Test             : %s", TEST_NAME);
`ifdef SINGLE_CYCLE
        $display(" Design           : single-cycle (original)");
`else
        $display(" Design           : 5-stage pipeline%s%s",
`ifdef NO_FORWARDING
                 " [NO_FORWARDING baseline]",
`else
                 "",
`endif
`ifdef BRANCH_STALL
                 " [BRANCH_STALL baseline]");
`else
                 "");
`endif
`endif
        $display(" Memory writes    : %0d of %0d checked, %0d error(s)", (i > N) ? N : i, N, errors);
        $display(" Instructions     : %0d (reference model: %0d)%s", instrs, DYN_INSTR,
                 (instrs == DYN_INSTR) ? "" : "  <-- MISMATCH");
        $display(" Cycles           : %0d (first fetch to last writeback)", total_cycles);
        $display(" CPI / IPC        : %0.3f / %0.3f", cpi, ipc);
`ifndef SINGLE_CYCLE
        $display(" Stall cycles     : %0d (load-use %0d, non-ADD dependency %0d, branch operand %0d)",
                 stall_cyc, lw_stall, dep_stall, br_stall);
        $display(" Branches         : %0d taken, %0d not taken; %0d instruction(s) flushed",
                 br_taken, br_ntaken, flushes);
        $display(" Forwarding       : ALU from MEM %0d, ALU from WB %0d, comparator from MEM %0d",
                 fwd_alu_m, fwd_alu_w, fwd_cmp);
`endif
        $display("------------------------------------------------------------");
        if (errors == 0 && i == N && instrs == DYN_INSTR) $display("TEST PASSED");
        else                                              $display("TEST FAILED");
        $display("TEST COMPLETE");
    endtask
endmodule
