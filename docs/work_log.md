# 作業完了報告・実施内容記録 (Work Log)

## 1. 実施概要
ユーザーからの要請に基づき、RISC-V 32ビット基本整数命令セット（RV32I）の完全実装、4コア構成を前提としたマルチコア共有メモリSoCの構築、レジスタ配列によるRAM/ROM代用、シミュレータ環境整備、公式アーキテクチャテスト（riscv-tests RV32UI）による全命令検証、および local_ai_gateway MCP サーバーとの連携作業を実施した。

---

## 2. 実施項目詳細

### 2.1 シミュレータおよびクロス開発環境の構築
- **Icarus Verilog (`iverilog` / `vvp` 12.0)**:
  - ユーザーローカル環境 (`~/.local/`) にインストールし、パスを通すとともにライブラリリンクを調整。
  - SystemVerilog 2012 対応シミュレーション環境を整備。
- **RISC-V GNU Toolchain (`riscv64-unknown-elf-gcc`, `as`, `ld`, `objcopy`, `objdump` 13.2.0)**:
  - ユーザーローカル環境に展開・セットアップ。
  - `-march=rv32i -mabi=ilp32` による 32 ビット RISC-V バイナリ生成環境を確立。

### 2.2 local_ai_gateway MCP 連携
- ドキュメント RAG:
  - [riscv-unprivileged.pdf](file:///home/n4styb33/work/tiny_risc/pdf/riscv-unprivileged.pdf) を `local_ai_gateway` の `riscv` プロジェクトコレクションとして登録・インデックス化（`add_source`）。
  - `search_docs` を用いて、RV32I の命令仕様および FENCE / SYSTEM 命令の標準規約を確認・参照。
- Agent Runtime 連携:
  - `start_agent_task` を用い、コーディングおよびテストスイート実行タスクを local_ai_gateway へ投入。
  - サンドボックス環境下での自動検証（`verification_commands`）をパスさせ、全タスク正常完了（`status: completed`, `verification: passed`）を記録。

### 2.3 RV32I プロセッサコア (`tiny_risc`) の完全化
- **ヘッダ定義 (`src/tiny_risc.svh`)**:
  - `OPCODE_MISC_MEM` (`7'b0001111`)、`OPCODE_SYSTEM` (`7'b1110011`) などの命令コード定義を整備。
- **命令デコーダ (`src/control.sv`)**:
  - `OPCODE_MISC_MEM` (FENCE): インオーダー実行かつ調停器による直列化メモリモデルのため、**NOP** として安全に処理。
  - `OPCODE_SYSTEM`: `illegal_op = 1` を出力。
  - 未定義 opcode: `illegal_op = 1` を出力。
  - `illegal_op` 出力ポートを追加。
- **コア統合 (`src/tiny_risc.sv`)**:
  - `illegal_op` を受け取り、`EXECUTE` ステートで安全に `FAULTED` 状態へ遷移するロジックを実装。
  - アライメント検査（LB/LBU/LH/LHU/LW, SB/SH/SW）および制御フロー違反（分岐・ジャンプ先PCのアライメント）のフォールト処理を統合。

### 2.4 4コア共有メモリ SoC (`tiny_risc_soc`) の構築
- **デフォルトパラメータの4コア化**:
  - `N_HARTS = 4` をデフォルト値に設定。
  - 各コアのリセットベクタ間隔 `HART_STRIDE_BYTES = 64`（Core 0: 0x000, Core 1: 0x040, Core 2: 0x080, Core 3: 0x0C0）。
- **レジスタ配列による共有メモリ (`src/rv32_shared_memory.sv`)**:
  - `logic [31:0] words [0:WORDS-1];` によるレジスタ配列で命令 ROM およびデータ RAM を代用。
  - 1024 ワード（4 KiB）ずつの容量を確保。
  - バイト書き込みストローブ `wstrb` による部分バイト更新に対応。
- **ラウンドロビン調停器 (`src/rv32_mem_arbiter.sv`)**:
  - 4基のコアからの独立した命令フェッチ要求およびデータメモリアクセス要求を公平に調停。
  - 応答ルーティングの完全性を保持。

### 2.5 4コア並行同期統合検証 (`test/tiny_risc/tb_tiny_risc_4core.sv`)
- 4つの hart を同時起動（`hart_enable = 4'b1111`）し、以下の並行プログラムを実行：
  - **Hart 0**: R-Type 演算（ADD, SUB, SLL, SLT, XOR, OR, AND） $\rightarrow$ Byte 0 に `0x0D` をストア
  - **Hart 1**: I-Type 演算（ADDI, SLLI, SRAI, XORI, ORI, ANDI, SLTIU） $\rightarrow$ Byte 1 に `0x1B` をストア
  - **Hart 2**: B-Type 分岐（BEQ, BNE）判定 $\rightarrow$ Byte 2 に `0x22` をストア
  - **Hart 3**: LUI, AUIPC, FENCE 実行 $\rightarrow$ Byte 3 に `0x55` をストア。共有メモリ上の他コア完了フラグを**スピンウェイト（ポーリング）**で待機後、Word 0 を一括ロード。
- **検証結果**:
  - 全コア正常停止（`hart_fault == 4'b0000`）。
  - 共有メモリ Word 0 の合成値および Hart 3 のロード結果が **`0x55221B0D`** と完全一致。
  - 命令調停競合 **261 サイクル** を確認し、ラウンドロビン調停の正常動作を実証。

### 2.6 公式 RISC-V アーキテクチャテストスイート (`riscv-tests` RV32UI) による全命令適合性検証
- 国際標準の公式テストリポジトリ [`riscv-software-src/riscv-tests`](https://github.com/riscv-software-src/riscv-tests) を導入。
- 非特権 RV32I ベアメタル用テスト環境（`riscv_test.h`, `link.ld`）を構築。
- 全 38 テストスイート（数十〜百件超のサブテスト）を実行し、**全問合格 (38 / 38 passed, 0 failed)** を達成。

---

## 3. 作成・整備したドキュメント一覧
- [specifications.md](specifications.md): CPU機能仕様書、全体アーキテクチャ設計仕様書、各ブロック設計仕様書、検証報告書
- [multicore-architecture.md](multicore-architecture.md): 4コアマルチコア構成・同期・メモリ順序の解説
- [implementation.md](implementation.md): モジュール責務、検証構成、実装ガイド
- [work_log.md](work_log.md): 本ドキュメント（作業実施記録）
- [README.md](../README.md): プロジェクト概要およびテスト実行ガイド
