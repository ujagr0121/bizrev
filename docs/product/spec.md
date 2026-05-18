# プロダクト概要 — bizrev

> 信頼できる情報源 (Source of Truth): Google ドキュメント「新規ビジネスアイデア実現性評価AIエージェントチーム 設計検討資料」
> (ID `1yqtPUGXNqxSaefkcGjxRYJkXu9Co34-iDF2m0bT8MQI`)。このファイルは Google ドキュメントの内容を反映したものです。内容に乖離が生じた場合は Google ドキュメントが優先され、このファイルは再反映されます。

## 1. エグゼクティブサマリー

ビジネスアイデア（数文から数百文字程度の非構造化テキスト）を入力とし、人間のオーナーに対して構造化された「Go / Conditional Go（条件付きGo）/ NoGo / Hold」の推奨決定を生成する「AIエージェントチーム」を構築します。

単なる「相談相手（スパーリングパートナー）」のチャットボットではなく、LLM を状態機械（ステートマシン）内のワーカーとして機能させる**決定論的ワークフロー**です。エージェント間の通信は**構造化された JSON** (Pydantic / JSON Schema) で行われ、人間の承認（Human-in-the-loop）ゲートが組み込まれています。

スコープ：1〜2週間で提供可能な個人開発向け MVP。将来のエンタープライズ版（GitHub Projects との連携、過去の NoGo アイデアに対する RAG など）への明確な拡張パスを備えています。

### 前提条件 (Assumptions)

- 初期入力：数文から数百文字程度の自由形式のテキスト。
- バックエンド：オーケストレーション用の Python (FastAPI)。REST を介してフロントエンドと通信。
- フロントエンド：Next.js。
- インフラ：コストと運用のためのサーバーレス / PaaS（Vercel、Supabase、Render）。

## 2. システムの概要 (System overview)

システムは状態機械（ステートマシン）です。LLM はパイプラインのワーカーであり、制御フローは決定論的なコードです。

1. **入力フェーズ** — ユーザーがアイデアを入力します。受付エージェントが 1〜2 の明確化のための質問を行う場合があります。
2. **構造化フェーズ** — 受付エージェントがアイデアを `IdeaBrief` JSON ドキュメントに変換し、データベースに永続化します。
3. **調査フェーズ** — 専門エージェント（スペシャリスト）が概要を読み取り、それぞれ独自の分析（Tavily を介した Web 検索など）を実行し、型定義された JSON を出力します。依存関係が許す限り、エージェントは並行して動作します。
4. **統合 & 監査フェーズ** — 統合エージェントが結果を集約し、クリティカルレビューエージェントが「楽観バイアス」や「論理の飛躍」がないかを監査します。
5. **意思決定フェーズ** — ユーザーがダッシュボードを確認し、「Go / Conditional Go / NoGo / Hold」を選択します。
6. **アクションフェーズ** — 「Go」の場合、システムは初期の実装タスクをプロジェクトトラッカー（将来的に GitHub Projects V2）に登録します。

## エージェント一覧（スペシャリスト）

（詳細なスキーマは設計段階で決定されます — `docs/architecture/overview.md` を参照してください。）

- **競合 / 代替分析**（「これは単なる ChatGPT ではないか？」というリスク評価を含む）。
- **市場規模 & TAM/SAM/SOM** の現実的な検証。
- **顧客の課題の深刻度**（YC の「髪に火がついている状態 (hair on fire)」のフレーミング）。
- **技術的実現可能性 & 開発期間**の見積もり。
- **マネタイズ / ユニットエコノミクス**。
- **法規制 / コンプライアンス**のリスク。

さらに：
- **統合エージェント (Integration agent)** — レポートを組み立てます。
- **クリティカルレビュアー (Critical reviewer)** — 意図的に懐疑的なトーンで最終監査を行います。

## スキーマの断片（仕様書からの抜粋）

コントラクトのスタイルを示す、あるスペシャリストの出力スキーマの例：

```json
{
  "type": "object",
  "properties": {
    "competitors": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "url":  {"type": "string"},
          "threat_level":   {"type": "string", "enum": ["High", "Medium", "Low"]},
          "key_difference": {"type": "string"}
        },
        "required": ["name", "url", "threat_level", "key_difference"]
      }
    },
    "chatgpt_replacement_risk": {"type": "boolean"},
    "confidence_score": {"type": "integer", "minimum": 0, "maximum": 100},
    "sources": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "url":            {"type": "string"},
          "accessed_date":  {"type": "string"}
        }
      }
    }
  },
  "required": ["competitors", "chatgpt_replacement_risk", "confidence_score", "sources"]
}
```

## コスト & 運用に関する注意事項

- **コンテキストの再課金。** 単純なマルチエージェントパイプラインでは、各エージェントが過去のコンテキストに再度支払うため、単一モデル実行の最大 4.8 倍のコストがかかる可能性があります。対策：
  - 会話履歴全体ではなく、抽出された JSON のみを渡します（「エンティティメモリ」）。
  - 共有システムプロンプトには Anthropic のプロンプトキャッシュを使用します。
  - 安価な抽出タスクには GPT-4o-mini を割り当て、統合とレビューには Claude Sonnet を確保します。
- LangGraph の各ノードでのイテレーション数を制限します（`max_iterations ≈ 3`）。これにより、検索漏れによって無限のリトライループが発生するのを防ぎます。

## 失敗モードと対策

| 失敗モード | 原因 | 対策 |
|---|---|---|
| ユーザーに同調する「イエスマン」出力 | ユーザーを喜ばせるための RLHF 報酬 | 最後に独立したクリティカルレビュアーを配置し、意図的に厳格なトーンで評価 |
| 捏造された市場規模 | 検索結果不足を補うためのハルシネーション | プロンプトでソース URL のない数値の出力を禁止。抽出と生成を分割する |
| API コストの暴走 | 検索で有用な情報が得られないことによるリトライループ | ノードあたりのイテレーション数をハード制限 |
| 実用に適さないレポート | 単にエージェントの出力を連結したもの | 統合エージェントの役割を「要約」ではなく「Go/NoGo の軸の抽出」とする |

## ロードマップ（初期の2週間）

**第1週 — バックエンド & コアロジック**
- 1〜2日目：LangGraph 環境の構築、Supabase スキーマの作成、Tavily アカウントの設定。
- 3〜4日目：6つのエージェントのプロンプト + Pydantic 出力スキーマの作成。
- 5〜6日目：LangGraph での順次 DAG の構築。固定のアイデア文字列を使用した疎通確認テスト。
- 7日目：FastAPI エンドポイント、タイムアウト/エラーハンドリングの実装。

**第2週 — フロントエンド & 統合**
- 8〜9日目：Next.js の雛形作成、Supabase クライアントの実装。
- 10〜11日目：アイデア入力 + 進捗表示 UI の実装。
- 12〜13日目：レポートダッシュボード（Markdown + チャート）の実装、DB に書き戻す Go/NoGo ボタンの実装。
- 14日目：E2E テスト、プロンプト調整、Vercel + Render へのデプロイ。

## 将来の拡張機能（MVP以降）

- GitHub Projects V2 GraphQL 連携（「Go」判定時に MVP のイシューを自動起票）。
- 「Conditional Go」判定時のインタビューシート自動生成。
- 過去に NoGo 判定されたアイデアに対する pgvector を活用した RAG により、「アイデア X と同様の失敗パターン」の警告を表示。

## 参照 (References)

- LangGraph ドキュメント (state machine + interrupt patterns)
- CrewAI Sequential/Hierarchical (role design patterns)
- OpenAI Structured Outputs ガイド
- GitHub Projects V2 GraphQL API
- Y Combinator Startup School ("hair on fire problem")
