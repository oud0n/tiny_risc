# Repository instructions

## Local document RAG

- ローカル PDF を調査する際は、まず Local RAG に必要な情報がないか確認し、結果が不足する場合に PDF を検索する。
- ローカル PDF の確認には、グローバル MCP server `local_ai_gateway` を使用する。
- 利用前に `list_sources` で必要な project collection が登録済みか確認する。
- EDA command/API 名、option 名、エラーメッセージは `search_docs` の `mode="exact"` を最初に使い、通常は `limit=3` とする。
- 概念やフローは `mode="hybrid"` で検索する。結果が十分なら検索を繰り返さない。
- 複数 collection を参照する場合は `projects=["A", "B"]` のように明示する。
- 回答と実装には `source_pdf` と `page` を根拠として記録する。
- `relevant_chunk` で確認できない EDA 仕様を記憶から補完しない。
- PDF 全文や広い連続ページを Codex context へ読み込まない。
- 複数箇所の統合が必要な場合だけ `ask_local_ai` を使う。CPU 推論は遅いため、command 検索には使わない。
- 新しい PDF の登録はユーザーの依頼がある場合に `add_source` を使う。
- `local_ai_gateway` の詳細契約は `/home/n4styb33/work/local_ai_gateway/docs/MCP_API.md` を参照する。
