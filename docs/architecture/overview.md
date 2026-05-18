# アーキテクチャの概要 (Architecture overview)

> ステータス: **ドラフト**。ADR が承認されるたびに更新されます。不確かな場合は ADR の決定が優先されます。

## 最上位ディレクトリの構成（ターゲット）

```
backend/                  FastAPI アプリ、LangGraph ワークフロー、エージェントプロンプト
  app/
    api/                  HTTP ルート（ルーティング）
    graph/                LangGraph ノードとエッジ
    agents/               専門スペシャリストごとのプロンプト + Pydantic スキーマ
    db/                   Supabase クライアント、マイグレーション
    tools/                Tavily ラッパーなど
  tests/
  pyproject.toml

frontend/                 Next.js (App Router) UI
  app/
  components/
  lib/
  package.json

infra/                    デプロイ設定（Vercel + Render 環境、Supabase SQL）

docs/                     仕様書、アーキテクチャ、ADR（このディレクトリ）
```

上記のディレクトリツリーは**ターゲット（目標構成）**であり、まだディスク上にすべてが存在するわけではありません。初期の実装タスクによって段階的に構築されます — `tasks/` を参照してください。

## ランタイムの構成 (Runtime shape)

```
┌────────────┐    REST     ┌──────────────────────────┐
│  Next.js   │ ──────────► │  FastAPI                 │
│  (Vercel)  │ ◄────────── │  /ideas, /reports, /vote │
└────────────┘   JSON      │                          │
                           │  ┌────────────────────┐  │
                           │  │  LangGraph DAG     │  │
                           │  │  ┌──┐ ┌──┐ ┌──┐    │  │
                           │  │  │R │→│P*│→│I │→│V││  │
                           │  │  └──┘ └──┘ └──┘    │  │
                           │  └────────────────────┘  │
                           │       │       │          │
                           │   Tavily   Anthropic /   │
                           │             OpenAI       │
                           └──────────────────────────┘
                                    │
                                    ▼
                               Supabase (Postgres)
```

- R: 受付 (Reception)（アイデア → IdeaBrief）。
- P*: 並行処理スペシャリスト (Parallel specialists)（競合、市場、課題の深刻度、技術的実現可能性、マネタイズ、法規制）。
- I: 統合 & クリティカルレビュー (Integration + critical review)。
- V: 投票 (Vote)（Human-in-the-loop インタラプト。ユーザーが Go / Conditional（条件付きGo）/ NoGo / Hold をクリックする）。

## データコントラクト (Data contracts)

各エージェントは `backend/app/agents/<name>/schema.py` に Pydantic モデルを持ちます。これらのモデルは JSON スキーマとしてエクスポートされ、フロントエンドのレポートレンダラーに提供されるため、UI はデータ駆動型になります（エージェントごとの個別のビューをハードコーディングする必要はありません）。

受付エージェントの出力（`IdeaBrief`）は結合点であり、すべてのスペシャリストがこれをコンシューム（消費）します。そのスキーマは安定したコントラクトとして扱い、変更は ADR を通す必要があります。

## 横断的関心事 (Cross-cutting concerns)

- **プロンプトキャッシュ。** システムプロンプトはキャッシュ可能なプレフィックスを共有し、エージェントごとのバリエーションは末尾に追加されます。これは Anthropic のキャッシュヒット率ログで検証されます。
- **コストに応じたルーティング。** 安価な抽出タスク → GPT-4o-mini。統合およびクリティカルレビュー → Claude Sonnet（最新版）。ADR-0004 を参照（正確なモデル ID を決定した際に作成されます）。
- **イテレーション上限。** すべての LangGraph ノードには `max_iterations = 3` が設定されています。収束しないスペシャリストは、ループし続けるのではなく、信頼度の低い結果を出力します。
- **オブザーバビリティ（観察可能性）。** エージェントの実行ごとに、入力、出力、トークン数、レイテンシを含むログが `(idea_id, agent, attempt)` をキーとして `runs` テーブルに書き込まれます。ダッシュボードはこれをアイデアごとの監査トレイルとして表示します。

## 他で追跡されている未解決の質問 (Open questions tracked elsewhere)

- 正確な LLM モデルとバージョンの固定 → 将来の ADR
- 認証（単一ユーザーの MVP か、マルチテナントか） → 将来の ADR
- FastAPI のデプロイ先ターゲット（Render vs. Fly.io vs. Lambda） → 将来の ADR
