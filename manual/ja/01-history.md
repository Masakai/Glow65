# 第1章 6502 の歴史

[日本語](01-history.md) | [English](../en/01-history.md)

6502 は、1975年に発表された 8 ビットの CPU(中央処理装置、プログラムの命令を実行する部品)です。Apple II、Commodore PET 2001、ファミリーコンピュータの CPU は、6502 かその派生品です。

[1] のような番号は、章末の出典です。

## 1.1 1975年: 25 ドルの CPU

6502 は、アメリカの MOS Technology 社が 1975年9月に、サンフランシスコの見本市 WESCON で発表しました[3]。価格は 1 個 25 ドルです[3]。

設計したのは、Chuck Peddle と Bill Mensch らのチームです[2][3]。Peddle がチームを率い、Mensch がチップを設計したとされます[3]。

2人は、もとは Motorola の技術者で、会社は 6800 という CPU を売っていました。Peddle らが出した、もっと安い CPU の案は受け入れられませんでした。1974年8月、Peddle と数人の技術者は Motorola を離れ、MOS Technology に移りました[3][4]。

Motorola は 1975年11月に MOS Technology を訴えました。元社員が Motorola の技術を使ったという主張です。1976年の春に和解し、MOS Technology は 6800 とピン配置が同じ 6501 の販売をやめました[4]。6502 の販売は続きました。

## 1.2 6502 の仕様

6502 の仕様は、次のとおりです[1]。

| 項目 | 内容 |
|---|---|
| データの幅 | 8 ビット。1 回に 1 バイトを扱う |
| アドレス(メモリの番地)の幅 | 16 ビット。2 の 16 乗で、65,536 バイト(64KB)を指定できる |
| レジスタ | A(アキュムレータ)、X、Y、S(スタックポインタ)、P(ステータス)は 8 ビット。PC(プログラムカウンタ)は 16 ビット |
| ゼロページ | アドレスの上位が 00 の、先頭 256 バイト |
| クロック | 1 MHz(マニュアルのタイミング表の前提) |

1 MHz は、1 秒に 100 万回のクロックを刻むことです。のちに 2 MHz や 3 MHz で動く品種も出ました[3]。トランジスタの数は、約 3,500 個です[3][5]。

> **コラム: トランジスタの数え方**
>
> 6502 のトランジスタは、「約 3,500 個」と書かれることが多い数です。正確には、論理を作るトランジスタが 3,510 個です。このほかに、負荷として使われるトランジスタが 1,018 個あります。両方を合わせると 4,528 個です。数字の違いは、どこまでをトランジスタに数えるかの違いです[5]。

> **Glow65 で確かめられること**
>
> パネルの LED に、16 ビットのアドレスバス(A0 から A15)と 8 ビットのデータバス(D0 から D7)があります。PC、SP、A、X、Y、ステータスフラグの LED もあります。モニタの `D 0000 00FF` で、ゼロページ全体の内容を表示できます。`L 0300 0308` で、メモリの内容を命令として読めます。手順は[チュートリアル第1章](../../tutorial/README.ja.md)にあります。
>
> ![Glow65 のフロントパネルと端末。上にアドレスバス、データバス、PC、SP、A、X、Y、ステータスの LED、下に端末](../../docs/assets/frontpanel.png)
>
> 図 1-1 Glow65 のフロントパネル(BASIC の実行中)。上の段に、アドレスバスとデータバスの LED、PC、SP、A、X、Y、ステータスの LED が並ぶ

## 1.3 Apple I と Apple II

Apple I は 1976年7月に発売されました。CPU は 6502 で、クロックは約 1 MHz、価格は 666.66 ドルです[6]。

Apple II は 1977年6月10日に出荷が始まりました[7]。CPU は 6502 で、クロックは 1.023 MHz です[7]。発売時の価格は、RAM 4KB の構成で 1,298 ドル、最大 48KB の構成で 2,638 ドルでした[7]。

Apple II は、映像を NTSC のコンポジット信号で出力します。文字は 40 桁 24 行です。キーボードは大文字だけで、音は 1 ビットのスピーカーを切り替えて出します。カセットテープに保存できます。ROM(電源を切っても消えない記憶)には、Integer BASIC と、機械語モニタが入っています[8]。

> **コラム: 1.023 MHz という半端なクロック**
>
> Apple II のクロックは、1 MHz ちょうどではありません。NTSC のテレビ信号には、色を表す約 3.579545 MHz の信号があります。Apple II のクロックは、その 2/7 にあたる値です。正確には 1.022727 MHz で、これを丸めて 1.023 MHz と書きます。映像回路と共通の基準から作られた値です[6]。

## 1.4 Commodore PET 2001

PET 2001 は、Commodore 社のコンピュータです。CPU は 6502、クロックは 1 MHz、価格は 795 ドルでした[9]。

「いつ発売されたか」は、基準によって答えが変わります。

| 基準 | 時期 |
|---|---|
| 展示 | 1977年1月、Winter CES(家電見本市)で試作機を公開 |
| 出荷 | 1977年10月に最初の約 100 台。一般の購入者へは 1977年12月 |

Apple II の出荷(1977年6月)と比べると、展示は PET が先、出荷は Apple II が先です[7][9]。

PET は、画面とキーボード、カセットテープ装置が本体に一体になっています。画面は 40 桁 25 行の白黒表示です。音は、小さなブザーが付くモデルと、付かないモデルがありました。ROM には、BASIC と、基本的な入出力を担当する KERNAL、文字の形が入っています[9]。

## 1.5 ファミリーコンピュータ

任天堂のファミリーコンピュータ(ファミコン)は、1983年に発売されました[12]。発売日は 7月15日、価格は 14,800 円です[10]。CPU はリコー製の RP2A03 です。6502 と互換のコアに、サウンドを出す回路などを一緒に入れたチップです[10][11]。

リコーの技術者(高橋豊文氏)のインタビューでは、2A03 は「6502 の CPU コアとサウンドが入っているチップ」と説明されています[14]。CPU コアは別のグループが作ったもので、高橋氏はサウンドの回路を担当しました。リコーは、画像処理用のチップ 2C02 と合わせて、CPU を作って任天堂に納めていました[14]。

ファミコンの CPU には、6502 にある 10 進モード(数を 10 進数のまま計算する機能)がありません[15]。

CPU のクロックは、日本向けの NTSC 版で約 1.79 MHz です。PAL 方式の地域向けは、チップが RP2A07 になり、約 1.66 MHz です[15]。

> **Glow65 で確かめられること**
>
> Glow65 の CPU は、6502 の命令に加えて 10 進モードも動きます。Klaus Dormann の機能テストを、10 進モードを含めて通過しています(README の「テスト」の節)。ファミコンのチップにはない機能です。

> **コラム: ファミコンが 6502 を選んだ理由**
>
> ファミコンの開発に関わった上村雅之氏は、任天堂の公式インタビューで経緯を語っています。6502 を勧めたのは、半導体を作っていたリコーでした。当時の日本では、6502 はほとんど使われていない CPU でした。上村氏は、中身を理解できる人が少なく、他社に解析されにくいことが採用の理由だったと話しています。社内の技術者からは反対されたそうです[13]。

## 1.6 そのほかの 6502 系

6502 とその派生品を使った例です。

| 機種・チップ | 年 | 内容 |
|---|---|---|
| Atari 2600 | 1977年ごろ | 6507 を使用。約 1.19 MHz[16] |
| VIC-20 | 1980年(日本)/ 1981年(世界) | 6502、約 1.02 MHz(NTSC)[17] |
| BBC Micro | 1981年12月 | 6502A、2 MHz[18] |
| Commodore 64 | 1982年8月 | 6510、約 1.023 MHz(NTSC)[19] |
| 65C02 | 1983年 | 消費電力を下げた CMOS 版。WDC が開発[20] |
| 65816 | 1985年ごろ | 内部が 16 ビット、アドレスは 24 ビット(16MB)[21] |
| PC エンジン | 1987年10月30日 | Hudson Soft の HuC6280(65C02 を拡張)[22][23] |
| スーパーファミコン | 1990年11月21日 | Ricoh 5A22(65816 の派生)[24] |

CMOS は、消費電力が少ないトランジスタの作り方です。

> **コラム: アドレス端子を減らした 6507**
>
> Atari 2600 の CPU は、6502 の端子の一部を減らした 6507 です。6502 は 40 ピンですが、6507 は 28 ピンです。アドレス端子は 16 本から 13 本に減り、指定できるのは、2 の 13 乗で 8,192 バイト(8KB)までです。割り込みの端子もありません。端子を減らして、安く作るための CPU でした。チップの内部は 6502 と同じです[16][27]。

## 1.7 いま買える 6502

6502 の系列は、現在も販売されています。WDC(Western Design Center)は、公式ページで W65C02S を案内しています。パッケージは 40 ピン DIP、44 ピン PLCC、44 ピン QFP の 3 種類で、公式ページは Mouser や Jameco などの販売店を案内しています[25]。

6502 は、25 ドルで発表された安価な CPU です。トランジスタは約 3,500 個で[3][5]、MOS Technology はハードウェアマニュアルを出していました[1]。6507、6510、2A03、65C02、65816、HuC6280 など、用途に合わせた派生品も作られました。

## 1.8 Glow65 にあるもの・ないもの

Glow65 は、6502 の学習用に作った、架空のワンボードコンピュータのエミュレータです。3 つの実機との違いは、次の表のとおりです。

| 項目 | Apple II(1977年) | PET 2001(1977年) | ファミコン(1983年) | Glow65 |
|---|---|---|---|---|
| CPU | 6502、1.023 MHz[7] | 6502、1 MHz[9] | RP2A03(6502 互換、10 進モードなし)、約 1.79 MHz[15] | NMOS 6502(既定)。パネルの SPEED で 1 Hz から 1 MHz まで切り替え。CPU スイッチで 65C02 にも切り替え可 |
| メモリ | RAM 4KB 〜 48KB[7] | RAM 4KB または 8KB[9] | CPU 用 RAM 2KB、映像用 RAM 2KB[26] | RAM 32KB(`$0000-$7FFF`) |
| 画面表示 | NTSC コンポジット出力、40 桁 24 行[8] | 本体に一体の白黒画面、40 桁 25 行[9] | 画像処理チップ 2C02、256 x 240 ドット[26] | UART につないだ端末だけ。専用のグラフィック画面はなし。CPU の状態を見るフロントパネル(LED)あり |
| 入力 | キーボード(大文字のみ)[8] | 本体のキーボード[9] | ゲームパッド(本体に固定された 2 つ)[26] | 端末からのキーボード入力(UART 経由) |
| サウンド | 1 ビットのスピーカー[8] | 小さなブザーのみ(なしのモデルもあり)[9] | 5 チャンネル[26] | なし |
| 外部記憶 | カセットテープ[8] | 本体のカセット装置[9] | 本体にはなし[26] | なし。BASIC の `SAVE` と `LOAD` は使えない。ファイルの読み込み(File → Load Program)は、エミュレータが RAM へ直接書き込む機能 |
| ROM のソフト | Integer BASIC、機械語モニタ(8KB)[8] | BASIC、KERNAL、文字の形[9] | ゲームのカートリッジ(プログラム用チップは最大 32KB)[26] | モニタ(`$F000-$FFFF`)と Microsoft BASIC(`$C000-$EFFF`) |

Glow65 の BASIC は、Microsoft の 6502 用 BASIC(1978年の v1.1)[28]を、このボード向けに変換したものです。

Glow65 の目的は、実機の再現ではなく、CPU の動きを見ることです。実機の余分なダミーリードとダミーライトは再現していないため、バスの表示は実際の 6502 と少し異なります。

## 出典

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", 1976年1月版: https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt
2. IEEE Spectrum, "Chip Hall of Fame: MOS Technology 6502 Microprocessor": https://spectrum.ieee.org/chip-hall-of-fame-mos-technology-6502-microprocessor
3. Wikipedia, "MOS Technology 6502": https://en.wikipedia.org/wiki/MOS_Technology_6502
4. Wikipedia, "Motorola 6800": https://en.wikipedia.org/wiki/Motorola_6800
5. Ken Shirriff, "Intel x86 documentation has more pages than the 6502 has transistors": https://www.righto.com/2013/09/intel-x86-documentation-has-more-pages.html
6. Wikipedia, "Apple I": https://en.wikipedia.org/wiki/Apple_I
7. Wikipedia, "Apple II": https://en.wikipedia.org/wiki/Apple_II
8. Wikipedia, "Apple II (original)": https://en.wikipedia.org/wiki/Apple_II_(original)
9. Wikipedia, "Commodore PET": https://en.wikipedia.org/wiki/Commodore_PET
10. Wikipedia 日本語版, "ファミリーコンピュータ": https://ja.wikipedia.org/wiki/ファミリーコンピュータ
11. Wikipedia, "Ricoh 2A03": https://en.wikipedia.org/wiki/Ricoh_2A03
12. 任天堂 沿革: https://www.nintendo.co.jp/corporate/history/index.html
13. 任天堂「社長が訊く マリオ25周年 Vol.2」: https://www.nintendo.co.jp/n10/interview/mario25th/vol2/index2.html
14. 高橋豊文氏オーラルヒストリー(第2回前半)、一橋大学 IIR Working Paper WP#19-17、2019年: https://pubs.iir.hit-u.ac.jp/admin/ja/pdfs/file/2267
15. NESdev Wiki, "CPU": https://www.nesdev.org/wiki/CPU
16. Wikipedia, "Atari 2600": https://en.wikipedia.org/wiki/Atari_2600
17. Wikipedia, "VIC-20": https://en.wikipedia.org/wiki/VIC-20
18. Wikipedia, "BBC Micro": https://en.wikipedia.org/wiki/BBC_Micro
19. Wikipedia, "Commodore 64": https://en.wikipedia.org/wiki/Commodore_64
20. Wikipedia, "WDC 65C02": https://en.wikipedia.org/wiki/WDC_65C02
21. Wikipedia, "WDC 65C816": https://en.wikipedia.org/wiki/WDC_65C816
22. Wikipedia, "TurboGrafx-16": https://en.wikipedia.org/wiki/TurboGrafx-16
23. Wikipedia, "Hudson Soft HuC6280": https://en.wikipedia.org/wiki/Hudson_Soft_HuC6280
24. Wikipedia, "Super Nintendo Entertainment System": https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System
25. Western Design Center, "W65C02S": https://www.westerndesigncenter.com/wdc/w65c02s-chip.php
26. Wikipedia, "Nintendo Entertainment System": https://en.wikipedia.org/wiki/Nintendo_Entertainment_System
27. Wikipedia, "MOS Technology 6507": https://en.wikipedia.org/wiki/MOS_Technology_6507
28. Microsoft, "BASIC-M6502"(Microsoft BASIC for 6502 のソース): https://github.com/microsoft/BASIC-M6502

次の章: [2. コンピュータの基本 →](02-basics.md)
