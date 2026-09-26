// ====================================================================
// Module: control
// Description: Decodes instruction opcodes, funct3, and funct7 elements.
//              Generates datapath selection flags and ALU operations.
// ====================================================================

`default_nettype none
`include "tiny_risc.svh"

module control (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,

    output logic       reg_write,
    output logic       alu_src,
    output logic [1:0] mem_to_reg,  // 00: ALU, 01: Mem, 10: PC+4
    output logic       mem_write,
    output logic       mem_read,
    output logic       branch,
    output logic       jump,
    output logic [3:0] alu_control,
    output logic       illegal_op
);

    logic funct7_5;

    assign funct7_5 = funct7[5];

    // Single-cycle main control decoder logic
    always_comb begin
        // Setup sensible defaults in lower_case
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        mem_to_reg  = 2'b00;
        mem_write   = 1'b0;
        mem_read    = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        alu_control = `ALU_ADD;
        illegal_op  = 1'b0;

        case (opcode)
            // R-Type operations (ADD, SUB, AND, OR, XOR, shifts etc.)
            7'b0110011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;
                mem_to_reg = 2'b00;

                // Select custom operation depending on funct3 & funct7
                case (funct3)
                    `FUNCT3_ADD_SUB:
                    alu_control = (funct7_5) ? `ALU_SUB : `ALU_ADD;
                    `FUNCT3_SLL: alu_control = `ALU_SLL;
                    `FUNCT3_SLT: alu_control = `ALU_SLT;
                    `FUNCT3_SLTU: alu_control = `ALU_SLTU;
                    `FUNCT3_XOR: alu_control = `ALU_XOR;
                    `FUNCT3_SRL_SRA:
                    alu_control = (funct7_5) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_OR: alu_control = `ALU_OR;
                    `FUNCT3_AND: alu_control = `ALU_AND;
                    default: alu_control = `ALU_ADD;
                endcase
            end

            // I-Type ALU operations (ADDI, ANDI, ORI, XORI etc.)
            7'b0010011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b00;

                case (funct3)
                    `FUNCT3_ADDI: alu_control = `ALU_ADD;
                    `FUNCT3_SLLI: alu_control = `ALU_SLL;
                    `FUNCT3_SLTI: alu_control = `ALU_SLT;
                    `FUNCT3_SLTIU: alu_control = `ALU_SLTU;
                    `FUNCT3_XORI: alu_control = `ALU_XOR;
                    `FUNCT3_SRAI_SRLI:
                    alu_control = (funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRAI / SRLI
                    `FUNCT3_ORI: alu_control = `ALU_OR;  // ORI
                    `FUNCT3_ANDI: alu_control = `ALU_AND;  // ANDI
                    default: alu_control = `ALU_ADD;
                endcase
            end

            // I-Type Load operations (LW, LB, LH, LBU, LHU)
            `OPCODE_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b01; // Write-back memory contents
                mem_read   = 1'b1;
                alu_control = `ALU_ADD; // Node offset addition
            end

            // S-Type Store operations (SW, SB, SH)
            `OPCODE_STORE: begin
                reg_write  = 1'b0;
                alu_src    = 1'b1;
                mem_write  = 1'b1;
                alu_control = `ALU_ADD; // Address addition
            end

            // B-Type Branch instructions (BEQ, BNE, BLT, BGE)
            `OPCODE_BRANCH: begin
                reg_write = 1'b0;
                alu_src   = 1'b0;
                branch    = 1'b1;

                case (funct3)
                    `FUNCT3_BEQ:
                    alu_control = `ALU_SUB;  // BEQ (uses sub zero check)
                    `FUNCT3_BNE:
                    alu_control = `ALU_SUB;  // BNE (uses sub zero check)
                    `FUNCT3_BLT:
                    alu_control = `ALU_SLT;  // BLT (uses signed comparison)
                    `FUNCT3_BGE:
                    alu_control = `ALU_SLT;  // BGE (uses signed comparison)
                    `FUNCT3_BLTU:
                    alu_control = `ALU_SLTU;  // BLTU (uses unsigned comparison)
                    `FUNCT3_BGEU:
                    alu_control = `ALU_SLTU;  // BGEU (uses unsigned comparison)
                    default: alu_control = `ALU_SUB;
                endcase
            end

            // J-Type JAL jump
            `OPCODE_JAL: begin
                reg_write = 1'b1;
                mem_to_reg = 2'b10; // PC + 4 written to link register standard x1 (ra)
                jump = 1'b1;
            end

            // I-Type JALR jump
            `OPCODE_JALR: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                mem_to_reg  = 2'b10;  // PC + 4 written to link register
                jump        = 1'b1;
                alu_control = `ALU_ADD;
            end

            // U-Type LUI loading
            `OPCODE_LUI: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b00;
                alu_control = `ALU_LUI;
            end

            `OPCODE_AUIPC: begin
                reg_write  = 1'b1;
                mem_to_reg = 2'b11; // PC + U-immediate
            end

            // I-Type Sync: FENCE (treated as NOP in this architecture)
            `OPCODE_MISC_MEM: begin
                reg_write   = 1'b0;
                alu_src     = 1'b0;
                mem_to_reg  = 2'b00;
                mem_write   = 1'b0;
                mem_read    = 1'b0;
                branch      = 1'b0;
                jump        = 1'b0;
                alu_control = `ALU_ADD;
                illegal_op  = 1'b0;
            end

            // I-Type System: ECALL / EBREAK
            `OPCODE_SYSTEM: begin
                reg_write   = 1'b0;
                alu_control = `ALU_ADD;
                illegal_op  = 1'b1; // triggers execution environment trap / fault
            end

            default: begin
                // Secure unknown operations
                reg_write   = 1'b0;
                alu_control = `ALU_ADD;
                illegal_op  = 1'b1;
            end
        endcase
    end

endmodule

`default_nettype wire
