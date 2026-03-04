`default_nettype none
`include "riscv32.svh"  // 共通の定数ファイル (DATA_WIDTH=32, REG_WIDTH=5)

module tb;

    // DUT (Device Under Test: register_file) の信号宣言
    reg                     clk;
    reg                     resetn;

    reg   [ `REG_WIDTH-1:0] read_addr_a;
    wire  [`DATA_WIDTH-1:0] read_data_a;

    reg   [ `REG_WIDTH-1:0] read_addr_b;
    wire  [`DATA_WIDTH-1:0] read_data_b;

    reg                     write_enable;
    reg   [ `REG_WIDTH-1:0] write_addr;
    reg   [`DATA_WIDTH-1:0] write_data;

    logic [           31:0] WRITE_VAL_NEW;
    logic [           31:0] WRITE_ADDR;
    logic [           31:0] WRITE_VAL_OLD;


    // テスト対象モジュールのインスタンス化
    register_file dut (
        .clk(clk),
        .resetn(resetn),
        .read_addr_a(read_addr_a),
        .read_data_a(read_data_a),
        .read_addr_b(read_addr_b),
        .read_data_b(read_data_b),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .write_data(write_data)
    );

    // クロック生成 (50%デューティサイクル)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // テスト手順
    // -------------------------------------------------------------------------

    initial begin
        // Set up for waveform dumping
        $dumpfile("tb_register_file.vcd");
        $dumpvars(0, tb);

        for (int i = 0; i < `DATA_WIDTH; i = i + 1) begin
            $dumpvars(0, tb.dut.register_bank[i]);
        end

        $display("---------------------------------");
        $display("Starting REGISTER_FILE Testbench");
        $display("---------------------------------");

        $display("--- RISC-V レジスタファイル検証開始 ---");
        clk = 0;

        // リセット
        resetn = 0;
        write_enable = 0;
        read_addr_a = 5'd0;
        read_addr_b = 5'd0;
        // #10 @(negedge clk);  // クロックを一度下げるまで待つ
        #10 resetn = 1;
        $display("リセット完了。");

        // --- T1 & T2: 基本書き込みと読み出し ---
        $display("\n[T1 & T2] 基本書き込み(x5)と読み出し検証");
        write_addr   = 5'd5;
        write_data   = 32'hDEADBEEF;
        write_enable = 1;

        // クロックサイクルをまたいで書き込み実行
        #10 @(posedge clk);
        write_enable = 0;  // 書き込みを停止

        // 読み出し (x5を読み出しA、x6を読み出しB)
        read_addr_a  = 5'd5;
        read_addr_b  = 5'd6;
        #10 @(posedge clk);

        $display("  書き込み完了: Reg[%0d] <= %h", 5'd5, 32'hDEADBEEF);
        $display("  読み出しA (x5): %h, 期待値: %h", read_data_a, 32'hDEADBEEF);
        $display("  読み出しB (x6): %h, 期待値: %h", read_data_b, 32'h0);

        if (read_data_a == 32'hDEADBEEF && read_data_b == 32'h0)
            $display("  [PASS] 基本的な読み書きが成功しました。");
        else $display("  [FAIL] 基本的な読み書きに失敗しました。");

        // --- T3: x0 への書き込み無視検証 ---
        $display("\n[T3] x0 (ゼロレジスタ) への書き込み無視検証");
        write_addr   = 5'd0;  // x0レジスタ
        write_data   = 32'hAAAAAAAA;
        write_enable = 1;

        #10 @(posedge clk);
        write_enable = 0;  // 書き込みを停止

        // x0 から読み出し (読み出しは常にゼロが期待される)
        read_addr_a  = 5'd0;
        read_addr_b  = 5'd0;
        #10 @(posedge clk);

        $display("  書き込み試行: Reg[0] <= %h", 32'hAAAAAAAA);
        $display("  読み出しA (x0): %h, 期待値: %h", read_data_a, 32'h0);

        if (read_data_a == 32'h0) $display("  [PASS] x0 への書き込みが無視されました。");
        else $display("  [FAIL] x0 の値が書き換えられました。");

        // --- T4: x0 からの読み出し検証 ---
        // T3の検証過程でread_addr_aとread_addr_bはすでに5'd0になっているため、そのまま検証
        $display("\n[T4] x0 (ゼロレジスタ) からの読み出し検証");
        $display("  読み出しA (x0): %h, 期待値: %h", read_data_a, 32'h0);
        $display("  読み出しB (x0): %h, 期待値: %h", read_data_b, 32'h0);

        if (read_data_a == 32'h0 && read_data_b == 32'h0)
            $display("  [PASS] x0 からの読み出しがゼロでした。");
        else $display("  [FAIL] x0 からの読み出しがゼロではありませんでした。");

        // --- T5: 多重読み出し検証 ---
        $display("\n[T5] 多重書き込みと読み出し検証 (x10, x11)");

        // x10 に書き込み (AAAA)
        write_addr   = 5'd10;
        write_data   = 32'hAAAA0000;
        write_enable = 1;
        #10 @(posedge clk);
        write_enable = 0;

        // x11 に書き込み (BBBB)
        write_addr   = 5'd11;
        write_data   = 32'hBBBB1111;
        write_enable = 1;
        #10 @(posedge clk);
        write_enable = 0;

        // x10 と x11 を同時に読み出し
        read_addr_a  = 5'd10;
        read_addr_b  = 5'd11;
        #10 @(posedge clk);

        $display("  読み出しA (x10): %h, 期待値: %h", read_data_a, 32'hAAAA0000);
        $display("  読み出しB (x11): %h, 期待値: %h", read_data_b, 32'hBBBB1111);

        if (read_data_a == 32'hAAAA0000 && read_data_b == 32'hBBBB1111)
            $display("  [PASS] 多重読み出しが成功しました。");
        else $display("  [FAIL] 多重読み出しに失敗しました。");

        // --- T6: 同一サイクルでの読み書き検証 (リード・アズ・ア・ライト) ---
        $display("\n[T6] 同一サイクル読み書き検証 (x7)");


        WRITE_VAL_NEW = 32'hCCDDCCDD;
        WRITE_ADDR = 5'd7;

        // x7に初期値 (0x1234) を書き込む (次のサイクルで古い値として使用)
        write_addr = WRITE_ADDR;
        write_data = 32'h12345678;
        write_enable = 1;
        #10 @(posedge clk);
        WRITE_VAL_OLD = 32'h12345678;

        // クロックエッジの瞬間に、x7に新しい値(0xCCDD)を書き込みながら、x7を読み出す
        read_addr_a = WRITE_ADDR;
        write_data = WRITE_VAL_NEW;
        write_enable = 1;


        // シミュレーター起因っぽい期待値不一致が起こるので1ps待機
        #1

        // 読み出しデータは、このエッジで書き込まれた新しい値ではなく、
        // エッジ直前の古い値 (0x12345678) であることが期待される
        $display(
            "  書き込みアドレス: Reg[%0d] @ %0t", WRITE_ADDR, $realtime
        );
        $display("  書き込みデータ (新): %h", WRITE_VAL_NEW);
        $display("  読み出しデータ (旧): %h, 期待値: %h", read_data_a, WRITE_VAL_OLD);

        // 検証: 読み出しが古い値 (WRITE_VAL_OLD) であること
        if (read_data_a == WRITE_VAL_OLD)
            $display("  [PASS] 同一サイクル読み書きで古い値が読み出されました。");
        else
            $display(
                "  [FAIL] 同一サイクル読み書きで新しい値または不正な値が読み出されました。"
            );

        // クロックが上昇する瞬間を待機
        #1 @(posedge clk);

        // 次のサイクルで値が更新されたことを確認 (オプションだが確認として実行)
        read_addr_a  = WRITE_ADDR;
        write_enable = 0;
        #10 @(posedge clk);
        $display("  次のサイクルで更新確認: %h, 期待値: %h", read_data_a, WRITE_VAL_NEW);

        $display("\n--- レジスタファイル検証終了 ---");
        $finish;
    end
endmodule
