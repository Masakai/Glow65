# 第1章 6502 の歴史

6502 は、1975年に発表された 8 ビットの CPU(中央処理装置、プログラムの命令を実行する部品)です。Apple II、Commodore PET 2001、ファミリーコンピュータの CPU は、6502 かその派生品です。この章では、6502 がどのように登場し、何に使われたかを順にたどります。最後に、Glow65 が当時のコンピュータとどこが同じで、どこが違うかを表にします。

[1] のような番号は、章末の出典です。Wikipedia など二次資料だけで確認した数字には、出典の一覧に「二次」と書いてあります。

## 1.1 1975年: 25 ドルの CPU

6502 は、アメリカの MOS Technology 社が 1975年9月に、サンフランシスコの見本市 WESCON で発表しました[2][3]。価格は 1 個 25 ドルです[3]。同じ時期の Intel 8080 と Motorola 6800 は、200 ドル近くしたと紹介されています[2]。比較価格は資料によって差があるため、倍率は示しません。

設計したのは、Chuck Peddle と Bill Mensch らのチームです[2][3]。Peddle がチームを率い、Mensch がチップを設計したとされます[3]。

2人は、もとは Motorola の技術者で、会社は 6800 という CPU を売っていました。Peddle らが出した、もっと安い CPU の案は受け入れられませんでした。1974年8月、Peddle と数人の技術者は Motorola を離れ、MOS Technology に移りました[3][4]。

Motorola は 1975年11月に MOS Technology を訴えました。元社員が Motorola の技術を使ったという主張です。1976年4月に和解し、MOS Technology は 6800 とピン配置が同じ 6501 の販売をやめました[4]。6502 の販売は続きました。

見本市の会場ではチップを売れず、近くのホテルの部屋で売ったと伝えられています[5]。Peddle 本人の回想として紹介されている話で、一次資料は確認できていません。

## 1.2 6502 は何が小さく、何が安いのか

6502 の仕様のうち、MOS 社の 1976年1月版マニュアルで確認できるものは次のとおりです[1]。

- データの幅は 8 ビットです。1 回に 1 バイトを扱います。
- アドレス(メモリの番地)の幅は 16 ビットです。2 の 16 乗で、65,536 バイト(64KB)を指定できます。
- 主なレジスタは、A(アキュムレータ)、X、Y、S(スタックポインタ)、PC(プログラムカウンタ)、P(ステータス)です。A、X、Y、S、P は 8 ビット、PC は 16 ビットです。
- アドレスの上位が 00 の先頭 256 バイトを、ゼロページと呼びます。

マニュアルのタイミング表は 1 MHz のクロックを前提にしています[1]。1 MHz は、1 秒に 100 万回のクロックを刻むことです。のちに 2 MHz や 3 MHz で動く品種も出ました[3]。

トランジスタの数は、約 3,500 個です。ただし数え方で変わります。論理を作るトランジスタだけを数えると 3,510 個、負荷として使われるトランジスタを加えると 4,528 個になります[6]。

安く作れた理由として、Mensch は命令の種類が少ないことと、製造の歩留まりが良いことを挙げたと紹介されています[2]。

> **Glow65 で確かめられること**
> パネルの LED に、16 ビットのアドレスバス(A0 から A15)と 8 ビットのデータバス(D0 から D7)があります。PC、SP、A、X、Y、ステータスフラグの LED もあります。モニタの `D 0000 00FF` で、ゼロページ全体の内容を表示できます。`L 0300 0308` で、メモリの内容を命令として読めます。手順は[チュートリアル第1章](../../tutorial/README.ja.md)にあります。

## 1.3 Apple I と Apple II

Apple I は 1976年7月に発売されました。CPU は 6502 で、クロックは約 1 MHz、価格は 666.66 ドルです。生産数は約 200 台とされます[7]。

Apple II は 1977年6月10日に出荷が始まりました[8]。CPU は 6502 で、クロックは 1.023 MHz です[8]。発売時の価格は、RAM 4KB の構成で 1,298 ドル、最大 48KB の構成で 2,638 ドルでした[8]。

Apple II は、映像を NTSC のコンポジット信号で出力します。文字は 40 桁 24 行です。キーボードは大文字だけで、音は 1 ビットのスピーカーを切り替えて出します。カセットテープに保存できます。ROM(電源を切っても消えない記憶)には、Integer BASIC と、機械語モニタが入っています[9]。

1.023 MHz は、NTSC のテレビ信号の周波数から決まった値です(正確には 1.022727 MHz)[8]。Apple 自身の資料では確認できていません。

## 1.4 Commodore PET 2001

PET 2001 は、Commodore 社のコンピュータです。CPU は 6502、クロックは 1 MHz、価格は 795 ドルでした[10]。

- 展示: 1977年1月の Winter CES(家電見本市)[10]。
- 出荷: 1977年10月(最初の約 100 台)。一般の購入者へは 1977年12月[10]。

PET は、画面とキーボード、カセットテープ装置が本体に一体になっています[10]。画面は 40 桁 25 行の白黒表示です[10]。音は、小さなブザーが付くモデルと、付かないモデルがありました[10]。ROM には、BASIC と、基本的な入出力を担当する KERNAL、文字の形が入っています[10]。BASIC は、Microsoft の 6502 用 BASIC を基にしたとされます[10]。ROM の版は確認できていません。

## 1.5 ファミリーコンピュータ

任天堂のファミリーコンピュータ(ファミコン)は、1983年に発売されました[13]。発売日は 7月15日、価格は 14,800 円です[11]。CPU はリコー製の RP2A03 です。6502 と互換のコアに、サウンドを出す回路などを一緒に入れたチップです[11][12]。

6502 を選んだ経緯は、任天堂の公式インタビューで語られています[14]。リコーが 6502 を提案しました。当時の日本では普及していない CPU でした。上村雅之氏は、解析されにくいことが採用の理由だったと話しています[14]。同じインタビューでは、社内の技術者に反対されたことも語られています。

リコーの元技術者(高橋豊文氏)のインタビューでは、2A03 は「6502 の CPU コアとサウンドが入っているチップ」と説明されています[15]。CPU コアは別のグループが作ったもので、高橋氏はサウンドの回路を担当しました。リコーは、画像処理用のチップ 2C02 と合わせて、CPU を作って任天堂に納めていました[15]。

ファミコンの CPU には、6502 にある 10 進モード(数を 10 進数のまま計算する機能)がありません[16]。なぜ無くしたのかは、公式の資料では確認できていません。「特許を避けるため」という推測を書いた資料はありますが、確かな根拠は見つかっていません。

CPU のクロックは、日本向けの NTSC 版で約 1.79 MHz です。PAL 方式の地域向けは、チップが RP2A07 になり、約 1.66 MHz です[16]。

> **Glow65 で確かめられること**
> Glow65 の CPU は、6502 の命令に加えて 10 進モードも動きます。Klaus Dormann の機能テストを、10 進モードを含めて通過しています(README の「テスト」の節)。ファミコンのチップにはない機能です。

## 1.6 そのほかの 6502 系

次の表は、6502 とその派生品を使った例です。年と数値は二次資料によります。

| 機種・チップ | 年 | 内容 |
|---|---|---|
| Atari 2600 | 1977年ごろ | 6502 のアドレス端子を 13 本に減らした 6507 を使用。約 1.19 MHz[27] |
| VIC-20 | 1980年(日本)/ 1981年(世界) | 6502、約 1.02 MHz(NTSC)[18] |
| BBC Micro | 1981年12月 | 6502A、2 MHz[19] |
| Commodore 64 | 1982年8月 | 6510、約 1.023 MHz(NTSC)[20] |
| 65C02 | 1983年 | 消費電力を下げた CMOS 版。WDC が開発[21] |
| 65816 | 1985年ごろ | 内部が 16 ビット、アドレスは 24 ビット(16MB)[22] |
| PC エンジン | 1987年10月30日 | Hudson Soft の HuC6280(65C02 を拡張)[23][24] |
| スーパーファミコン | 1990年11月21日 | Ricoh 5A22(65816 の派生)[25] |

65816 の年は、資料により 1984 年と 1985 年に分かれるため「1985年ごろ」としました。Apple IIGS の発売年、Atari 8 ビットの年代、日本国内の 6502 搭載パソコンの機種は、確認できていません。

CMOS は、消費電力が少ないトランジスタの作り方です。1 MHz で動かしたときの消費電力は、初代 6502 の約 450 mW に対し、65C02 は約 20 mW とされます[21]。

## 1.7 いま買える 6502

6502 の系列は、現在も販売されています。WDC(Western Design Center)は、公式ページで W65C02S を案内しています。パッケージは 40 ピン DIP、44 ピン PLCC、44 ピン QFP の 3 種類で、Mouser や Jameco などで買えると書かれています[26]。販売店の在庫は確認していません。

長く使われた背景として、この章で確認できた事実は次のとおりです。

- 価格が安かった(25 ドルで発表)[3]。
- 構造が小さい(トランジスタ約 3,500 個、命令の種類が少ない)[2][6]。
- メーカーの公式マニュアルが公開されていた[1]。
- 用途に合わせた派生品が多い(6507、6510、2A03、65C02、65816、HuC6280)。

これらを理由と断定する資料は確認できていません。

## 1.8 Glow65 にあるもの・ないもの

Glow65 は、6502 の学習用に作った、架空のワンボードコンピュータのエミュレータです。3 つの実機との違いは、次の表のとおりです。

| 項目 | Apple II(1977年) | PET 2001(1977年) | ファミコン(1983年) | Glow65 |
|---|---|---|---|---|
| CPU | 6502、1.023 MHz[8] | 6502、1 MHz[10] | RP2A03(6502 互換、10 進モードなし)、約 1.79 MHz[16] | NMOS 6502(既定)。パネルの SPEED で 1 Hz から 1 MHz まで切り替え。CPU スイッチで 65C02 にも切り替え可 |
| メモリ | RAM 4KB 〜 48KB[8] | RAM 4KB または 8KB[10] | CPU 用 RAM 2KB、映像用 RAM 2KB[17] | RAM 32KB(`$0000-$7FFF`) |
| 画面表示 | NTSC コンポジット出力、40 桁 24 行[9] | 本体に一体の白黒画面、40 桁 25 行[10] | 画像処理チップ 2C02、256 x 240 ドット[17] | UART につないだ端末だけ。専用のグラフィック画面はなし。CPU の状態を見るフロントパネル(LED)あり |
| 入力 | キーボード(大文字のみ)[9] | 本体のキーボード[10] | ゲームパッド(本体に固定された 2 つ)[17] | 端末からのキーボード入力(UART 経由) |
| サウンド | 1 ビットのスピーカー[9] | 小さなブザーのみ(なしのモデルもあり)[10] | 5 チャンネル[17] | なし |
| 外部記憶 | カセットテープ[9] | 本体のカセット装置[10] | 本体にはなし[17] | なし。BASIC の `SAVE` と `LOAD` は使えない。ファイルの読み込み(File → Load Program)は、エミュレータが RAM へ直接書き込む機能 |
| ROM のソフト | Integer BASIC、機械語モニタ(8KB)[9] | BASIC、KERNAL、文字の形[10] | ゲームのカートリッジ(プログラム用チップは最大 32KB のものが多い)[17] | モニタ(`$F000-$FFFF`)と Microsoft BASIC(`$C000-$EFFF`) |

Glow65 側の欄は `README.ja.md` の記述に合わせています。実機の欄の数字は二次資料によります。

Glow65 の BASIC は、Microsoft の 6502 用 BASIC(1978年の v1.1)を、このボード向けに変換したものです。PET の BASIC は同じ Microsoft の BASIC を基にしたとされますが、ROM の中身は同一ではありません。PET 向けのプログラムが、そのまま動くとは限りません。

Glow65 の目的は、実機の再現ではなく、CPU の動きを見ることです。実機の余分なダミーリードとダミーライトは再現していないため、バスの表示は実際の 6502 と少し異なります。

## 出典

調査日は 2026年10月12日です。「一次」は当事者やメーカーの資料、「準一次」は当事者の証言を収めた資料、「二次」は解説記事や Wikipedia です。

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", 1976年1月版(一次。テキスト版): https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt
2. IEEE Spectrum, "Chip Hall of Fame: MOS Technology 6502 Microprocessor"(二次): https://spectrum.ieee.org/chip-hall-of-fame-mos-technology-6502-microprocessor
3. Wikipedia, "MOS Technology 6502"(二次): https://en.wikipedia.org/wiki/MOS_Technology_6502
4. Wikipedia, "Motorola 6800"(二次): https://en.wikipedia.org/wiki/Motorola_6800
5. All About Circuits, "The MOS 6502: How a $25 Chip Sparked a Computer Revolution"(二次): https://www.allaboutcircuits.com/news/the-mos-6502-how-a-25-chip-sparked-a-computer-revolution
6. Ken Shirriff, "Intel x86 documentation has more pages than the 6502 has transistors"(二次、Visual 6502 の解析に基づく): https://www.righto.com/2013/09/intel-x86-documentation-has-more-pages.html
7. Wikipedia, "Apple I"(二次): https://en.wikipedia.org/wiki/Apple_I
8. Wikipedia, "Apple II"(二次。Computer History Museum などを引用): https://en.wikipedia.org/wiki/Apple_II
9. Wikipedia, "Apple II (original)"(二次): https://en.wikipedia.org/wiki/Apple_II_(original)
10. Wikipedia, "Commodore PET"(二次): https://en.wikipedia.org/wiki/Commodore_PET
11. Wikipedia 日本語版, "ファミリーコンピュータ"(二次): https://ja.wikipedia.org/wiki/ファミリーコンピュータ
12. Wikipedia, "Ricoh 2A03"(二次): https://en.wikipedia.org/wiki/Ricoh_2A03
13. 任天堂 公式沿革(1983年にファミリーコンピュータを発売と記載、一次): https://www.nintendo.co.jp/corporate/history/index.html
14. 任天堂「社長が訊く マリオ25周年 Vol.2」(一次): https://www.nintendo.co.jp/n10/interview/mario25th/vol2/index2.html
15. 高橋豊文氏オーラルヒストリー(第2回前半)、一橋大学 IIR Working Paper WP#19-17、2019年(準一次): https://pubs.iir.hit-u.ac.jp/admin/ja/pdfs/file/2267
16. NESdev Wiki, "CPU"(二次): https://www.nesdev.org/wiki/CPU
17. Wikipedia, "Nintendo Entertainment System"(二次): https://en.wikipedia.org/wiki/Nintendo_Entertainment_System
18. Wikipedia, "VIC-20"(二次): https://en.wikipedia.org/wiki/VIC-20
19. Wikipedia, "BBC Micro"(二次): https://en.wikipedia.org/wiki/BBC_Micro
20. Wikipedia, "Commodore 64"(二次): https://en.wikipedia.org/wiki/Commodore_64
21. Wikipedia, "WDC 65C02"(二次): https://en.wikipedia.org/wiki/WDC_65C02
22. Wikipedia, "WDC 65C816"(二次): https://en.wikipedia.org/wiki/WDC_65C816
23. Wikipedia, "TurboGrafx-16"(二次): https://en.wikipedia.org/wiki/TurboGrafx-16
24. Wikipedia, "Hudson Soft HuC6280"(二次): https://en.wikipedia.org/wiki/Hudson_Soft_HuC6280
25. Wikipedia, "Super Nintendo Entertainment System"(二次): https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System
26. Western Design Center, "W65C02S"(一次): https://www.westerndesigncenter.com/wdc/w65c02s-chip.php
27. Wikipedia, "Atari 2600"(二次): https://en.wikipedia.org/wiki/Atari_2600
