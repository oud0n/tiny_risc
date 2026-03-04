`include "riscv32.svh"  // 共通の定数ファイル（DATA_WIDTH, REG_WIDTHなど）

// -----------------------------------------------------------------------------
// RISC-V レジスタファイル (32本, 32ビット)
// -----------------------------------------------------------------------------
module register_file (
    // クロックとリセット
    input wire clk,
    input wire resetn,

    // 読み出しポート A (rs1)
    input  wire [ `REG_WIDTH-1:0] read_addr_a,  // 読み出しレジスタ番号 (5ビット)
    output wire [`DATA_WIDTH-1:0] read_data_a,  // 読み出しデータ (32ビット)

    // 読み出しポート B (rs2)
    input  wire [ `REG_WIDTH-1:0] read_addr_b,  // 読み出しレジスタ番号 (5ビット)
    output wire [`DATA_WIDTH-1:0] read_data_b,  // 読み出しデータ (32ビット)

    // 書き込みポート (rd)
    input wire                   write_enable,  // 書き込み許可信号
    input wire [ `REG_WIDTH-1:0] write_addr,    // 書き込みレジスタ番号 (5ビット)
    input wire [`DATA_WIDTH-1:0] write_data     // 書き込みデータ (32ビット)
);

    // 32本のレジスタを格納するメモリ
    // register_bank[0]はレジスタx0に相当します。
    reg [`DATA_WIDTH-1:0] register_bank[0:(1 << `REG_WIDTH) - 1];

    generate
        genvar idx;
        for (idx = 0; idx < 32; idx = idx + 1) begin : register
            wire [31:0] tmp;
            assign tmp = register_bank[idx];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 読み出し処理 (常時実行される組み合わせ論理)
    // -------------------------------------------------------------------------

    // ポートAの読み出し: アドレスがx0(0)の場合、強制的に0を出力
    assign read_data_a = (read_addr_a == 0) ? `DATA_WIDTH'h0 : register_bank[read_addr_a];

    // ポートBの読み出し: アドレスがx0(0)の場合、強制的に0を出力
    assign read_data_b = (read_addr_b == 0) ? `DATA_WIDTH'h0 : register_bank[read_addr_b];

    // -------------------------------------------------------------------------
    // 書き込み処理 (クロック同期処理)
    // -------------------------------------------------------------------------

    always @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            // リセット時、全レジスタをゼロクリア（オプション）
            // RISC-Vの仕様上必須ではないが、シミュレーション初期化に便利
            for (integer i = 0; i < `DATA_WIDTH; i = i + 1) begin
                register_bank[i] <= `DATA_WIDTH'h0;
            end
        end else if (write_enable) begin
            // 書き込み許可があり、かつ書き込みアドレスがx0(0)ではない場合のみ書き込み実行
            if (write_addr != 0) begin
                register_bank[write_addr] <= #1 write_data;
            end
        end
    end

endmodule

`default_nettype wire

