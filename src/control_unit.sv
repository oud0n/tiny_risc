// Control Unit Module: 命令をデコードし、データパス全体への制御信号を生成する
`default_nettype none
`include "riscv32.svh"  // 共通の定数 (OPCODE, FUNCT3, ALU_CODES, etc.)

module control_unit (
    input wire [`DATA_WIDTH-1:0] instruction,

    // output wire addi,
    // output wire add,
    // output wire sub,
    // output wire lw,
    // output wire sw,
    // output wire beq,
    // output wire jal,
    // output wire sll,

    // 制御信号出力
    output logic reg_write,  // レジスタファイル書き込み有効 (1)
    output logic mem_read,  // データメモリ読み出し有効 (1)
    output logic mem_write,  // データメモリ書き込み有効 (1)
    output logic ALUSrcA,  // ALU Source A (0: RegData, 1: PC)
    output logic ALUSrcB,  // ALU Source B (0: RegData/rs2, 1: Immediate)
    output logic [`ALU_CONTROL_WIDTH-1:0] ALU_control,  // ALU操作コード (4-bit)
    output logic [`RESULT_SRC_WIDTH-1:0] ResultSrc  // 書き込みデータソース (00: ALU, 01: MemData, 10: PC+4)
);

    // 命令の各フィールドを抽出
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // ALU制御コードの幅 (4-bit)
    parameter ALU_CONTROL_WIDTH = 4;

    // ResultSrcの幅 (2-bit)
    parameter RESULT_SRC_WIDTH = 2;
    parameter RESULT_ALU = 2'b00;
    parameter RESULT_MEM = 2'b01;
    parameter RESULT_PC4 = 2'b10;

    // ------------------------------------------------------------------
    // 制御ロジック: 命令の Opcode および Funct フィールドに基づき信号を決定
    // ------------------------------------------------------------------
    logic load_type;
    logic store_type;
    logic imm_ari_type;
    logic imm_shift_type;
    logic reg_type;
    logic branch_type;
    logic jump_type;
    logic upper_type;

    always_comb begin : inst_decoder
        load_type = `OPCODE_LOAD == opcode ? 1'b1 : 1'b0;
        s_type = `OPCODE_STORE == opcode ? 1'b1 : 1'b0;
        i_type_ari = `OPCODE_I_TYPE == opcode ? 1'b1 : 1'b0;
        r_type = `OPCODE_R_TYPE == opcode ? 1'b1 : 1'b0;
        b_type = `OPCODE_BRANCH == opcode ? 1'b1 : 1'b0;
        j_type = `OPCODE_JAL == opcode ? 1'b1 : 1'b0;
        u_type = `OPCODE_LUI == opcode ? 1'b1 : 1'b0;
    end

    always_comb begin : blockName
        reg_write = (r_type) ? 1'b1 : 1'b0;

    end


    always @(*) begin
        // デフォルト値 (安全のため全て非アクティブに設定)
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        ALUSrcA = 1'b0;
        ALUSrcB = 1'b0;
        ALU_control = `ALU_ADD;  // デフォルトは加算 (アドレス計算等に利用)
        ResultSrc = RESULT_ALU;

        case (opcode)
            // R-TYPE (ADD, SUB, AND, OR, ...)
            // Opcode = 0110011 (RV32I_OP)
            `OPCODE_R_TYPE: begin
                reg_write = 1'b1;
                ALUSrcA   = 1'b0;  // rs1 (RegData)
                ALUSrcB   = 1'b0;  // rs2 (RegData)
                // ALU_control は funct3/funct7 に基づき決定 (後述)

                case (funct3)
                    // ADD/SUB (funct3=000) - funct7で区別
                    `FUNCT3_ADD_SUB: begin
                        if (funct7 == `FUNCT7_SUB) ALU_control = `ALU_SUB;  // SUB
                        else ALU_control = `ALU_ADD;  // ADD
                    end
                    // AND
                    `FUNCT3_AND: ALU_control = `ALU_AND;
                    // OR
                    `FUNCT3_OR: ALU_control = `ALU_OR;
                    // XOR
                    `FUNCT3_XOR: ALU_control = `ALU_XOR;
                    // SLT
                    `FUNCT3_SLT: ALU_control = `ALU_SLT;
                    // SLTU
                    `FUNCT3_SLTU: ALU_control = `ALU_SLTU;
                    // SLL/SRL/SRA は funct7で区別
                    `FUNCT3_SHIFT: begin
                        if (funct7 == `FUNCT7_SRA) ALU_control = `ALU_SRA;  // SRA
                        else ALU_control = `ALU_SLL;  // SLL/SRLはALU_SLL/SRLにデコード
                        // (注: SRLとSLLの区別は、ALUでB[4:0]が符号/論理シフトの制御に利用されるため、ここではSLLで統一)
                    end
                    default: ALU_control = `ALU_ADD;
                endcase
            end

            // I-TYPE (ADDI, SLLI, LW, JALR, CSR)
            // Opcode = 0010011 (RV32I_OP_IMM) - ADDI, SLLI
            `OPCODE_I_TYPE_ARITH: begin
                reg_write = 1'b1;
                ALUSrcA   = 1'b0;  // rs1 (RegData)
                ALUSrcB   = 1'b1;  // Immediate

                case (funct3)
                    `FUNCT3_ADDI: ALU_control = `ALU_ADD;
                    `FUNCT3_ANDI: ALU_control = `ALU_AND;
                    `FUNCT3_ORI: ALU_control = `ALU_OR;
                    `FUNCT3_XORI: ALU_control = `ALU_XOR;
                    `FUNCT3_SLTI: ALU_control = `ALU_SLT;
                    `FUNCT3_SLTIU: ALU_control = `ALU_SLTU;
                    `FUNCT3_SLLI: ALU_control = `ALU_SLL;
                    // SLL/SRL/SRA は funct7で区別
                    `FUNCT3_SHIFT: begin
                        if (funct7 == `FUNCT7_SRA) ALU_control = `ALU_SRA;  // SRA
                        else ALU_control = `ALU_SLL;  // SLL/SRLはALU_SLL/SRLにデコード
                        // (注: SRLとSLLの区別は、ALUでB[4:0]が符号/論理シフトの制御に利用されるため、ここではSLLで統一)
                    end
                    default: ALU_control = `ALU_ADD;
                endcase
            end

            // I-TYPE LOAD (LW, LH, LB, ...)
            // Opcode = 0000011 (RV32I_LOAD)
            `OPCODE_LOAD: begin
                reg_write = 1'b1;
                mem_read = 1'b1;
                ALUSrcA = 1'b0;  // rs1 (RegData)
                ALUSrcB = 1'b1;  // Immediate (アドレスオフセット)
                ALU_control = `ALU_ADD;  // アドレス計算: rs1 + imm
                ResultSrc = RESULT_MEM;  // 結果はメモリデータから
            end

            // S-TYPE STORE (SW, SH, SB, ...)
            // Opcode = 0100011 (RV32I_STORE)
            `OPCODE_STORE: begin
                mem_write = 1'b1;
                ALUSrcA = 1'b0;  // rs1 (RegData)
                ALUSrcB = 1'b1;  // Immediate (アドレスオフセット)
                ALU_control = `ALU_ADD;  // アドレス計算: rs1 + imm
            end

            // B-TYPE BRANCH (BEQ, BNE, ...)
            // Opcode = 1100011 (RV32I_BRANCH)
            `OPCODE_BRANCH: begin
                // 分岐判定のためにrs1, rs2を比較する必要があるが、ALU自体は演算をしない
                ALUSrcA = 1'b0;  // rs1
                ALUSrcB = 1'b0;  // rs2
                // ALU_control は funct3に基づき決定
                case (funct3)
                    `FUNCT3_BEQ: ALU_control = `BR_BEQ;  // (ここでは分岐判定ロジックとして使用)
                    `FUNCT3_BNE: ALU_control = `BR_BNE;
                    default: ALU_control = `ALU_ADD;
                endcase
            end

            default: begin
                // 未実装または不正な命令
            end
        endcase
    end
endmodule

`default_nettype wire
