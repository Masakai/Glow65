# NOTICE / 第三者ソフトウェアの表示

Glow65 は、自作の部分と第三者の成果物を含む。全体が独自実装ではない。

## ライセンスの範囲

- 自作の部分(下記): リポジトリ直下の `LICENSE`(MIT License、Copyright (c) 2026 masanorisakai)。
- `ROM/basic/upstream/` 以下: Microsoft の MIT License(`ROM/basic/upstream/LICENSE`)。リポジトリ直下の `LICENSE` は適用されない。
- 上記から生成した `ROM/basic/build/` 以下: 原典の派生物であり、Microsoft の著作権表示と許諾文を伴う。

## 自作の部分

- `Sources/Core6502`: 6502 CPU コア
- `Sources/Glow65`: ボード(バス、UART、実行制御、パネル用の状態)
- `Sources/glow65-cli`, `Sources/Glow65App`: 実行ファイル(CLI、フロントパネル付きアプリ)
- `ROM/monitor.s`: モニタ ROM
- `Tools/convert_m6502.py`: BASIC の変換スクリプト

## 同梱している第三者のソフトウェア

### Microsoft BASIC for 6502 v1.1

- 場所: `ROM/basic/upstream/m6502.asm`、ライセンス文は `ROM/basic/upstream/LICENSE`
- 権利者: Copyright (c) Microsoft Corporation
- ライセンス: MIT License
- 入手元: https://github.com/microsoft/BASIC-M6502
- 用途: `Tools/convert_m6502.py` で ca65 用に変換し、`ROM/basic/build/basic.bin` をビルドする。
  変換結果と `basic.bin` を配布する場合も、上記の著作権表示と MIT の許諾文を同梱すること。
- BASIC の起動時に表示される「COPYRIGHT 1978 MICROSOFT」は、原典のメッセージである。
- 起動バナーの1行目(機種名)は、原典の「OSI 6502 BASIC VERSION 1.1」を「GLOW65 BASIC (MICROSOFT BASIC V1.1 FOR 6502)」に差し替えている(`Tools/convert_m6502.py` の `PATCHES`)。

## 同梱していないが、利用しているもの

- cc65(ca65/ld65): ROM のビルドに使うツール。zlib License。リポジトリには含めない。
- Klaus Dormann の 6502 機能テスト: CPU コアの検証に使う。GPLv3。
  `Tests/Fixtures/klaus/` に各自が取得して置く。リポジトリには含めない(`.gitignore` 対象)。
