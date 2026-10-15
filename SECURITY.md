# Security Policy

[日本語は下にあります](#セキュリティポリシー)

## Scope

Glow65 is a 6502 emulator for learning. It runs on your own machine, reads only the files you pass to it (a ROM, a program with `--load` or File → Load Program), and writes no files. It has no network code.

Things worth reporting:

- A crash or memory problem triggered by a crafted ROM or program file.
- A flaw in the build scripts under `Tools/` (for example, unsafe handling of file names).
- Secrets or personal information that should not be in the repository.

Program code that runs inside the emulated 6502 cannot reach the host. That is by design and is not a vulnerability.

## Reporting

Please do not open a public issue for a security problem. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on https://github.com/Masakai/Glow65 .

Include the version (commit), your macOS version, and steps to reproduce. This is a personal project, so a reply may take a few days.

## Supported versions

Only the latest commit on `main` and the latest release on [Releases](https://github.com/Masakai/Glow65/releases) are supported.

---

# セキュリティポリシー

## 対象

Glow65 は学習用の 6502 エミュレータです。自分のマシン上で動き、指定したファイル(ROM、`--load` や File → Load Program で渡すプログラム)だけを読み、ファイルは書き出しません。ネットワークの処理もありません。

報告してほしいもの:

- 細工した ROM やプログラムのファイルで起きるクラッシュやメモリの問題。
- `Tools/` のビルドスクリプトの欠陥(ファイル名の扱いなど)。
- リポジトリに入っていてはいけない秘密情報や個人情報。

エミュレートされた 6502 の中で動くプログラムは、ホストに影響できません。これは設計であり、脆弱性ではありません。

## 報告の方法

セキュリティの問題は、公開の Issue にしないでください。GitHub の非公開の報告機能を使ってください。
https://github.com/Masakai/Glow65 の **Security → Report a vulnerability** です。

バージョン(コミット)、macOS のバージョン、再現手順を書いてください。個人のプロジェクトなので、返信に数日かかることがあります。

## 対象のバージョン

`main` の最新コミットと、[Releases](https://github.com/Masakai/Glow65/releases) の最新のリリースが対象です。
