# 開発ワークフロー

機能が実際にエンドツーエンドでどのように構築されるかを示します。まず一読し、ハーネスを初めて実行する間は開いたままにしてください。

## どこで何を実行するか

ハーネスは、Claude Code (および Codex) が起動されたマシン上で動作します。Web 版 of Claude Code では `codex exec` を実行できません。Anthropic が管理するクラウドセッションには、デフォルトで Codex CLI がインストールされておらず、公式の `openai-codex` プラグインはクライアントサイドでのインストールが必要であり、デフォルトのネットワーク許可リストには OpenAI API が含まれていません。そのため、ループを以下のように分割します：

| フェーズ | 実行場所 | 理由 |
|---|---|---|
| `/plan`, `/adr` | Web 版の Claude | 純粋な設計とドキュメント作成作業。Codex は不要。 |
| レビュー差分の読み込み | Web 版の Claude | GitHub MCP 経由でプッシュされたブランチを読み込みます。 |
| `/implement <id>` | **ローカルの Claude Code** | `codex exec` と実際のファイルシステム上のワークツリーが必要です。 |
| `/parallel <ids…>` | **ローカルの Claude Code** | 同上。 |
| `/review <id>` (アプリ起動) | **ローカルの Claude Code** | ポートのバインドと開発サーバーの制御が必要です。 |
| `/integrate <id>` | どちらでも | Git 操作のみ。 |

実際の運用：ワークツリーを操作するタスクでは、ターミナル側のローカル Claude Code でこのリポジトリを開き、それより上流および下流の作業には Web 版を使用します。どちらの側もバージョン管理された `tasks/` ディレクトリを参照するため、Web で作成されたプランはローカルですぐに実行可能です。

**ローカル**側の前提条件：`README.md` のクイックスタートを参照してください。`./scripts/bizrev doctor` を実行して、Codex CLI が PATH に通っているか確認してください。

## 要約 (TL;DR)

```
アイデア ──► Claude /plan ──► tasks/<id>/ ──► /implement ──► ワークツリー+Codex
                                                   │
                                                   ▼
                                        /review (アプリ起動)
                                                   │
                                   ┌────── OK ─────┴───── NG ──────┐
                                   ▼                               ▼
                             /integrate                       タスクのやり直し
```

## 1. 計画 (Plan)

```
ユーザー: "競合分析のスペシャリストを追加して。"
Claude:  /plan competitor-analysis
```

`planner` サブエージェントは、リクエストを `tasks/` 以下の1つ以上のタスクディレクトリに分解します。それぞれに数値 ID (`NNNN-slug`)、概要、受け入れチェックリスト、および所有するファイルを宣言する `paths:` が割り当てられます。計画自体は、メインブランチにコミットされた1行の概要で終了します：

```
chore(plan): add tasks 0007–0009 (competitor agent)
```

2つのタスクが独立している場合（`paths:` が重複しない場合）、計画はそれらを並行実行可能（parallel-safe）としてマークします。

## 2. 実装 (Implement)

```
Claude:  /implement 0007-competitor-agent
```

これは `scripts/bizrev implement 0007-competitor-agent` を呼び出し、以下の処理を行います：

1. `main` から分岐したブランチ `task/0007-competitor-agent` 上の `../bizrev-worktrees/0007-competitor-agent/` にワークツリーが存在することを確認します。
2. `tasks/0007-competitor-agent/task.md`、`acceptance.md`、リポジトリの `AGENTS.md`、および依存するタスクの概要から Codex プロンプトを構築します。
3. `codex exec --cd <worktree> <prompt>` を実行し、出力を `.bizrev/logs/0007-competitor-agent.log` にストリーミングします。
4. 終了時に、未ステージの Codex 変更を `chore(codex): wip` としてコミットし、変更が失われないようにした上で、次のステップのヒントを出力します。

並行作業の場合：

```
Claude:  /parallel 0007 0008 0009
```

これは3つの `/implement` を実行するのと同等ですが、並行して起動されます。

## 3. レビュー (Review)

```
ユーザー: "0007をレビューする準備はできた？"
Claude:  /review 0007-competitor-agent
```

`reviewer` サブエージェントは：

1. `scripts/bizrev review 0007-competitor-agent` を実行します。これは：
   a. `acceptance.md` から受け入れコマンドを実行します。
   b. `app.cmd` が設定されている場合、`scripts/bizrev app up` を介して開発サーバーを起動します。
   c. URL を出力して待機します。
2. `paths:` への準拠、追加されたテスト、リスク、および Codex が出力した `NOTES:` ブロックに焦点を当てて、`main` に対する差分を要約します。
3. 緑色のチェックマーク、アプリの URL、およびユーザーの判断が必要な質問を添えて、あなたに引き渡します。

差分が `paths:` の範囲外に及んでいる場合、レビューは即座に失敗します。これは Codex のバグではなく、プランナーのバグです。

## 4. 統合 (Integrate)

```
ユーザー: "マージして。"
Claude:  /integrate 0007-competitor-agent
```

`integrator` サブエージェントは、`task/0007-competitor-agent` を `main` にファストフォワードまたはマージ（デフォルトはスクワッシュ）し、プッシュして、ワークツリーと実行中のアプリをクリーンアップします。タスクディレクトリは git 履歴に残ります。`tasks/<id>/task.md` の `status` は `merged` に更新されます。

## 5. 決定事項の記録 (Capture decisions)

計画/実装/レビュー中に自明ではない決定事項が生じた場合：

```
Claude:  /adr "route GPT-4o-mini for competitor extraction, Sonnet for review"
```

`adr-writer` エージェントは、ステータスを `Accepted` とした新しい連番の ADR を作成し、タスクおよび関連する場合は `docs/architecture/overview.md` からリンクします。

## 日常コマンド

```bash
scripts/bizrev doctor              # 前提条件のチェック
scripts/bizrev task new <slug>     # tasks/<NNNN-slug>/ の雛形作成
scripts/bizrev implement <id>      # ワークツリー内でCodexに処理を委譲
scripts/bizrev parallel <id> ...   # 複数のタスクを同時に実行
scripts/bizrev review <id>         # 受け入れ確認の実行 + アプリの起動
scripts/bizrev app up <id>         # アプリのみ起動
scripts/bizrev app down <id>       # アプリの停止
scripts/bizrev app status          # アプリの状態確認
scripts/bizrev worktree list       # ワークツリー一覧
scripts/bizrev worktree rm <id>    # ワークツリーの削除
scripts/bizrev status              # クロスタスクダッシュボードの表示
```

Claude Code 内部では、スラッシュコマンド (`/plan`, `/implement` など) を優先して使用してください。これらは適切なサブエージェントとコンテキストプロンプトを自動的に適用します。

## 配置されるファイルとディレクトリ

- `tasks/<id>/` — タスク概要。バージョン管理対象。
- `../bizrev-worktrees/<id>/` — 作業ツリー。このリポジトリ内ではバージョン管理対象外（同じ `.git` の別作業コピー）。
- `.bizrev/` — ランタイム状態（PID、ログ、ポート割り当て）。Git 管理対象外（gitignore）。
- `docs/adr/` — 決定事項。不変の履歴。
