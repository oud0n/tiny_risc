`default_nettype none
`include "riscv32.svh"

// --------------------------------------------------------------------------
// RISC-V 32-bit Single Cycle Processor Top Module
// --------------------------------------------------------------------------
module riscv32 (
    // 外部インターフェース (クロック、リセット、メモリI/O)
    input wire clk,
    input wire resetn,

    // Instruction Memory Interface (簡略化のため、ここでは直接アクセス)
    input wire [`DATA_WIDTH-1:0] instruction_in,  // 外部からフェッチされた命令

    // Data Memory Interface (未実装だが、インターフェースを定義)
    input  wire [`DATA_WIDTH-1:0] mem_rdata,  // メモリからの読み出しデータ
    output wire [`DATA_WIDTH-1:0] mem_addr,   // メモリのアドレス
    output wire                   mem_wen,    // メモリ書き込み有効
    output wire [`DATA_WIDTH-1:0] mem_wdata   // メモリへの書き込みデータ

);
    // --- Wires for Data Path ---

    // PC (Program Counter)
    reg [`DATA_WIDTH-1:0] PC_reg;
    wire [`DATA_WIDTH-1:0] PC_next;
    wire [`DATA_WIDTH-1:0] PC_plus4;

    // Control Unit Signals (Control Unitの出力)
    wire RegWrite;
    wire MemRead;
    wire ALUSrcA;
    wire ALUSrcB;
    wire [`ALU_CONTROL_WIDTH-1:0] ALU_control;
    wire [`RESULT_SRC_WIDTH-1:0] ResultSrc;

    // Instruction Decode & Register File
    wire [`REG_WIDTH-1:0] rs1_addr;
    wire [`REG_WIDTH-1:0] rs2_addr;
    wire [`REG_WIDTH-1:0] rd_addr;
    wire [`DATA_WIDTH-1:0] rs1_data;
    wire [`DATA_WIDTH-1:0] rs2_data;

    // ALU Inputs/Output
    wire [`DATA_WIDTH-1:0] ALU_A_in;
    wire [`DATA_WIDTH-1:0] ALU_B_in;
    wire [`DATA_WIDTH-1:0] ALU_result;
    wire ALU_is_zero;

    // Immediate & Sign Extension (簡略化のため、ここでは即値I-Typeのみ定義)
    wire [`DATA_WIDTH-1:0] imm_i_sext;

    // S-Type即値の符号拡張 (新規追加)
    wire [`DATA_WIDTH-1:0] imm_s_sext;

    // Write Back
    wire [`DATA_WIDTH-1:0] wb_data;


    // =========================================================================
    // 1. Instruction Fetch (IF) Stage & PC Logic
    // =========================================================================

    // PCのインクリメント
    assign PC_plus4 = PC_reg + `DATA_WIDTH'd4;

    // PCの次の値を選択 (初期段階では分岐・ジャンプなし)
    assign PC_next  = PC_plus4;

    // PCレジスタの更新 (クロック同期)
    always @(posedge clk) begin
        if (~resetn) PC_reg <= 32'h0;  // リセットでPCを0に
        else PC_reg <= PC_next;
    end

    // 命令アドレスはPCレジスタ
    // 通常、命令メモリへのアドレスバスに接続される
    // (ここでは instruction_in を外部からの入力として代用)


    // =========================================================================
    // 2. Control Unit Instantiation (ID Stage)
    // =========================================================================

    control_unit ctrl_inst (
        .instruction(instruction_in),
        .RegWrite   (RegWrite),
        .MemRead    (MemRead),
        .MemWrite   (mem_wen),
        .ALUSrcA    (ALUSrcA),
        .ALUSrcB    (ALUSrcB),
        .ALU_control(ALU_control),
        .ResultSrc  (ResultSrc)
    );

    // =========================================================================
    // 3. Instruction Decode (ID) & Immediate Generation
    // =========================================================================

    // レジスタアドレス抽出
    assign rs1_addr = instruction_in[19:15];
    assign rs2_addr = instruction_in[24:20];
    assign rd_addr = instruction_in[11:7];

    // I-Type 即値の符号拡張 (簡略化)
    // instruction[31:20]を符号拡張してimm_i_sextとする
    // { {12{instruction_in[31]}}, instruction_in[31:20] }
    assign imm_i_sext = {{(`DATA_WIDTH - 12) {instruction_in[31]}}, instruction_in[31:20]};

    // S-Type 即値の符号拡張 (instruction[31:25]とinstruction[11:7]を連結)
    assign imm_s_sext = {{(`DATA_WIDTH - 12) {instruction_in[31]}}, instruction_in[31:25], instruction_in[11:7]};

    // =========================================================================
    // 4. Register File Instantiation (ID Stage)
    // =========================================================================

    register_file reg_file_inst (
        .clk         (clk),
        .resetn      (resetn),
        .read_addr_a (rs1_addr),
        .read_data_a (rs1_data),
        .read_addr_b (rs2_addr),
        .read_data_b (rs2_data),
        .write_enable(RegWrite),
        .write_addr  (rd_addr),
        .write_data  (wb_data)    // Write Backの結果を接続
    );


    // =========================================================================
    // 5. ALU Operand Selection (EX Stage)
    // =========================================================================

    // ALU A 入力選択: 0=Reg Data (rs1_data), 1=PC (Branch/AUIPC用)
    assign ALU_A_in = (ALUSrcA == 1'b1) ? PC_reg : rs1_data;

    // ALU B 入力選択: 0=Reg Data (rs2_data), 1=Immediate (imm_i_sext or imm_s_sext)
    // 制御信号が即値を使うことを示している場合、さらに命令の種類で即値を切り替える
    assign ALU_B_in = (ALUSrcB == 1'b1) ?
        // 即値を使う場合: Store命令かそれ以外か？
        (instruction_in[`OPCODE_WIDTH-1:0] == `OPCODE_STORE) ? imm_s_sext :  // Store命令 (S-Type) なら imm_s_sext
        imm_i_sext :  // I-Type Arith/Load なら imm_i_sext
        rs2_data;  // 即値を使わないなら Reg Data


    // =========================================================================
    // 6. ALU Instantiation (EX Stage)
    // =========================================================================

    alu alu_inst (
        .a               (ALU_A_in),
        .b               (ALU_B_in),
        .alu_control_code(ALU_control),
        .out             (ALU_result),
        .is_zero         (ALU_is_zero)   // Branch/BEQ命令で使用
    );


    // =========================================================================
    // 7. Data Memory Interface (MEM Stage)
    // =========================================================================

    // メモリアドレスはALUの結果
    assign mem_addr  = ALU_result;

    // 書き込みデータはrs2のレジスタデータ (Store命令用)
    assign mem_wdata = rs2_data;


    // =========================================================================
    // 8. Write Back (WB) Stage
    // =========================================================================

    // レジスタへの書き込みデータ選択
    // ResultSrc: 00=ALU結果, 01=メモリデータ, 10=PC+4 (JAL用)
    assign wb_data   = (ResultSrc == `RESULT_MEM) ? mem_rdata : (ResultSrc == `RESULT_PC4) ? PC_plus4 : ALU_result;

endmodule

`default_nettype wire
