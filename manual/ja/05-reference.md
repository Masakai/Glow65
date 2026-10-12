# 第5章 命令リファレンス

[← 4. アドレッシングモード](04-addressing.md)

この章は、6502 の公式の 151 オペコード(56 の命令)を、機能別にまとめたリファレンスです。命令ごとに、動作、影響するフラグ、オペコード表、使い方の例を載せています。命令は、分類ごとのファイルに分けています。

## 読み方

### 命令の書式

| 書き方 | 意味 |
|---|---|
| `#$nn` | 値そのもの(イミディエイト)。`nn` は 1 バイト |
| `$nn` | ゼロページの番地。`nn` は 1 バイト |
| `$nnnn` | 2 バイトの番地。機械語では、下位バイトが先に並ぶ |
| `($nn,X)`、`($nn),Y`、`($nnnn)` | インダイレクトの 3 つの形 |
| `A` | アキュムレータ(A レジスタ自身) |
| `label` | 分岐先の番地。アセンブラが、距離に直す |

アドレッシングモードは、第4章で説明しています。

### フラグ表の記号

各命令の「影響するフラグ」の表は、N、V、D、I、Z、C の 6 つを、次の記号で示します。B(ブレーク)とビット 5 は、P の中に実体がないので、表にありません。

| 記号 | 意味 |
|---|---|
| ○ | 結果に応じて 0 か 1 になる |
| - | 変わらない |
| 0、1 | いつも 0、いつも 1 になる |
| M7、M6 | メモリの値のビット 7、ビット 6 が、そのまま入る |
| 復元 | スタックから取り出した値で置き換わる |

### オペコード表の見方

「オペコード表」の列は、次のとおりです。

| 列 | 意味 |
|---|---|
| アドレッシングモード | その命令が持つモード |
| 書き方 | アセンブリでの書き方 |
| オペコード | 機械語の最初の 1 バイト(16進数) |
| バイト数 | 命令全体の長さ |
| サイクル数 | 実行にかかるサイクル数 |

サイクル数の記号は、次のとおりです。

| 表記 | 意味 |
|---|---|
| `4` | いつも 4 サイクル |
| `4+` | 読み出し命令で、足した結果が別のページになると 1 サイクル増える(5 サイクル) |
| `2 (+1,+2)` | 分岐。条件が成り立たないとき 2、成り立つと 3、成り立って別のページへ飛ぶと 4 |

ページをまたぐときの 1 サイクルの増加と、分岐のサイクル数は、MOS 社のマニュアル[1]の表にあります。

### Glow65 のサイクルとバスアクセス

実機の 6502 は、アドレスの計算のときなどに、結果に使われない余分な読み出し(ダミーリード)と、書き込み(ダミーライト)を行います。Glow65 は、これを再現しません。サイクル数は実機と同じ値を数えますが、パネルや図に現れるバスアクセスの回数は、実機より少ない場合があります。たとえば `CLC` は、サイクル数は 2 で、バスアクセスは 1 回です。

## 分類

| 分類 | 命令 |
|---|---|
| [5.1 ロードとストア](05-1-load-store.md) | LDA、LDX、LDY、STA、STX、STY |
| [5.2 レジスタ間の転送](05-2-transfer.md) | TAX、TAY、TXA、TYA、TSX、TXS |
| [5.3 算術演算と比較](05-3-arithmetic.md) | ADC、SBC、CMP、CPX、CPY、INC、DEC、INX、INY、DEX、DEY |
| [5.4 論理演算とシフト](05-4-logic-shift.md) | AND、ORA、EOR、BIT、ASL、LSR、ROL、ROR |
| [5.5 分岐とジャンプ](05-5-branch-jump.md) | BCC、BCS、BEQ、BNE、BMI、BPL、BVC、BVS、JMP、JSR、RTS、BRK、RTI |
| [5.6 スタックとフラグ操作](05-6-stack-flags.md) | PHA、PLA、PHP、PLP、CLC、SEC、CLI、SEI、CLD、SED、CLV、NOP |

## 全 56 命令の一覧

<!-- list -->
| ニーモニック | 名前 | 機能 | 影響するフラグ |
|---|---|---|---|
| [LDA](05-1-load-store.md#lda) | Load Accumulator(ロード A) | メモリの値を A に入れる | N Z |
| [LDX](05-1-load-store.md#ldx) | Load X Register(ロード X) | メモリの値を X に入れる | N Z |
| [LDY](05-1-load-store.md#ldy) | Load Y Register(ロード Y) | メモリの値を Y に入れる | N Z |
| [STA](05-1-load-store.md#sta) | Store Accumulator(ストア A) | A の値をメモリに書く | なし |
| [STX](05-1-load-store.md#stx) | Store X Register(ストア X) | X の値をメモリに書く | なし |
| [STY](05-1-load-store.md#sty) | Store Y Register(ストア Y) | Y の値をメモリに書く | なし |
| [TAX](05-2-transfer.md#tax) | Transfer A to X(A を X へ転送) | A の値を X にコピーする | N Z |
| [TAY](05-2-transfer.md#tay) | Transfer A to Y(A を Y へ転送) | A の値を Y にコピーする | N Z |
| [TXA](05-2-transfer.md#txa) | Transfer X to A(X を A へ転送) | X の値を A にコピーする | N Z |
| [TYA](05-2-transfer.md#tya) | Transfer Y to A(Y を A へ転送) | Y の値を A にコピーする | N Z |
| [TSX](05-2-transfer.md#tsx) | Transfer Stack Pointer to X(SP を X へ転送) | SP の値を X にコピーする | N Z |
| [TXS](05-2-transfer.md#txs) | Transfer X to Stack Pointer(X を SP へ転送) | X の値を SP にコピーする | なし |
| [ADC](05-3-arithmetic.md#adc) | Add with Carry(キャリー付き加算) | A にメモリの値とキャリーを足す | N V Z C |
| [SBC](05-3-arithmetic.md#sbc) | Subtract with Carry(キャリー付き減算) | A からメモリの値と借りを引く | N V Z C |
| [CMP](05-3-arithmetic.md#cmp) | Compare Accumulator(A の比較) | A とメモリの値を比べる | N Z C |
| [CPX](05-3-arithmetic.md#cpx) | Compare X Register(X の比較) | X とメモリの値を比べる | N Z C |
| [CPY](05-3-arithmetic.md#cpy) | Compare Y Register(Y の比較) | Y とメモリの値を比べる | N Z C |
| [INC](05-3-arithmetic.md#inc) | Increment Memory(メモリを 1 増やす) | メモリの値に 1 を足す | N Z |
| [DEC](05-3-arithmetic.md#dec) | Decrement Memory(メモリを 1 減らす) | メモリの値から 1 を引く | N Z |
| [INX](05-3-arithmetic.md#inx) | Increment X Register(X を 1 増やす) | X に 1 を足す | N Z |
| [INY](05-3-arithmetic.md#iny) | Increment Y Register(Y を 1 増やす) | Y に 1 を足す | N Z |
| [DEX](05-3-arithmetic.md#dex) | Decrement X Register(X を 1 減らす) | X から 1 を引く | N Z |
| [DEY](05-3-arithmetic.md#dey) | Decrement Y Register(Y を 1 減らす) | Y から 1 を引く | N Z |
| [AND](05-4-logic-shift.md#and) | Logical AND(論理積) | A とメモリの値のビットごとの AND | N Z |
| [ORA](05-4-logic-shift.md#ora) | Logical OR(論理和) | A とメモリの値のビットごとの OR | N Z |
| [EOR](05-4-logic-shift.md#eor) | Exclusive OR(排他的論理和) | A とメモリの値のビットごとの XOR | N Z |
| [BIT](05-4-logic-shift.md#bit) | Bit Test(ビットテスト) | A とメモリの値を AND して Z を決め、メモリの上位 2 ビットを N と V に写す | N V Z |
| [ASL](05-4-logic-shift.md#asl) | Arithmetic Shift Left(算術左シフト) | 左に 1 ビットずらし、最上位ビットを C に出す | N Z C |
| [LSR](05-4-logic-shift.md#lsr) | Logical Shift Right(論理右シフト) | 右に 1 ビットずらし、最下位ビットを C に出す | N Z C |
| [ROL](05-4-logic-shift.md#rol) | Rotate Left(左ローテート) | C を含めて左に 1 ビット回す | N Z C |
| [ROR](05-4-logic-shift.md#ror) | Rotate Right(右ローテート) | C を含めて右に 1 ビット回す | N Z C |
| [BCC](05-5-branch-jump.md#bcc) | Branch if Carry Clear(C が 0 なら分岐) | C が 0 のとき分岐する | なし |
| [BCS](05-5-branch-jump.md#bcs) | Branch if Carry Set(C が 1 なら分岐) | C が 1 のとき分岐する | なし |
| [BEQ](05-5-branch-jump.md#beq) | Branch if Equal(Z が 1 なら分岐) | Z が 1 のとき分岐する | なし |
| [BNE](05-5-branch-jump.md#bne) | Branch if Not Equal(Z が 0 なら分岐) | Z が 0 のとき分岐する | なし |
| [BMI](05-5-branch-jump.md#bmi) | Branch if Minus(N が 1 なら分岐) | N が 1 のとき分岐する | なし |
| [BPL](05-5-branch-jump.md#bpl) | Branch if Plus(N が 0 なら分岐) | N が 0 のとき分岐する | なし |
| [BVC](05-5-branch-jump.md#bvc) | Branch if Overflow Clear(V が 0 なら分岐) | V が 0 のとき分岐する | なし |
| [BVS](05-5-branch-jump.md#bvs) | Branch if Overflow Set(V が 1 なら分岐) | V が 1 のとき分岐する | なし |
| [JMP](05-5-branch-jump.md#jmp) | Jump(ジャンプ) | 指定の番地へ飛ぶ | なし |
| [JSR](05-5-branch-jump.md#jsr) | Jump to Subroutine(サブルーチン呼び出し) | 戻り番地を積んで、指定の番地へ飛ぶ | なし |
| [RTS](05-5-branch-jump.md#rts) | Return from Subroutine(サブルーチンから戻る) | 戻り番地を取り出して戻る | なし |
| [BRK](05-5-branch-jump.md#brk) | Break(ブレーク) | ソフトウェア割り込みを起こす | I |
| [RTI](05-5-branch-jump.md#rti) | Return from Interrupt(割り込みから戻る) | P と戻り番地を取り出して戻る | N V D I Z C |
| [PHA](05-6-stack-flags.md#pha) | Push Accumulator(A を積む) | A をスタックに積む | なし |
| [PLA](05-6-stack-flags.md#pla) | Pull Accumulator(A に取り出す) | スタックから A に取り出す | N Z |
| [PHP](05-6-stack-flags.md#php) | Push Processor Status(P を積む) | P をスタックに積む | なし |
| [PLP](05-6-stack-flags.md#plp) | Pull Processor Status(P に取り出す) | スタックから P に取り出す | N V D I Z C |
| [CLC](05-6-stack-flags.md#clc) | Clear Carry Flag(C を 0 にする) | C を 0 にする | C |
| [SEC](05-6-stack-flags.md#sec) | Set Carry Flag(C を 1 にする) | C を 1 にする | C |
| [CLI](05-6-stack-flags.md#cli) | Clear Interrupt Disable(I を 0 にする) | 割り込みを許可する | I |
| [SEI](05-6-stack-flags.md#sei) | Set Interrupt Disable(I を 1 にする) | 割り込みを禁止する | I |
| [CLD](05-6-stack-flags.md#cld) | Clear Decimal Mode(D を 0 にする) | 10進モードを解除する | D |
| [SED](05-6-stack-flags.md#sed) | Set Decimal Mode(D を 1 にする) | 10進モードにする | D |
| [CLV](05-6-stack-flags.md#clv) | Clear Overflow Flag(V を 0 にする) | V を 0 にする | V |
| [NOP](05-6-stack-flags.md#nop) | No Operation(何もしない) | 何もしない | なし |
<!-- /list -->

## 未定義のオペコード

公式の 151 オペコード以外の 105 個は、公式の命令ではありません。Glow65 は、これらを、オペランドを持たない 1 バイトの 2 サイクルの NOP として実行します。実機の NMOS 6502 では、未定義のオペコードが、オペコードごとに別の動作をしますが、Glow65 は再現しません。

65C02 で加わる命令(`BRA`、`STZ`、`PHX` など)は、この章に載せていません。

> **Glow65 で確かめられること**
>
> 未定義のオペコード `$02` を置いて実行します。`L` は `.BYTE` と表示します。
>
> ```
> *E 0300 02 A2 05 8E F0 03 60
> *L 0300 0301
> 0300  02        .BYTE $02
> 0301  A2 05     LDX   #$05
> *G 0300
> *D 03F0 03F0
> 03F0: 05 00 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> `$02` は、1 バイトの NOP として動きます。続く `LDX #$05` が実行されて、`$03F0` に `05` が書かれます。

## 出典

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", 1976年1月版: https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt

## 次の章

第6章「フラグ、スタック、割り込み」は準備中です。
