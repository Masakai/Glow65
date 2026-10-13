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
- `ROM/game65g/`: GAME 言語のインタプリタ GAME65G(下記「GAME 言語について」)
- `Tools/convert_m6502.py`: BASIC の変換スクリプト

## GAME 言語について

- GAME 言語は、大西博氏が月刊アスキー(1978 年)で発表した言語である。
- GAME65G は、公開された言語の仕様(月刊アスキーの特集「GAME65 & GAME-MZ」の記事「超CPU-GAMEとは?」の表1と本文、同特集の GAME65 の記事にある演算子の説明)をもとに、このプロジェクトのために一から書いた。コードは MIT License。
- 鈴木仁志氏の GAME65(同特集、PET 用。掲載は 1979 年 10 月号と、はせりん氏の掲載記事一覧にある)とは別物である。GAME65 のコード(ダンプリスト)や内部構成は使っていない。ほかの GAME 処理系のソースコードも参照していない。
- 仕様の出典と、出典にない部分を独自に決めた点は `documents/designs/2026-10-13-game65g.md` にある。

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
