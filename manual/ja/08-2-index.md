# 8.2 索引

[← 8.1 用語集](08-1-glossary.md) &nbsp;·&nbsp; [章の入口](08-glossary-index.md)

## 8.2.1 命令の索引

アルファベット順です。第5章の各命令の見出しへ飛びます。

| ニーモニック | 名前 |
|---|---|
| [ADC](05-3-arithmetic.md#adc) | Add with Carry(キャリー付き加算) |
| [AND](05-4-logic-shift.md#and) | Logical AND(論理積) |
| [ASL](05-4-logic-shift.md#asl) | Arithmetic Shift Left(算術左シフト) |
| [BCC](05-5-branch-jump.md#bcc) | Branch if Carry Clear(C が 0 なら分岐) |
| [BCS](05-5-branch-jump.md#bcs) | Branch if Carry Set(C が 1 なら分岐) |
| [BEQ](05-5-branch-jump.md#beq) | Branch if Equal(Z が 1 なら分岐) |
| [BIT](05-4-logic-shift.md#bit) | Bit Test(ビットテスト) |
| [BMI](05-5-branch-jump.md#bmi) | Branch if Minus(N が 1 なら分岐) |
| [BNE](05-5-branch-jump.md#bne) | Branch if Not Equal(Z が 0 なら分岐) |
| [BPL](05-5-branch-jump.md#bpl) | Branch if Plus(N が 0 なら分岐) |
| [BRK](05-5-branch-jump.md#brk) | Break(ブレーク) |
| [BVC](05-5-branch-jump.md#bvc) | Branch if Overflow Clear(V が 0 なら分岐) |
| [BVS](05-5-branch-jump.md#bvs) | Branch if Overflow Set(V が 1 なら分岐) |
| [CLC](05-6-stack-flags.md#clc) | Clear Carry Flag(C を 0 にする) |
| [CLD](05-6-stack-flags.md#cld) | Clear Decimal Mode(D を 0 にする) |
| [CLI](05-6-stack-flags.md#cli) | Clear Interrupt Disable(I を 0 にする) |
| [CLV](05-6-stack-flags.md#clv) | Clear Overflow Flag(V を 0 にする) |
| [CMP](05-3-arithmetic.md#cmp) | Compare Accumulator(A の比較) |
| [CPX](05-3-arithmetic.md#cpx) | Compare X Register(X の比較) |
| [CPY](05-3-arithmetic.md#cpy) | Compare Y Register(Y の比較) |
| [DEC](05-3-arithmetic.md#dec) | Decrement Memory(メモリを 1 減らす) |
| [DEX](05-3-arithmetic.md#dex) | Decrement X Register(X を 1 減らす) |
| [DEY](05-3-arithmetic.md#dey) | Decrement Y Register(Y を 1 減らす) |
| [EOR](05-4-logic-shift.md#eor) | Exclusive OR(排他的論理和) |
| [INC](05-3-arithmetic.md#inc) | Increment Memory(メモリを 1 増やす) |
| [INX](05-3-arithmetic.md#inx) | Increment X Register(X を 1 増やす) |
| [INY](05-3-arithmetic.md#iny) | Increment Y Register(Y を 1 増やす) |
| [JMP](05-5-branch-jump.md#jmp) | Jump(ジャンプ) |
| [JSR](05-5-branch-jump.md#jsr) | Jump to Subroutine(サブルーチン呼び出し) |
| [LDA](05-1-load-store.md#lda) | Load Accumulator(ロード A) |
| [LDX](05-1-load-store.md#ldx) | Load X Register(ロード X) |
| [LDY](05-1-load-store.md#ldy) | Load Y Register(ロード Y) |
| [LSR](05-4-logic-shift.md#lsr) | Logical Shift Right(論理右シフト) |
| [NOP](05-6-stack-flags.md#nop) | No Operation(何もしない) |
| [ORA](05-4-logic-shift.md#ora) | Logical OR(論理和) |
| [PHA](05-6-stack-flags.md#pha) | Push Accumulator(A を積む) |
| [PHP](05-6-stack-flags.md#php) | Push Processor Status(P を積む) |
| [PLA](05-6-stack-flags.md#pla) | Pull Accumulator(A に取り出す) |
| [PLP](05-6-stack-flags.md#plp) | Pull Processor Status(P に取り出す) |
| [ROL](05-4-logic-shift.md#rol) | Rotate Left(左ローテート) |
| [ROR](05-4-logic-shift.md#ror) | Rotate Right(右ローテート) |
| [RTI](05-5-branch-jump.md#rti) | Return from Interrupt(割り込みから戻る) |
| [RTS](05-5-branch-jump.md#rts) | Return from Subroutine(サブルーチンから戻る) |
| [SBC](05-3-arithmetic.md#sbc) | Subtract with Carry(キャリー付き減算) |
| [SEC](05-6-stack-flags.md#sec) | Set Carry Flag(C を 1 にする) |
| [SED](05-6-stack-flags.md#sed) | Set Decimal Mode(D を 1 にする) |
| [SEI](05-6-stack-flags.md#sei) | Set Interrupt Disable(I を 1 にする) |
| [STA](05-1-load-store.md#sta) | Store Accumulator(ストア A) |
| [STX](05-1-load-store.md#stx) | Store X Register(ストア X) |
| [STY](05-1-load-store.md#sty) | Store Y Register(ストア Y) |
| [TAX](05-2-transfer.md#tax) | Transfer A to X(A を X へ転送) |
| [TAY](05-2-transfer.md#tay) | Transfer A to Y(A を Y へ転送) |
| [TSX](05-2-transfer.md#tsx) | Transfer Stack Pointer to X(SP を X へ転送) |
| [TXA](05-2-transfer.md#txa) | Transfer X to A(X を A へ転送) |
| [TXS](05-2-transfer.md#txs) | Transfer X to Stack Pointer(X を SP へ転送) |
| [TYA](05-2-transfer.md#tya) | Transfer Y to A(Y を A へ転送) |

## 8.2.2 アドレッシングモードの索引

| モード | 書き方の例 | 節 |
|---|---|---|
| インプライド(Implied) | `INX` | [インプライド(Implied)](04-addressing.md#インプライドimplied) |
| アキュムレータ(Accumulator) | `ASL A` | [アキュムレータ(Accumulator)](04-addressing.md#アキュムレータaccumulator) |
| イミディエイト(Immediate) | `LDA #$10` | [4.3 イミディエイト(Immediate)](04-addressing.md#43-イミディエイトimmediate) |
| ゼロページ(Zero Page) | `LDA $10` | [ゼロページ(Zero Page)](04-addressing.md#ゼロページzero-page) |
| ゼロページ X(Zero Page,X) | `LDA $10,X` | [ゼロページ X(Zero Page,X)](04-addressing.md#ゼロページ-xzero-pagex) |
| ゼロページ Y(Zero Page,Y) | `LDX $10,Y` | [ゼロページ Y(Zero Page,Y)](04-addressing.md#ゼロページ-yzero-pagey) |
| アブソリュート(Absolute) | `LDA $0400` | [アブソリュート(Absolute)](04-addressing.md#アブソリュートabsolute) |
| アブソリュート X(Absolute,X) | `LDA $0410,X` | [アブソリュート X(Absolute,X)](04-addressing.md#アブソリュート-xabsolutex) |
| アブソリュート Y(Absolute,Y) | `LDA $0420,Y` | [アブソリュート Y(Absolute,Y)](04-addressing.md#アブソリュート-yabsolutey) |
| インダイレクト(Indirect) | `JMP ($0430)` | [4.6 インダイレクト(Indirect)](04-addressing.md#46-インダイレクトindirect) |
| インデックスト・インダイレクト(Indexed Indirect) | `LDA ($20,X)` | [4.7 インデックスト・インダイレクト(Indexed Indirect)](04-addressing.md#47-インデックストインダイレクトindexed-indirect) |
| インダイレクト・インデックスト(Indirect Indexed) | `LDA ($30),Y` | [4.8 インダイレクト・インデックスト(Indirect Indexed)](04-addressing.md#48-インダイレクトインデックストindirect-indexed) |
| リラティブ(Relative) | `BNE label` | [4.9 リラティブ(Relative)](04-addressing.md#49-リラティブrelative) |

## 8.2.3 フラグとレジスタの索引

| 項目 | 節 |
|---|---|
| N(ネガティブ) | [6.1.1 N と Z(結果のフラグ)](06-flags-stack-interrupts.md#611-n-と-z結果のフラグ) |
| Z(ゼロ) | [6.1.1 N と Z(結果のフラグ)](06-flags-stack-interrupts.md#611-n-と-z結果のフラグ) |
| C(キャリー) | [6.1.2 C(キャリー)](06-flags-stack-interrupts.md#612-cキャリー) |
| V(オーバーフロー) | [6.1.3 V(オーバーフロー)](06-flags-stack-interrupts.md#613-vオーバーフロー) |
| D(10進モード) | [6.1.4 D(10進モード)](06-flags-stack-interrupts.md#614-d10進モード) |
| I(割り込み禁止) | [6.1.5 I(割り込み禁止)](06-flags-stack-interrupts.md#615-i割り込み禁止) |
| B(ブレーク)とビット 5 | [6.1.6 B とビット 5](06-flags-stack-interrupts.md#616-b-とビット-5) |
| フラグの全体(P レジスタ) | [3.2 レジスタ](03-cpu.md#32-レジスタ)、[6.1 フラグ(P レジスタ)](06-flags-stack-interrupts.md#61-フラグp-レジスタ) |
| A(アキュムレータ) | [3.2 レジスタ](03-cpu.md#32-レジスタ) |
| X、Y(インデックスレジスタ) | [3.2 レジスタ](03-cpu.md#32-レジスタ) |
| SP(スタックポインタ) | [6.2.1 場所と SP](06-flags-stack-interrupts.md#621-場所と-sp)、[3.2 レジスタ](03-cpu.md#32-レジスタ) |
| PC(プログラムカウンタ) | [3.1 CPU とメモリ](03-cpu.md#31-cpu-とメモリ)、[3.2 レジスタ](03-cpu.md#32-レジスタ) |
| P(ステータス) | [6.1 フラグ(P レジスタ)](06-flags-stack-interrupts.md#61-フラグp-レジスタ)、[3.2 レジスタ](03-cpu.md#32-レジスタ) |

## 8.2.4 モニタのコマンドとルーチンの索引

| 項目 | 内容 | 節 |
|---|---|---|
| コマンド `D` | メモリダンプ | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| コマンド `E` | バイトを書き込む | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| コマンド `L` | 逆アセンブル | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| コマンド `G` | ルーチンを呼ぶ | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| コマンド `B` | BASIC を起動 | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| コマンド `?` | ヘルプ | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| ルーチン `$F000` CHRIN | 1 文字入力(待つ) | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| ルーチン `$F003` CHROUT | 1 文字出力 | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| ルーチン `$F006` ISCNTC | Ctrl-C の確認 | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| ルーチン `$F009` ウォームスタート | モニタに戻る | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| ルーチン `$F00C` GETKEY | 待たずに 1 文字入力 | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |

## 8.2.5 主なアドレスの索引

| アドレス | 内容 | 節 |
|---|---|---|
| `$0000-$00FF` | ゼロページ | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$0006-$000C` | BASIC の USR と変換ルーチンのベクタ | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$00F0-$00FF` | モニタが使うゼロページ | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$0100-$01FF` | スタック | [6.2.1 場所と SP](06-flags-stack-interrupts.md#621-場所と-sp) |
| `$0200-$027F` | モニタの行入力バッファ | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$0300-$03F7` | ユーザープログラム用 | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$03F8-$03FB` | NMI、IRQ と BRK のハンドラの番地(RAM) | [6.3.6 Glow65 の割り込み](06-flags-stack-interrupts.md#636-glow65-の割り込み) |
| `$0400-$7FFF` | BASIC のプログラムと変数 | [7.1.3 RAM の使い分け](07-memory-io.md#713-ram-の使い分け) |
| `$8000-$9FFF` | 何もつながっていない | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| `$A000` `$A001` | UART の状態と制御、データ | [7.3 UART](07-memory-io.md#73-uart) |
| `$A000-$A0FF` | UART(鏡像) | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| `$A100-$BFFF` | 何もつながっていない | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| `$C000-$EFFF` | BASIC の ROM | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| `$F000-$FFFF` | モニタの ROM とベクタ | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| `$F000-$F00C` | モニタのジャンプテーブル | [7.4 モニタのルーチン](07-memory-io.md#74-モニタのルーチン) |
| `$FFFA-$FFFF` | NMI、リセット、IRQ と BRK のベクタ | [3.7 リセットと割り込みのベクタ](03-cpu.md#37-リセットと割り込みのベクタ)、[6.3.1 4 つの割り込み](06-flags-stack-interrupts.md#631-4-つの割り込み) |

## 8.2.6 図の一覧

| 図 | タイトル | 画像 | 節 |
|---|---|---|---|
| 図 3-1 | リセット直後のパネル | [03-reset.png](images/03-reset.png) | [3.2 レジスタ](03-cpu.md#32-レジスタ) |
| 図 3-2 | STEP 1 回目(SEI のオペコード) | [03-cycle-1.png](images/03-cycle-1.png) | [3.4 フェッチと実行](03-cpu.md#34-フェッチと実行) |
| 図 3-3 | STEP 3 回目(LDX のオペコード) | [03-cycle-3.png](images/03-cycle-3.png) | [3.4 フェッチと実行](03-cpu.md#34-フェッチと実行) |
| 図 3-4 | STEP 4 回目(LDX のオペランド) | [03-cycle-4.png](images/03-cycle-4.png) | [3.4 フェッチと実行](03-cpu.md#34-フェッチと実行) |
| 図 3-5 | STEP 5 回目(LDX の結果) | [03-cycle-5.png](images/03-cycle-5.png) | [3.4 フェッチと実行](03-cpu.md#34-フェッチと実行) |
| 図 3-6 | INSTR で 3 回目の STEP のあと | [03-instr-3.png](images/03-instr-3.png) | [3.6 命令の実行例](03-cpu.md#36-命令の実行例) |
| 図 3-7 | INSTR で 4 回目の STEP のあと | [03-instr-4.png](images/03-instr-4.png) | [3.6 命令の実行例](03-cpu.md#36-命令の実行例) |
| 図 4-1 | インプライド(`INX`) | [04-implied.svg](images/04-implied.svg) | [インプライド(Implied)](04-addressing.md#インプライドimplied) |
| 図 4-2 | アキュムレータ(`ASL A`) | [04-accumulator.svg](images/04-accumulator.svg) | [アキュムレータ(Accumulator)](04-addressing.md#アキュムレータaccumulator) |
| 図 4-3 | イミディエイト(`LDA #$10`) | [04-immediate.svg](images/04-immediate.svg) | [4.3 イミディエイト(Immediate)](04-addressing.md#43-イミディエイトimmediate) |
| 図 4-4 | ゼロページ(`LDA $10`) | [04-zeropage.svg](images/04-zeropage.svg) | [ゼロページ(Zero Page)](04-addressing.md#ゼロページzero-page) |
| 図 4-5 | ゼロページ X(`LDA $10,X`) | [04-zeropage-x.svg](images/04-zeropage-x.svg) | [ゼロページ X(Zero Page,X)](04-addressing.md#ゼロページ-xzero-pagex) |
| 図 4-6 | ゼロページ Y(`LDX $10,Y`) | [04-zeropage-y.svg](images/04-zeropage-y.svg) | [ゼロページ Y(Zero Page,Y)](04-addressing.md#ゼロページ-yzero-pagey) |
| 図 4-7 | アブソリュート(`LDA $0400`) | [04-absolute.svg](images/04-absolute.svg) | [アブソリュート(Absolute)](04-addressing.md#アブソリュートabsolute) |
| 図 4-8 | アブソリュート X(`LDA $0410,X`) | [04-absolute-x.svg](images/04-absolute-x.svg) | [アブソリュート X(Absolute,X)](04-addressing.md#アブソリュート-xabsolutex) |
| 図 4-9 | アブソリュート Y(`LDA $0420,Y`) | [04-absolute-y.svg](images/04-absolute-y.svg) | [アブソリュート Y(Absolute,Y)](04-addressing.md#アブソリュート-yabsolutey) |
| 図 4-10 | インダイレクト(`JMP ($0430)`) | [04-indirect.svg](images/04-indirect.svg) | [4.6 インダイレクト(Indirect)](04-addressing.md#46-インダイレクトindirect) |
| 図 4-11 | インデックスト・インダイレクト(`LDA ($20,X)`) | [04-indexed-indirect.svg](images/04-indexed-indirect.svg) | [4.7 インデックスト・インダイレクト(Indexed Indirect)](04-addressing.md#47-インデックストインダイレクトindexed-indirect) |
| 図 4-12 | インダイレクト・インデックスト(`LDA ($30),Y`) | [04-indirect-indexed.svg](images/04-indirect-indexed.svg) | [4.8 インダイレクト・インデックスト(Indirect Indexed)](04-addressing.md#48-インダイレクトインデックストindirect-indexed) |
| 図 4-13 | リラティブ(`BNE`) | [04-relative.svg](images/04-relative.svg) | [4.9 リラティブ(Relative)](04-addressing.md#49-リラティブrelative) |
| 図 5-1 | ASL、LSR、ROL、ROR のビットの動き | [05-shift.svg](images/05-shift.svg) | [5.4 論理演算とシフト](05-4-logic-shift.md#54-論理演算とシフト) |
| 図 5-2 | BIT が N、V、Z を決める流れ | [05-bit.svg](images/05-bit.svg) | [5.4 論理演算とシフト](05-4-logic-shift.md#54-論理演算とシフト) |
| 図 5-3 | 分岐の飛び先 | [05-branch.svg](images/05-branch.svg) | [5.5 分岐とジャンプ](05-5-branch-jump.md#55-分岐とジャンプ) |
| 図 5-4 | JSR と RTS | [05-jsr-rts.svg](images/05-jsr-rts.svg) | [5.5 分岐とジャンプ](05-5-branch-jump.md#55-分岐とジャンプ) |
| 図 5-5 | BRK と RTI | [05-brk-rti.svg](images/05-brk-rti.svg) | [5.5 分岐とジャンプ](05-5-branch-jump.md#55-分岐とジャンプ) |
| 図 5-6 | PHA と PLA | [05-stack.svg](images/05-stack.svg) | [5.6 スタックとフラグ操作](05-6-stack-flags.md#56-スタックとフラグ操作) |
| 図 6-1 | P レジスタの 8 ビット | [06-flags.svg](images/06-flags.svg) | [6.1 フラグ(P レジスタ)](06-flags-stack-interrupts.md#61-フラグp-レジスタ) |
| 図 6-2 | CMP のあとのフラグと分岐 | [06-compare.svg](images/06-compare.svg) | [6.1.8 比較(CMP)のあと](06-flags-stack-interrupts.md#618-比較cmpのあと) |
| 図 6-3 | JSR を 2 回重ねたときのスタック | [06-stack-nested.svg](images/06-stack-nested.svg) | [6.2.3 JSR を重ねたとき](06-flags-stack-interrupts.md#623-jsr-を重ねたとき) |
| 図 6-4 | 割り込みの流れ | [06-interrupt-flow.svg](images/06-interrupt-flow.svg) | [6.3.2 受け付けの手順](06-flags-stack-interrupts.md#632-受け付けの手順) |
| 図 6-5 | NMI と IRQ の違い | [06-nmi-irq.svg](images/06-nmi-irq.svg) | [6.3.3 NMI と IRQ の違い](06-flags-stack-interrupts.md#633-nmi-と-irq-の違い) |
| 図 6-6 | NMI ボタンを押した直後 | [06-gui-nmi-pending.png](images/06-gui-nmi-pending.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-7 | STEP 1 回目(PC の上位バイトを積む) | [06-gui-nmi-push1.png](images/06-gui-nmi-push1.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-8 | STEP 3 回目(P を積む) | [06-gui-nmi-push3.png](images/06-gui-nmi-push3.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-9 | NMI の受け付けの完了 | [06-gui-nmi-entered.png](images/06-gui-nmi-entered.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-10 | ハンドラの PHA のあと | [06-gui-nmi-pha.png](images/06-gui-nmi-pha.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-11 | RTI のあと | [06-gui-nmi-rti.png](images/06-gui-nmi-rti.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-12 | IRQ の受け付け直後 | [06-gui-irq-entered.png](images/06-gui-irq-entered.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-13 | LDA $A001 のあと | [06-gui-irq-read.png](images/06-gui-irq-read.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 6-14 | IRQ の LED が消える | [06-gui-irq-off.png](images/06-gui-irq-off.png) | [6.3.7 パネルで割り込みを見る](06-flags-stack-interrupts.md#637-パネルで割り込みを見る) |
| 図 7-1 | Glow65 のメモリマップ | [07-memory-map.svg](images/07-memory-map.svg) | [7.1.2 Glow65 のメモリマップ](07-memory-io.md#712-glow65-のメモリマップ) |
| 図 7-2 | UART のレジスタ | [07-uart.svg](images/07-uart.svg) | [7.3 UART](07-memory-io.md#73-uart) |
| 図 7-3 | ポーリングの流れ | [07-polling.svg](images/07-polling.svg) | [7.3.1 ポーリング](07-memory-io.md#731-ポーリング) |
| 図 7-4 | 受信データがないとき($A000 は $02) | [07-gui-status-02.png](images/07-gui-status-02.png) | [7.3.1 ポーリング](07-memory-io.md#731-ポーリング) |
| 図 7-5 | h を入力したあと($A000 は $03) | [07-gui-status-03.png](images/07-gui-status-03.png) | [7.3.1 ポーリング](07-memory-io.md#731-ポーリング) |
| 図 7-6 | $A001 を読んだとき | [07-gui-data-read.png](images/07-gui-data-read.png) | [7.3.1 ポーリング](07-memory-io.md#731-ポーリング) |
| 図 7-7 | データを読んだあと($A000 は $02) | [07-gui-status-after.png](images/07-gui-status-after.png) | [7.3.1 ポーリング](07-memory-io.md#731-ポーリング) |

---

[← 8.1 用語集](08-1-glossary.md) &nbsp;·&nbsp; [章の入口](08-glossary-index.md)
