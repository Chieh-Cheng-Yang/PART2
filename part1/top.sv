////////////////////////////////////////////////////////////////////////////
// ========================================================================
// This file has the following module implementations:
// 1. top
// 2. mips
// 3. dmem
// 4. imem
// =========================================================================
////////////////////////////////////////////////////////////////////////////
// Top Module (interface unchanged)
//  - This module connects the MIPS processor to instruction and data memory
////////////////////////////////////////////////////////////////////////////
module top (
    input  logic        clk, reset,
    output logic [31:0] writedata, dataadr,
    output logic        memwrite
);
    logic [31:0] pc, instr, readdata;

    // instantiate processor and memories
    mips mips (clk, reset, pc, instr, memwrite, dataadr, writedata, readdata);
    imem imem (pc[7:2], instr);
    dmem dmem (clk, memwrite, dataadr, writedata, readdata);
endmodule


//////////////////////////////////////////////////////////////////////
// 5-stage pipelined MIPS Processor Module (ports unchanged)
//////////////////////////////////////////////////////////////////////
module mips (
    input  logic        clk, reset,
    output logic [31:0] pc,
    input  logic [31:0] instr,
    output logic        memwrite,           // driven by the datapath (MemWriteM)
    output logic [31:0] aluout, writedata,
    input  logic [31:0] readdata
);
    logic [31:0] instrD;
    logic memtoregD, memwriteD, branchD, alusrcD, regdstD, regwriteD, jumpD;
    logic [2:0] alucontrolD;

    // Controller decodes the Decode-stage instruction
    controller c (instrD[31:26], instrD[5:0],
                  memtoregD, memwriteD, branchD, alusrcD,
                  regdstD, regwriteD, jumpD, alucontrolD);

    datapath dp (.clk(clk), .reset(reset),
                 .alucontrolD(alucontrolD), .alusrcD(alusrcD), .regdstD(regdstD),
                 .branchD(branchD), .memwriteD(memwriteD),
                 .memtoregD(memtoregD), .regwriteD(regwriteD), .jumpD(jumpD),
                 .instr(instr), .readdata(readdata),
                 .pc(pc), .instrD(instrD),
                 .aluout(aluout), .writedata(writedata), .memwrite(memwrite));
endmodule


//////////////////////////////////////////////////////////////////////
// Data Memory Module: 64 words, combinational read, write on posedge
//////////////////////////////////////////////////////////////////////
module dmem (
    input  logic        clk, we,
    input  logic [31:0] a, wd,
    output logic [31:0] rd
);
    logic [31:0] RAM [63:0];

    assign rd = RAM[a[7:2]];    // word aligned (64 words -> 6 address bits)

    always_ff @(posedge clk)
        if (we) RAM[a[7:2]] <= wd;
endmodule


//////////////////////////////////////////////////////////////////////
// Instruction Memory Module: 64 words, loaded from memfile.dat
// - unused locations are filled with 0 (NOP) so the pipeline never
//   fetches X past the end of the program
//////////////////////////////////////////////////////////////////////
module imem (
    input  logic [5:0]  a,
    output logic [31:0] rd
);
    logic [31:0] RAM [63:0];

    initial begin
        for (int i = 0; i < 64; i++) RAM[i] = 32'b0;
        $readmemh("memfile.dat", RAM);
    end

    assign rd = RAM[a];         // word aligned
endmodule