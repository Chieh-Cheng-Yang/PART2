//////////////////////////////////////////////////////////////////////
// ===================================================================
// This file has the following module implementations:
// 1. controller
// 2. maindec
// 3. aludec
// ===================================================================
// Pipelined version: decodes InstrD (Decode stage). The branch decision
// (PCSrcD = BranchD & EqualD) now lives in the datapath, so the controller
// no longer takes "zero" or produces "pcsrc".
//////////////////////////////////////////////////////////////////////
module controller (
    input  logic [5:0] op, funct,       // InstrD[31:26], InstrD[5:0]
    output logic       memtoregD, memwriteD,
    output logic       branchD, alusrcD,
    output logic       regdstD, regwriteD,
    output logic       jumpD,
    output logic [2:0] alucontrolD
);
    logic [1:0] aluopD;

    maindec md (op, memtoregD, memwriteD, branchD, alusrcD,
                regdstD, regwriteD, jumpD, aluopD);
    aludec  ad (funct, aluopD, alucontrolD);
endmodule


//////////////////////////////////////////////////////////////////////
// Main Decoder module
//////////////////////////////////////////////////////////////////////
module maindec (
    input  logic [5:0] op,
    output logic       memtoreg, memwrite,
    output logic       branch, alusrc,
    output logic       regdst, regwrite,
    output logic       jump,
    output logic [1:0] aluop
);
    logic [8:0] controls;

    assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop} = controls;

    always_comb
        case (op)
            6'b000000: controls = 9'b110000010; // R-type
            6'b100011: controls = 9'b101001000; // LW
            6'b101011: controls = 9'b001010000; // SW
            6'b000100: controls = 9'b000100001; // BEQ
            6'b001000: controls = 9'b101000000; // ADDI
            6'b000010: controls = 9'b000000100; // J
            default:   controls = 9'b000000000; // unknown -> NOP (no X in the pipeline)
        endcase
endmodule


//////////////////////////////////////////////////////////////////////
// ALU Decoder module
//////////////////////////////////////////////////////////////////////
module aludec (
    input  logic [5:0] funct,
    input  logic [1:0] aluop,
    output logic [2:0] alucontrol
);
    always_comb
        case (aluop)
            2'b00: alucontrol = 3'b010;                 // add (lw, sw, addi)
            2'b01: alucontrol = 3'b110;                 // sub (beq)
            default: case (funct)                       // R-type
                6'b100000: alucontrol = 3'b010;         // ADD
                6'b100010: alucontrol = 3'b110;         // SUB
                6'b100100: alucontrol = 3'b000;         // AND
                6'b100101: alucontrol = 3'b001;         // OR
                6'b101010: alucontrol = 3'b111;         // SLT
                default:   alucontrol = 3'b000;         // NOP (funct 0)
            endcase
        endcase
endmodule