//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. datapath
// 2. regfile
// 3. alu
// 4. mux2
// 5. mux3      (forwarding mux)
// 6. signext
// 7. flopenr   (PC register with stall enable)
// ===================================================================
//////////////////////////////////////////////////////////////////////
// Datapath module
//////////////////////////////////////////////////////////////////////
module datapath (
    input logic clk, reset,

    // Control signals coming from the controller (decoded in Decode stage)
    input logic [2:0] alucontrolD,          // Execute stage control
    input logic alusrcD, regdstD,           // Execute stage control
    input logic branchD, jumpD,             // Decode stage control (early branch / jump)
    input logic memwriteD,                  // Memory stage control
    input logic memtoregD, regwriteD,       // Write Back stage control

    input logic [31:0] instr,      // instruction from imem
    input logic [31:0] readdata,   // RD of dmem, registered into readdataW

    // Result going out
    output logic [31:0] pc,               // PCF: drives imem address
    output logic [31:0] instrD,
    output logic [31:0] aluout, writedata,
    output logic memwrite                 // memwriteM: dmem WE
);
    // Fetch stage
    logic [31:0] pcplus4F;
    logic [31:0] pcnextbr, pcnextF;       // after branch mux / after jump mux (= PC')
    logic stallF;
    // Decode stage
    logic [4:0] rsD, rtD, rdD;
    logic [31:0] pcplus4D, rd1D, rd2D, signimmD;
    logic [31:0] pcbranchD, pcjumpD;
    logic isaddD, lwstallD, depstallD, stallD, equalD, pcsrcD, flushD;
    logic branchstallD, forwardaD, forwardbD;
    logic [31:0] cmpaD, cmpbD;          // comparator inputs after forwarding
    // Execute stage
    logic [31:0] rd1E, rd2E, signimmE;
    logic [4:0] writeregE;
    logic [4:0] rtE, rdE, rsE;
    logic [31:0] srcaE, srcbE, writedataE, aluoutE;   // after forwarding muxes
    logic [1:0]  forwardaE, forwardbE;
    logic zeroE, isaddE, flushE;
    // Memory stage
    logic [31:0] aluoutM, writedataM;
    logic [4:0] writeregM;
    // Write Back stage
    logic [4:0] writeregW;
    logic [31:0] resultW;
    logic [31:0] aluoutW, readdataW;

    // control signals
    logic regwriteE, memtoregE, memwriteE, alusrcE, regdstE;
    logic [2:0] alucontrolE;
    logic regwriteM, memtoregM, memwriteM;
    logic regwriteW, memtoregW;

    // ============================================================
    // 1. Fetch
    // ============================================================
    // imem (pc[7:2], instr) instantiated in top.v, its output "instr" enters datapath as an input port
    mux2 #(32) pcbrmux(pcplus4F, pcbranchD, pcsrcD, pcnextbr);
    mux2 #(32) pcmux(pcnextbr, pcjumpD, jumpD, pcnextF);
    flopenr #(32) pcreg(clk, reset, !stallF, pcnextF, pc);        // d: pcnextbr -> pcnextF

    assign pcplus4F = pc + 32'd4;

    // ============================================================
    // 2. Fetch-to-Decode pipeline registers
    // ============================================================
    always_ff @(posedge clk or posedge reset) begin : fd_reg
        if (reset) begin
            pcplus4D <= 32'b0;
            instrD   <= 32'b0;
        end else if (!stallD) begin          // EN = !StallD
            if (flushD) begin                  // CLR = PCSrcD -> NOP bubble
                pcplus4D <= 32'b0;
                instrD   <= 32'b0;
            end else begin
                pcplus4D <= pcplus4F;
                instrD   <= instr;
            end
        end
    end

    // ============================================================
    // 3. Decode
    // ============================================================
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];

`ifdef NO_FORWARDING
    // EXPERIMENT ONLY (IPC baseline): ADD is treated like every other
    // instruction, so it stalls instead of using forwarding.
    assign isaddD = 1'b0;
`else
    // Consumer is ADD (R-type, funct 100000): only ADD may use forwarding.
    assign isaddD = (instrD[31:26] == 6'b000000) && (instrD[5:0] == 6'b100000);
`endif

    // branch condition
    assign forwardaD = (rsD != 5'd0) && (rsD == writeregM) && regwriteM;
    assign forwardbD = (rtD != 5'd0) && (rtD == writeregM) && regwriteM;
    mux2 #(32) forwardadmux(rd1D, aluoutM, forwardaD, cmpaD);
    mux2 #(32) forwardbdmux(rd2D, aluoutM, forwardbD, cmpbD);

    assign equalD = (cmpaD == cmpbD);
    assign pcsrcD = branchD & equalD;
    assign pcbranchD = pcplus4D + (signimmD << 2);
    assign pcjumpD = {pcplus4D[31:28], instrD[25:0], 2'b00};     // j target (from original datapath.v)
`ifdef BRANCH_STALL
    // EXPERIMENT ONLY (IPC baseline): no flushing logic. Fetch is stalled one
    // cycle behind EVERY branch/jump until it resolves, taken or not.
    assign flushD  = branchD | jumpD;
`else
    // Flushing logic: assume not taken; only a taken beq (or j) clears the
    // wrong-path instruction in the F/D register.
    assign flushD  = pcsrcD | jumpD;
`endif
    // Read ports serve the Decode instruction (A1, A2).
    // Write port serves the Writeback instruction (A3 = WriteRegW, WD3 = ResultW, WE3 = RegWriteW).
    regfile rf (.clk(clk), .we3(regwriteW), .ra1(rsD), .ra2(rtD),
                .wa3(writeregW), .wd3(resultW), .rd1(rd1D), .rd2(rd2D));
    signext se(instrD[15:0], signimmD);

    // --- Data hazard: stall detection ---
    // lw in Execute writes rt, its data isn't ready until W -> stall 1 cycle
    assign lwstallD  = memtoregE && ((rsD == rtE) || (rtD == rtE));
    // Non-ADD consumer can't use forwarding -> stall while producer is in E or M
    // (beq is excluded: it has its own rule below, Fig. 7.57)
    assign depstallD = !isaddD && !branchD && (
        (regwriteE && (writeregE != 5'd0) && ((rsD == writeregE) || (rtD == writeregE))) ||
        (regwriteM && (writeregM != 5'd0) && ((rsD == writeregM) || (rtD == writeregM))));

    // Fig. 7.57 branch stall: beq compares in Decode, so it waits while an
    // ALU result it needs is still in Execute, or a lw it needs is in Memory
    // (ALUOutM holds the address there, not the data).
    assign branchstallD = branchD && (
        (regwriteE && (writeregE != 5'd0) && ((rsD == writeregE) || (rtD == writeregE))) ||
        (memtoregM && (writeregM != 5'd0) && ((rsD == writeregM) || (rtD == writeregM))));


`ifdef BRANCH_STALL
    // EXPERIMENT ONLY: behind a NOT-taken beq the fetched instruction was
    // discarded above, so hold the PC and fetch it again next cycle.
    assign stallF = lwstallD | depstallD | branchstallD | (branchD & ~pcsrcD);
`else
    assign stallF = lwstallD | depstallD | branchstallD;   // freeze PC
`endif
    assign stallD = lwstallD | depstallD | branchstallD;   // freeze F/D register
    assign flushE = lwstallD | depstallD | branchstallD;   // bubble into D/E register

    // ============================================================
    // 4. Decode-to-Execute pipeline registers
    // ============================================================
    always_ff @(posedge clk or posedge reset) begin : de_reg
        if (reset) begin
            rd1E        <= 32'b0;
            rd2E        <= 32'b0;
            rsE         <= 5'b0;      // forwarding compares rsE
            isaddE      <= 1'b0;      // decode provide if it's ADD
            rtE         <= 5'b0;
            rdE         <= 5'b0;
            signimmE    <= 32'b0;
            regwriteE   <= 1'b0;      // Control signal
            memtoregE   <= 1'b0;      // Control signal
            memwriteE   <= 1'b0;      // Control signal
            alusrcE     <= 1'b0;      // Control signal
            regdstE     <= 1'b0;      // Control signal
            alucontrolE <= 3'b010;    // Control signal
        end else if (flushE) begin           // CLR = FlushE -> bubble
            rd1E        <= 32'b0;
            rd2E        <= 32'b0;
            rsE         <= 5'b0;
            isaddE      <= 1'b0;
            rtE         <= 5'b0;
            rdE         <= 5'b0;
            signimmE    <= 32'b0;
            regwriteE   <= 1'b0;
            memtoregE   <= 1'b0;
            memwriteE   <= 1'b0;
            alusrcE     <= 1'b0;
            regdstE     <= 1'b0;
            alucontrolE <= 3'b000;
        end else begin
            rd1E        <= rd1D;
            rd2E        <= rd2D;
            rsE         <= rsD;
            isaddE      <= isaddD;
            rtE         <= rtD;
            rdE         <= rdD;
            signimmE    <= signimmD;
            regwriteE   <= regwriteD;     // Control signal
            memtoregE   <= memtoregD;     // Control signal
            memwriteE   <= memwriteD;     // Control signal
            alusrcE     <= alusrcD;       // Control signal
            regdstE     <= regdstD;       // Control signal
            alucontrolE <= alucontrolD;   // Control signal
        end
    end

    // ============================================================
    // 5. Execute
    // ============================================================
    // 00 = register file value, 01 = ResultW, 10 = ALUOutM
    always_comb begin
        forwardaE = 2'b00;
        forwardbE = 2'b00;
        if (isaddE) begin
            if      ((rsE != 5'd0) && (rsE == writeregM) && regwriteM) forwardaE = 2'b10;
            else if ((rsE != 5'd0) && (rsE == writeregW) && regwriteW) forwardaE = 2'b01;

            if      ((rtE != 5'd0) && (rtE == writeregM) && regwriteM) forwardbE = 2'b10;
            else if ((rtE != 5'd0) && (rtE == writeregW) && regwriteW) forwardbE = 2'b01;
        end
    end

    mux3 #(32) forwardaemux(rd1E, resultW, aluoutM, forwardaE, srcaE);       // SrcAE
    mux3 #(32) forwardbemux(rd2E, resultW, aluoutM, forwardbE, writedataE);  // WriteDataE

    mux2 #(32) srcbmux(writedataE, signimmE, alusrcE, srcbE);   // SrcBE
    mux2 #(5)  wrmux(rtE, rdE, regdstE, writeregE);             // WriteRegE
    alu alu(srcaE, srcbE, alucontrolE, aluoutE, zeroE);

    // ============================================================
    // 6. Execute-to-Memory pipeline registers
    // ============================================================
    always_ff @(posedge clk or posedge reset) begin : em_reg
        if (reset) begin
            aluoutM    <= 32'b0;
            writedataM <= 32'b0;
            writeregM  <= 5'b0;
            regwriteM  <= 1'b0;       // Control signal
            memtoregM  <= 1'b0;       // Control signal
            memwriteM  <= 1'b0;       // Control signal
        end else begin
            aluoutM    <= aluoutE;
            writedataM <= writedataE;
            writeregM  <= writeregE;
            regwriteM  <= regwriteE;  // Control signal
            memtoregM  <= memtoregE;  // Control signal
            memwriteM  <= memwriteE;  // Control signal
        end
    end

    // ============================================================
    // 7. Memory
    // ============================================================
    // dmem is instantiated in top; the datapath drives its ports from M-stage signals.
    assign aluout    = aluoutM;           // dmem A
    assign writedata = writedataM;        // dmem WD
    assign memwrite  = memwriteM;         // dmem WE

    // ============================================================
    // 8. Memory-to-Writeback pipeline registers
    // ============================================================
    always_ff @(posedge clk or posedge reset) begin : mw_reg
        if (reset) begin
            aluoutW   <= 32'b0;
            readdataW <= 32'b0;
            writeregW <= 5'b0;
            regwriteW <= 1'b0;        // Control signal
            memtoregW <= 1'b0;        // Control signal
        end else begin
            aluoutW   <= aluoutM;
            readdataW <= readdata;    // dmem RD -> ReadDataW
            writeregW <= writeregM;
            regwriteW <= regwriteM;   // Control signal
            memtoregW <= memtoregM;   // Control signal
        end
    end

    // ============================================================
    // 9. Write Back
    // ============================================================
    mux2 #(32) resmux(aluoutW, readdataW, memtoregW, resultW);    // ResultW
endmodule



//////////////////////////////////////////////////////////////////////
// Register File Module
//////////////////////////////////////////////////////////////////////
module regfile (
    input logic clk,
    input logic we3,
    input logic [4:0] ra1, ra2, wa3,
    input logic [31:0] wd3,
    output logic [31:0] rd1, rd2
);
    
    logic [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally
    // write third port on falling edge of clock
    // register 0 hardwired to 0
    always_ff @(negedge clk)
        if (we3) rf[wa3] <= wd3;

    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

//////////////////////////////////////////////////////////////////////
// ALU Module
////////////////////////////////////////////////////////////////////// 
module alu(
    input logic [31:0] a,          // First operand
    input logic [31:0] b,          // Second operand
    input logic [2:0] control,     // ALU control signal
    output logic [31:0] result, // ALU result
    output logic zero              // Zero flag
);

    // Define ALU operations based on control signal
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    
    // Calculate result based on control input
    always_comb begin
        case(control)
            ALU_AND: result = a & b;                     // AND
            ALU_OR:  result = a | b;                     // OR
            ALU_ADD: result = a + b;                     // ADD
            ALU_SUB: result = a - b;                     // SUB
            ALU_SLT: result = {31'b0, $signed(a) < $signed(b)}; // Set Less Than (signed)
            default: result = 32'bx;                     // Undefined operation
        endcase
    end
    
    // Set zero flag when result is 0
    assign zero = (result == 32'b0);
    
endmodule


//////////////////////////////////////////////////////////////////////
// 2-to-1 Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux2 # (parameter WIDTH = 8) (
    input logic [WIDTH-1:0] d0, d1,
    input logic s,
    output logic [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule


//////////////////////////////////////////////////////////////////////
// 3-to-1 Multiplexer Module
//////////////////////////////////////////////////////////////////////
module mux3 #(parameter int WIDTH = 8) (
    input  logic [WIDTH-1:0] d0, d1, d2,
    input  logic [1:0]       s,
    output logic [WIDTH-1:0] y
);
    assign y = s[1] ? d2 : (s[0] ? d1 : d0);
endmodule


//////////////////////////////////////////////////////////////////////
// Sign Extension Module
//////////////////////////////////////////////////////////////////////
module signext (
    input logic [15:0] a,
    output logic [31:0] y
);
    assign y = {{16{a[15]}}, a};
endmodule


//////////////////////////////////////////////////////////////////////
// Flop Enable Register Module
//////////////////////////////////////////////////////////////////////
module flopenr #(parameter int WIDTH = 8) (
    input  logic clk, reset, en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or posedge reset)
        if (reset)   q <= '0;
        else if (en) q <= d;
endmodule
