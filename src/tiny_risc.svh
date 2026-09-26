`ifndef RISCV32_SVH
`define RISCV32_SVH

// ------------------------------------------------------------------
// 1. 基本設定 (データ幅とレジスタ本数)
// ------------------------------------------------------------------
`define DATA_WIDTH 32
`define REG_WIDTH 5
`define ALU_CONTROL_WIDTH 4
`define RESULT_SRC_WIDTH 2
`define OPCODE_WIDTH 7
`define FUNCT3_WIDTH 3
`define FUNCT7_WIDTH 7

// ------------------------------------------------------------------
// 2. RISC-V 命令 Opcode (7-bit: inst[6:0])
// ------------------------------------------------------------------
`define OPCODE_LOAD 7'b0000011 // LW, LH, LB (I-type Load)
`define OPCODE_I_TYPE 7'b0010011 // ADDI, SLLI, SRLI, SRAI (I-type Arith)
`define OPCODE_AUIPC 7'b0010111 // AUIPC (U-type)
`define OPCODE_STORE 7'b0100011 // SW, SH, SB (S-type Store)
`define OPCODE_R_TYPE 7'b0110011 // ADD, SUB, SLT, XOR, etc. (R-type)
`define OPCODE_LUI 7'b0110111 // LUI (U-type)
`define OPCODE_BRANCH 7'b1100011 // BEQ, BNE, BLT, BGE, etc. (B-type)
`define OPCODE_JALR 7'b1100111 // JALR (I-type Jump)
`define OPCODE_JAL 7'b1101111 // JAL (J-type Jump)
`define OPCODE_MISC_MEM 7'b0001111 // FENCE, FENCE.I (I-type Sync)
`define OPCODE_SYSTEM 7'b1110011 // ECALL, EBREAK, CSRR* (I-type System)

// ------------------------------------------------------------------
// 3. RISC-V Funct3 (3-bit: inst[14:12])
// ------------------------------------------------------------------
// R-Type & I-Type (共通・演算)
`define FUNCT3_ADD_SUB 3'b000    // ADD / SUB (R-Type)
`define FUNCT3_ADDI 3'b000    // ADDI (I-Type)
`define FUNCT3_SLL 3'b001    // SLL (R-Type)
`define FUNCT3_SLLI 3'b001    // SLLI (I-Type)
`define FUNCT3_SLT 3'b010    // SLT (R-Type)
`define FUNCT3_SLTI 3'b010    // SLTI (I-Type)
`define FUNCT3_SLTU 3'b011    // SLTU (R-Type)
`define FUNCT3_SLTIU 3'b011    // SLTIU (I-Type)
`define FUNCT3_XOR 3'b100    // XOR (R-Type)
`define FUNCT3_XORI 3'b100    // XORI (I-Type)
`define FUNCT3_SHIFT     3'b101    // SRL / SRA / SRLI / SRAI 用共通デコードプレースホルダ
`define FUNCT3_SRL_SRA 3'b101    // SRL / SRA (R-Type)
`define FUNCT3_SRAI_SRLI 3'b101    // SRAI / SRLI (I-Type)
`define FUNCT3_OR 3'b110    // OR (R-Type)
`define FUNCT3_ORI 3'b110    // ORI (I-Type)
`define FUNCT3_AND 3'b111    // AND (R-Type)
`define FUNCT3_ANDI 3'b111    // ANDI (I-Type)

// B-Type (Branch)
`define FUNCT3_BEQ 3'b000    // BEQ
`define FUNCT3_BNE 3'b001    // BNE
`define FUNCT3_BLT 3'b100    // BLT
`define FUNCT3_BGE 3'b101    // BGE
`define FUNCT3_BLTU 3'b110    // BLTU
`define FUNCT3_BGEU 3'b111    // BGEU

// ------------------------------------------------------------------
// 4. RISC-V Funct7 (7-bit: inst[31:25])
// ------------------------------------------------------------------
`define FUNCT7_ADD_SLL_SRL 7'b0000000 // ADD, SLL, SRL (R-type)
`define FUNCT7_SUB_SRA 7'b0100000 // SUB, SRA (R-type / I-type shift)
`define FUNCT7_SUB 7'b0100000 // SUB 判定用
`define FUNCT7_SRA 7'b0100000 // SRA 判定用

// ------------------------------------------------------------------
// 5. ALU 制御コード (4-bit, 制御ユニットが出力)
// ------------------------------------------------------------------
// 演算命令
`define ALU_ADD 4'h0
`define ALU_SUB 4'h1
`define ALU_AND 4'h2
`define ALU_OR 4'h3
`define ALU_XOR 4'h4
`define ALU_SLL 4'h5
`define ALU_SRL 4'h6
`define ALU_SRA 4'h7
`define ALU_SLT 4'h8
`define ALU_SLTU 4'h9
`define ALU_LUI 4'hA

// 分岐比較 (Branch)
// BEQ/BNE/BLT/BGE 命令の実行に必要な比較指示
`define BR_BEQ 4'hA // Branch Equal (A == B)
`define BR_BNE 4'hB // Branch Not Equal (A != B)
`define BR_BLT 4'hC // Branch Less Than Signed (A <s B)
`define BR_BGE 4'hD // Branch Greater Than or Equal Signed (A >=s B)
`define BR_BLTU 4'hE // Branch Less Than Unsigned (A <u B)
`define BR_BGEU 4'hF // Branch Greater Than or Equal Unsigned (A >=u B)

// ------------------------------------------------------------------
// 6. Write Back Data Source (ResultSrc: 2-bit)
// ------------------------------------------------------------------
`define RESULT_SRC_ALU 2'b00  // ALUの結果を書き込む (デフォルト)
`define RESULT_SRC_MEM 2'b01  // メモリからの読み出しデータを書き込む (Load命令用)
`define RESULT_SRC_PC4 2'b10  // PC+4の値を書き込む (JAL命令用)

`define RESULT_ALU 2'b00  // RESULT_SRC_ALU と同等 (別名)
`define RESULT_MEM 2'b01  // RESULT_SRC_MEM と同等 (別名)
`define RESULT_PC4 2'b10  // RESULT_SRC_PC4 と同等 (別名)
// 2'b11 は未定義/予約

`endif  // RISCV32_SVH
