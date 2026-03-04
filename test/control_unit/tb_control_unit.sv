`default_nettype none
`include "riscv32.svh"  // 共通の定数ファイル (ALU_CODES, FUNCTx, OPCODEsなど)

module tb_control_unit;

    // DUTポート宣言
    reg [`DATA_WIDTH-1:0] instruction;

    wire RegWrite;
    wire MemRead;
    wire MemWrite;
    wire ALUSrcA;
    wire ALUSrcB;
    wire [`ALU_CONTROL_WIDTH-1:0] ALU_control;
    wire [`RESULT_SRC_WIDTH-1:0] ResultSrc;

    // 定数 (期待値検証用)
    parameter RESULT_ALU = 2'b00;
    parameter RESULT_MEM = 2'b01;
    parameter RESULT_PC4 = 2'b10;

    // テスト対象モジュールのインスタンス化
    control_unit dut (
        .instruction(instruction),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ALU_control(ALU_control),
        .ResultSrc(ResultSrc)
    );

    // ------------------------------------------------------------------
    // テスト手順
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);

        $display("-------------------------------------------");
        $display("Starting CONTROL_UNIT Testbench");
        $display("-------------------------------------------");

        // 信号の安定化のため初期化
        instruction = 0;
        #5;

        // --- T1: ADD 命令 (R-Type) ---
        // 0000000 00010 00000 000 00010 0110011 (ADD x2, x0, x2)
        instruction = 32'b00000000001000000000000100110011;
        #5;
        $display("[T1] ADD (R-Type) 検証");
        // 期待値: RegWrite=1, ALUSrcB=0 (Reg), ALU_control=ADD, ResultSrc=ALU
        if (RegWrite == 1 && ALU_control == `ALU_ADD && ALUSrcB == 0 && ResultSrc == RESULT_ALU)
            $display("  [PASS] ADD: 制御信号が期待通りです。");
        else $display("  [FAIL] ADD: 制御信号が不一致です。");

        // --- T2: SUB 命令 (R-Type) ---
        // 0100000 00010 00000 000 00010 0110011 (SUB x2, x0, x2)
        instruction = 32'b01000000001000000000000100110011;
        #5;
        $display("[T2] SUB (R-Type) 検証");
        // 期待値: RegWrite=1, ALUSrcB=0, ALU_control=SUB
        if (RegWrite == 1 && ALU_control == `ALU_SUB && ALUSrcB == 0)
            $display("  [PASS] SUB: 制御信号が期待通りです。");
        else $display("  [FAIL] SUB: 制御信号が不一致です。");

        // --- T3: ADDI 命令 (I-Type Arith) ---
        // 000000000100 00000 000 00010 0010011 (ADDI x2, x0, 4)
        instruction = 32'b00000000010000000000000100010011;
        #5;
        $display("[T3] ADDI (I-Type Arith) 検証");
        // 期待値: RegWrite=1, ALUSrcB=1 (Imm), ALU_control=ADD
        if (RegWrite == 1 && ALU_control == `ALU_ADD && ALUSrcB == 1)
            $display("  [PASS] ADDI: 制御信号が期待通りです。");
        else $display("  [FAIL] ADDI: 制御信号が不一致です。");

        // --- T4: LW 命令 (I-Type Load) ---
        // 000000000100 00000 010 00010 0000011 (LW x2, 4(x0))
        instruction = 32'b0000000001000000001000010000011;
        #5;
        $display("[T4] LW (Load) 検証");
        // 期待値: RegWrite=1, MemRead=1, ALUSrcB=1, ALU_control=ADD, ResultSrc=MEM
        if (RegWrite == 1 && MemRead == 1 && ResultSrc == RESULT_MEM)
            $display("  [PASS] LW: 制御信号が期待通りです。");
        else $display("  [FAIL] LW: 制御信号が不一致です。");

        // --- T5: SW 命令 (S-Type Store) ---
        // 0000000 00010 00000 010 00000 0100011 (SW x2, 0(x0))
        instruction = 32'b00000000001000000010000000100011;
        #5;
        $display("[T5] SW (Store) 検証");
        // 期待値: MemWrite=1, ALUSrcB=1, ALU_control=ADD, RegWrite=0
        if (MemWrite == 1 && RegWrite == 0 && ALUSrcB == 1)
            $display("  [PASS] SW: 制御信号が期待通りです。");
        else $display("  [FAIL] SW: 制御信号が不一致です。");

        // --- T6: BEQ 命令 (B-Type Branch) ---
        // imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode
        // 0000000 00010 00000 000 00000 1100011 (BEQ x0, x2, offset)
        instruction = 32'b00000000001000000000000101100011;
        #5;
        $display("[T6] BEQ (Branch) 検証");
        // 期待値: RegWrite=0, MemWrite=0, ALUSrcB=0, ALU_control=BR_BEQ
        if (RegWrite == 0 && MemWrite == 0 && ALU_control == `BR_BEQ)
            $display("  [PASS] BEQ: 制御信号が期待通りです。");
        else $display("  [FAIL] BEQ: 制御信号が不一致です。");

        $display("-------------------------------------------");
        $display("制御ユニット検証終了");
        $display("-------------------------------------------");

        $finish;
    end
endmodule
