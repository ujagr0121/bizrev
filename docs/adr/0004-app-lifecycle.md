# 0004 — dev-server コントラクトを介したアプリのライフサイクル

- **ステータス:** 承認済み (Accepted)
- **日付:** 2026-05-16
- **決定者:** プロジェクトオーナー (project owner)

## 背景 (Context)

実際の機能をレビューする場合、通常は差分（diff）を読むことではなく、実行中のアプリをクリックして確認することを意味します。各タスクが開発サーバー起動のオーケストレーションを個別にハードコーディングすることなく、`scripts/bizrev review <id>` が適切な開発サーバーを適切なポートで起動し、その URL を報告できるようにしたいと考えています。

## 意思決定 (Decision)

実行可能なインターフェースを生成するすべてのタスクは、`task.md` のフロントマターで `app:` の下にその旨を宣言します：

```yaml
app:
  cmd: "make -C backend dev"   # フォアグラウンドコマンド
  port: 8001                   # 割り当てるポート
  health: "http://localhost:8001/healthz"   # 任意のヘルスチェック
```

これに基づき、`scripts/bizrev app up <id>` は以下の処理を行います：

1. タスクのワークツリーに `cd` します。
2. `task.md` のフロントマターから `app.cmd` / `app.port` を読み取ります。
3. `PORT=<port>` および渡されたすべての `--env` フラグをエクスポートします。
4. バックグラウンドで `app.cmd` を実行し、標準出力/標準エラー出力を `.bizrev/logs/<id>.log` にキャプチャし、プロセスIDを `.bizrev/pids/<id>.pid` に書き込みます。
5. `app.health` が設定されている場合、200 OK になるまでポーリングします（タイムアウト 60 秒）。
6. `Ready: http://localhost:<port>` または失敗ログのパスを出力します。

`scripts/bizrev app down <id>` は、プロセスID（pid）をキルして pid ファイルを削除します。
`scripts/bizrev app status` は、起動中のすべてのアプリをリスト表示します。

マルチプロセスを伴うタスク（FastAPI + Next.js など）の場合、慣例として**タスクごとに1つの Makefile ターゲット**を定義して両方を接続します。Makefile はワークツリー内に存在するため、Codex がそれを管理します。

## 結果 (Consequences)

- 実行可能なインターフェースを持たないタスク（例: 「Pydantic モデルの追加」）は `app.cmd: null` に設定し、レビュアーはアプリの起動ステップをスキップします。
- タスクごとにポートを割り当てることで、ポートの衝突を回避します — ADR-0002（ワークツリーの分離）および `scripts/lib/ports.sh` を参照してください。
- 将来的には、ハーネスのみを変更することで拡張可能です（タスクごとの Docker Compose など）。`app:` のコントラクト自体は維持されます。

## 代替案の検討 (Alternatives considered)

- **サービスごとの固定ポート。** 却下 — 2つのタスクが同時に実行されるとすぐに衝突するため。
- **プロセススーパーバイザー (Honcho/Procfile)。** MVP の段階では却下 — 現時点ではメリットがなく不要な依存関係が増えるため。タスクごとの Makefile ターゲットの慣例だけで十分です。

## 参照 (References)

- `scripts/app.sh`
- `tasks/_template/task.md`
