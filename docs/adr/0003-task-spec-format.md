# 0003 — タスク仕様のフォーマット

- **ステータス:** 承認済み (Accepted)
- **日付:** 2026-05-16
- **決定者:** プロジェクトオーナー (project owner)

## 背景 (Context)

Codexは自己完結型の仕様概要（ブリーフ）を必要とします。この仕様概要は、タスクが難航した際に人間が監査する対象でもあります。Claudeが数分で記述でき、ハーネス（メタデータ抽出のため）が解析可能で、チャットによるやり取りなしで実装を完了できるほど十分に完全である必要があります。

## 意思決定 (Decision)

タスクは、以下を含む `tasks/<task-id>/` ディレクトリとして構成されます：

- `task.md` (**必須**) — タスクの概要。フロントマターは機械可読なYAML、ボディは人間向けのMarkdownで記述します。スキーマは以下の通りです：

  ```yaml
  ---
  id: 0007-competitor-agent
  title: Implement the competitor-analysis specialist
  status: ready          # ready | in-progress | review | merged | abandoned
  depends_on: [0001-ideabrief-schema]
  paths:                 # このタスクで変更が許可されるファイル
    - backend/app/agents/competitor/**
    - backend/tests/agents/test_competitor*.py
  app:
    cmd: null            # または "make -C backend dev" など
    port: null           # または 8001
    health: null         # または "http://localhost:8001/health"
  ---
  ```

  ボディの構成セクション：
  - **Why** — 仕様書やADRへのリンク、モチベーションに関する1段落の説明。
  - **What** — 具体的な成果物（ファイル、関数、エンドポイント）。
  - **Notes** — 既知のはまりどころ、他のワークツリー内の関連コードへのリンク。

- `acceptance.md` (**必須**) — 実行可能なコマンドのチェックリスト。
  各項目は `- [ ] 説明 — \`シェルコマンド\`` の形式で記述します。レビュアーはこれを作業ツリー内で実行し、すべてがパスすることを確認します。

- `codex.log` (自動生成、タスクディレクトリ内でgit管理対象外にすることを推奨) — ハーネスが `codex exec` を実行するたびに追加されます。

`task-id` は `NNNN-kebab-slug` 形式とし、NNNN はゼロ埋めされた連番です。ハーネスは `task new` の実行時に次の番号を自動で割り当てます。

## 結果 (Consequences)

- `paths:` の変更制限を強制できます — レビュアーは `git diff --name-only` を実行して、タスクが許可された範囲外のファイルを変更していないかを確認し、逸脱している場合は却下できます。これにより、並行作業の安全性が確保されます。
- タスクを理解するために必要なすべての情報がディレクトリ内にまとまっているため、数ヶ月後でもタスク単位でのレビューが可能です。
- 多少の記述量が増えることは許容します。些細なタスクであれば5行程度の `task.md` でも問題ありません — このフォーマットは規模の大小に応じて柔軟に対応できます。

## 代替案の検討 (Alternatives considered)

- **GitHub Issuesのみ。** 却下 — トラッキングには適していますが、コードに隣接すべきアーティファクトであるにもかかわらず、人間をGit以外の場所での作業に巻き込んでしまうため。
- **PRの説明文にインライン化する。** 却下 — 実装前のレビューができなくなり、かつPRが存在する前にPRの説明文に依存することはできないため。

## 参照 (References)

- `tasks/_template/`
- `scripts/bizrev task new`
