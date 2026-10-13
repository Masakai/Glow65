; GAME65G: Glow65 用の GAME 言語インタプリタ(自作、MIT License)
;
; GAME 言語(大西博氏、月刊アスキー 1978 年)の公開された仕様をもとに一から書いた。
; 鈴木仁志氏の GAME65(1979 年)とは別物で、そのコードは使っていない。
; 仕様と独自に決めた点は documents/designs/2026-10-13-game65g.md を参照。
;
; 配置: $8000-$9FFF。$8000 コールドスタート、$8003 ウォームスタート。
; 入出力はモニタのジャンプテーブル($F000 CHRIN、$F003 CHROUT、$F00C GETKEY)を使う。
; 命令は NMOS 6502 の範囲だけを使う(65C02 モードでも動く)。

        .setcpu "6502"

CHRIN     = $F000       ; 1文字入力(待つ)
CHROUT    = $F003       ; 1文字出力
GETKEY    = $F00C       ; 1文字入力(待たない。なければ A=0)

IBUF      = $0400       ; 行入力バッファ(128 バイト)
INBUF     = $0480       ; 数値入力 ? 用のバッファ(128 バイト)
SSTK      = $0500       ; 第2スタック(GOSUB、FOR、DO。1段 6 バイト、31 段)
KBUF      = $05C0       ; 先打ちのキーの環状バッファ(64 バイト)
PROG      = $0600       ; プログラムの先頭(= の初期値)

; ---- ゼロページ($F0-$FF はモニタ用に空ける) ----
TP        = $00         ; 2: 実行・解析中の文字の位置
LINEP     = $02         ; 2: 実行中の行の先頭(上位が 0 なら直接実行)
ACC       = $04         ; 2: 式の値
ARG       = $06         ; 2: 二項演算の右辺
REM       = $08         ; 2: 直前の割り算の余り(%)
PSTART    = $0A         ; 2: = プログラム先頭
PEND      = $0C         ; 2: & プログラム末尾(EOF マークの位置)
RAMEND    = $0E         ; 2: * RAM 末尾
RNDV      = $10         ; 2: ' 乱数レジスタ
SSP       = $12         ; 1: 第2スタックの使用バイト数
KHEAD     = $13         ; 1: KBUF の読み出し位置
PTR1      = $14         ; 2: 行を探す・表示するときのポインタ
PTR2      = $16         ; 2: 入力バッファ、配列の番地
CNT       = $18         ; 2: 転送するバイト数
TMP       = $1A         ; 2
WREM      = $1C         ; 2: 符号なし除算の余り
SRC       = $1E         ; 2: 転送元
DST       = $20         ; 2: 転送先
SIGN      = $22         ; 1
COL0      = $23         ; 1: 行頭にいれば 1
VIDX      = $24         ; 1: 代入先の変数のゼロページ番地(0 = なし)
NUMBUF    = $25         ; 7: 10進数の文字列
KTAIL     = $2C         ; 1: KBUF の書き込み位置
VARS      = $80         ; 52: 変数 A-Z(下位・上位の順)

EOFMARK   = $FF         ; EOF マーク(OPEN)
LOCKMARK  = $F0         ; EOF マーク(LOCK。行の追加と削除を受け付けない)
SSTKMAX   = 186         ; 第2スタックの上限(31 段。KBUF の手前まで)

        .segment "CODE"

        jmp COLD        ; $8000
        jmp READY       ; $8003

; ---- 起動 ----
COLD:
        ldx #$FF
        txs
        cld
        lda #<PROG
        sta PSTART
        lda #>PROG
        sta PSTART+1
        lda #$FF
        sta RAMEND
        lda #$7F
        sta RAMEND+1
        lda #$E1            ; 乱数の種(0 以外)
        sta RNDV
        lda #$AC
        sta RNDV+1
        lda #0
        sta KHEAD
        sta KTAIL
        ldx #51
:       sta VARS,x
        dex
        bpl :-
        jsr DONEW
        lda #<Banner
        ldy #>Banner
        jsr PRSTR

; ---- プロンプト ----
READY:
        ldx #$FF
        txs
        cld
        lda #0
        sta SSP
        sta LINEP+1         ; 直接実行
        lda COL0
        bne :+
        jsr CRLF
:       lda #'>'
        jsr OUTCH
        lda #<IBUF
        ldy #>IBUF
        jsr GETLINE
        jsr SKIPSP
        cmp #'0'
        bcc :+
        cmp #'9'+1
        bcs :+
        jmp LINECMD
:       jmp STMT

; ---- 行番号で始まる入力: LIST、行の追加・置き換え・削除 ----
LINECMD:
        jsr PARSENUM
        jsr GETC
        cmp #'/'
        beq @list
        lda ACC
        ora ACC+1
        beq @list           ; 0 は全体の LIST
        lda ACC+1
        bmi @err            ; 32767 を超える
        ldy #0
        lda (PEND),y
        cmp #LOCKMARK
        beq @err
        jsr FINDLN
        ldy #0
        lda (PTR1),y
        bmi @ins            ; EOF
        cmp ACC+1
        bne @ins
        iny
        lda (PTR1),y
        cmp ACC
        bne @ins
        jsr DELLINE         ; 同じ番号の行を消す
@ins:   jsr GETC
        cmp #$0D
        beq @done           ; 行番号だけなら削除で終わり
        jsr INSLINE
@done:  jmp READY
@list:  jmp LIST
@err:   jmp ERROR

; PTR1 の行を消す
DELLINE:
        ldy #2
        lda (PTR1),y
        sta TMP             ; 行の長さ
        clc
        adc PTR1
        sta SRC
        lda PTR1+1
        adc #0
        sta SRC+1
        lda PTR1
        sta DST
        lda PTR1+1
        sta DST+1
        sec                 ; CNT = PEND - SRC + 1
        lda PEND
        sbc SRC
        sta CNT
        lda PEND+1
        sbc SRC+1
        sta CNT+1
        inc CNT
        bne :+
        inc CNT+1
:       sec
        lda PEND
        sbc TMP
        sta PEND
        bcs :+
        dec PEND+1
:       jmp MOVEDN

; PTR1 の位置に、行番号 ACC、本文 TP(CR まで)の行を入れる。
; 行の形: 行番号(上位、下位)、行の長さ、本文、CR
INSLINE:
        ldy #0
:       lda (TP),y
        cmp #$0D
        beq :+
        iny
        bne :-
:       tya
        clc
        adc #4
        sta TMP             ; 行の長さ
        clc                 ; DST = 新しい PEND
        adc PEND
        sta DST
        lda PEND+1
        adc #0
        sta DST+1
        lda RAMEND          ; RAMEND < DST なら入らない
        cmp DST
        lda RAMEND+1
        sbc DST+1
        bcs :+
        jmp ERROR
:       lda PEND
        sta SRC
        lda PEND+1
        sta SRC+1
        sec                 ; CNT = PEND - PTR1 + 1
        lda PEND
        sbc PTR1
        sta CNT
        lda PEND+1
        sbc PTR1+1
        sta CNT+1
        inc CNT
        bne :+
        inc CNT+1
:       lda DST
        sta PEND
        lda DST+1
        sta PEND+1
        jsr MOVEUP
        ldy #0
        lda ACC+1
        sta (PTR1),y
        iny
        lda ACC
        sta (PTR1),y
        iny
        lda TMP
        sta (PTR1),y
        clc
        lda PTR1
        adc #3
        sta DST
        lda PTR1+1
        adc #0
        sta DST+1
        ldy #0
:       lda (TP),y          ; CR まで写す
        sta (DST),y
        iny
        cmp #$0D
        bne :-
        rts

; SRC から DST へ CNT バイトを前から写す
MOVEDN:
        ldy #0
@l:     lda CNT
        ora CNT+1
        beq @r
        lda (SRC),y
        sta (DST),y
        inc SRC
        bne :+
        inc SRC+1
:       inc DST
        bne :+
        inc DST+1
:       lda CNT
        bne :+
        dec CNT+1
:       dec CNT
        jmp @l
@r:     rts

; SRC から DST へ CNT バイトを後ろから写す(SRC、DST は末尾を指す)
MOVEUP:
        ldy #0
@l:     lda CNT
        ora CNT+1
        beq @r
        lda (SRC),y
        sta (DST),y
        lda SRC
        bne :+
        dec SRC+1
:       dec SRC
        lda DST
        bne :+
        dec DST+1
:       dec DST
        lda CNT
        bne :+
        dec CNT+1
:       dec CNT
        jmp @l
@r:     rts

; 行番号 ACC 以上の最初の行を PTR1 に返す(なければ EOF マークの位置)
FINDLN:
        lda PSTART
        sta PTR1
        lda PSTART+1
        sta PTR1+1
@l:     ldy #0
        lda (PTR1),y
        bmi @r              ; EOF
        ldy #1
        lda (PTR1),y
        cmp ACC
        dey
        lda (PTR1),y
        sbc ACC+1
        bcs @r              ; 行番号 >= ACC
        jsr NEXTPTR1
        bne @l
@r:     rts

; PTR1 を次の行へ進める(Z=0 で戻る)
NEXTPTR1:
        ldy #2
        lda (PTR1),y
        clc
        adc PTR1
        sta PTR1
        bcc :+
        inc PTR1+1
:       lda #1
        rts

; 行番号 ACC から最後まで表示する
LIST:
        jsr FINDLN
@l:     ldy #0
        lda (PTR1),y
        bmi @e
        jsr CHKBRK
        ldy #0
        lda (PTR1),y
        sta ACC+1
        iny
        lda (PTR1),y
        sta ACC
        jsr PRDEC
        ldy #3
:       lda (PTR1),y
        cmp #$0D
        beq :+
        jsr OUTCH
        iny
        bne :-
:       jsr CRLF
        jsr NEXTPTR1
        bne @l
@e:     jmp READY

; NEW: 末尾ポインタを先頭にして EOF マークを書く
DONEW:
        lda PSTART
        sta PEND
        lda PSTART+1
        sta PEND+1
        lda #EOFMARK
        ldy #0
        sta (PEND),y
        rts

; SEARCH END: 先頭から行をたどり、EOF マークの位置を & にする
SEARCHEND:
        lda PSTART
        sta PTR1
        lda PSTART+1
        sta PTR1+1
@l:     ldy #0
        lda (PTR1),y
        bmi @e
        ldy #2
        lda (PTR1),y
        beq @e              ; 壊れた行で止める
        jsr NEXTPTR1
        lda PTR1+1
        bne @l
@e:     lda PTR1
        sta PEND
        lda PTR1+1
        sta PEND+1
        rts

; ---- 実行 ----
STMT:
        jsr CHKBRK
        jsr SKIPSP
        cmp #$0D
        bne :+
        jsr NEXTLINE
        jmp STMT
:       jsr DOSTMT
        jmp STMT

; 次の行へ進む。直接実行かプログラムの終わりならプロンプトへ戻る。
NEXTLINE:
        lda LINEP+1
        bne :+
        jmp READY
:       lda LINEP
        sta PTR1
        lda LINEP+1
        sta PTR1+1
        jsr NEXTPTR1
; PTR1 の行から実行を始める。行番号のあとが空白でなければ注釈なので飛ばす。
ENTERP:
        ldy #0
        lda (PTR1),y
        bpl :+
        jmp READY           ; EOF
:       lda PTR1
        sta LINEP
        clc
        adc #3
        sta TP
        lda PTR1+1
        sta LINEP+1
        adc #0
        sta TP+1
        ldy #0
        lda (TP),y
        cmp #' '
        bne NEXTLINE
        rts

; 行番号 ACC へ飛ぶ(なければそれより大きい最初の行。なければ終了)
GOTOLN:
        jsr FINDLN
        jmp ENTERP

; 文を1つ実行する。A = 文の最初の文字。
DOSTMT:
        ldx #0
@l:     cmp StmtChr,x
        beq @f
        inx
        cpx #StmtTab-StmtChr
        bne @l
        jmp ASSIGN
@f:     txa
        asl a
        tax
        lda StmtTab+1,x
        pha
        lda StmtTab,x
        pha
        jmp INCTP           ; 文字を読み進め、RTS で処理へ飛ぶ

; "文字"
S_STR:
        jsr GETC
        cmp #$0D
        beq @e
        jsr INCTP
        cmp #'"'
        beq @e
        jsr OUTCH
        jmp S_STR
@e:     rts

; ?=n  ?(m)=n  ??=n  ?$=n
S_PR:
        jsr GETC
        cmp #'('
        beq @right
        cmp #'?'
        beq @hex4
        cmp #'$'
        beq @hex2
        jsr EQEXPR
        lda #0
        beq @num
@right: jsr INCTP
        jsr EXPR
        jsr EXPECTRP
        lda ACC
        pha
        jsr EQEXPR
        pla
@num:   jmp PRNUM
@hex4:  jsr INCTP
        jsr EQEXPR
        lda ACC+1
        jsr PRHEX2
        jmp @lo
@hex2:  jsr INCTP
        jsr EQEXPR
@lo:    lda ACC
        jmp PRHEX2

; $=n
S_CHR:
        jsr EQEXPR
        lda ACC
        jmp OUTCH

; .=n
S_TAB:
        jsr EQEXPR
        ldx ACC
        beq @r
:       lda #' '
        jsr OUTCH
        dex
        bne :-
@r:     rts

; #=n
S_GOTO:
        jsr EQEXPR
        lda ACC
        ora ACC+1
        beq :+
        jmp GOTOLN
:       rts

; !=n
S_GOSUB:
        jsr EQEXPR
        lda ACC
        ora ACC+1
        beq @r
        jsr PUSHENT
        jmp GOTOLN
@r:     rts

; ]
S_RET:
        jsr TOPENT
        stx SSP
        jmp GOENT

; >=n
S_CALL:
        jsr EQEXPR
        jmp (ACC)

; ;=n
S_IF:
        jsr EQEXPR
        lda ACC
        ora ACC+1
        bne @r
:       jsr GETC            ; 偽なら行末へ
        cmp #$0D
        beq @r
        jsr INCTP
        jmp :-
@r:     rts

; @(DO)、@=n(NEXT、UNTIL)
S_DO:
        jsr GETC
        cmp #'='
        beq @next
        lda #0
        sta ACC
        sta ACC+1
        jmp PUSHENT
@next:  jsr NEXTC
        ldx #0
        jsr ISALPHA
        bcc :+
        jsr VARADDR
:       stx VIDX            ; = の次が変数名なら、値をそこへ入れる
        jsr EXPR
        ldx VIDX
        beq :+
        lda ACC
        sta 0,x
        lda ACC+1
        sta 1,x
:       jsr TOPENT
        lda SSTK+4,x        ; 終値 < 値 ならループを抜ける
        cmp ACC
        lda SSTK+5,x
        sbc ACC+1
        bvc :+
        eor #$80
:       bmi @exit
        jmp GOENT
@exit:  stx SSP
        rts

; =n(プログラム先頭を変え、末尾を探す。== は末尾を探すだけ)
S_PROG:
        jsr EXPR
        lda ACC
        sta PSTART
        lda ACC+1
        sta PSTART+1
        jmp SEARCHEND

; 代入: V=n、V=a,b(FOR)、V(i)=n、V:i)=n。V は A-Z と & * '
ASSIGN:
        jsr VARADDR
        bcc :+
        jmp ERROR
:       stx VIDX
        jsr SKIPVAR
        cmp #'('
        beq @word
        cmp #':'
        beq @byte
        jsr EQEXPR
        ldx VIDX
        lda ACC
        sta 0,x
        lda ACC+1
        sta 1,x
        cpx #PEND           ; &=0 は NEW
        bne @for
        ora ACC
        bne @for
        jsr DONEW
@for:   jsr GETC
        cmp #','
        bne @r
        jsr INCTP
        jsr EXPR
        jmp PUSHENT
@r:     rts
@word:  jsr INCTP
        ldx VIDX
        jsr ARRW
        jsr @val
        ldy #1
        lda ACC+1
        sta (PTR2),y
        dey
        beq @lo
@byte:  jsr INCTP
        ldx VIDX
        jsr ARRB
        jsr @val
        ldy #0
@lo:    lda ACC
        sta (PTR2),y
        rts
@val:   lda PTR2+1          ; 右辺の評価で PTR2 が変わるので退避する
        pha
        lda PTR2
        pha
        jsr EQEXPR
        pla
        sta PTR2
        pla
        sta PTR2+1
        rts

; ---- 第2スタック ----
; TP、LINEP、ACC(終値)を積む
PUSHENT:
        ldx SSP
        cpx #SSTKMAX
        bcc :+
        jmp ERROR
:       lda TP
        sta SSTK,x
        lda TP+1
        sta SSTK+1,x
        lda LINEP
        sta SSTK+2,x
        lda LINEP+1
        sta SSTK+3,x
        lda ACC
        sta SSTK+4,x
        lda ACC+1
        sta SSTK+5,x
        txa
        clc
        adc #6
        sta SSP
        rts

; 一番上の段の位置を X に返す(空ならエラー)
TOPENT:
        ldx SSP
        bne :+
        jmp ERROR
:       txa
        sec
        sbc #6
        tax
        rts

; X の段の位置へ戻る
GOENT:
        lda SSTK,x
        sta TP
        lda SSTK+1,x
        sta TP+1
        lda SSTK+2,x
        sta LINEP
        lda SSTK+3,x
        sta LINEP+1
        rts

; ---- 式 ----
; 優先順位はなく、左から計算する。値は ACC。
EXPR:
        jsr TERM
@lp:    jsr GETC
        ldx #OpTab-OpChr-1
@f:     cmp OpChr,x
        beq @op
        dex
        bpl @f
        rts
@op:    jsr NEXTC
        cpx #8              ; <> <=
        bne @gt
        cmp #'>'
        bne :+
        ldx #10
        bne @two
:       cmp #'='
        bne @one
        ldx #11
        bne @two
@gt:    cpx #9              ; >=
        bne @one
        cmp #'='
        bne @one
        ldx #12
@two:   jsr INCTP
@one:   txa
        pha
        lda ACC+1
        pha
        lda ACC
        pha
        jsr TERM
        lda ACC
        sta ARG
        lda ACC+1
        sta ARG+1
        pla
        sta ACC
        pla
        sta ACC+1
        pla
        jsr DOOP
        jmp @lp

DOOP:
        asl a
        tax
        lda OpTab+1,x
        pha
        lda OpTab,x
        pha
        rts

OP_ADD:
        clc
        lda ACC
        adc ARG
        sta ACC
        lda ACC+1
        adc ARG+1
        sta ACC+1
        rts

OP_SUB:
        sec
        lda ACC
        sbc ARG
        sta ACC
        lda ACC+1
        sbc ARG+1
        sta ACC+1
        rts

OP_AND:
        lda ACC
        and ARG
        sta ACC
        lda ACC+1
        and ARG+1
        sta ACC+1
        rts

OP_OR:
        lda ACC
        ora ARG
        sta ACC
        lda ACC+1
        ora ARG+1
        sta ACC+1
        rts

OP_XOR:
        lda ACC
        eor ARG
        sta ACC
        lda ACC+1
        eor ARG+1
        sta ACC+1
        rts

OP_MUL:
        lda #0
        sta TMP
        sta TMP+1
        ldx #16
@l:     lsr ARG+1
        ror ARG
        bcc :+
        clc
        lda TMP
        adc ACC
        sta TMP
        lda TMP+1
        adc ACC+1
        sta TMP+1
:       asl ACC
        rol ACC+1
        dex
        bne @l
        lda TMP
        sta ACC
        lda TMP+1
        sta ACC+1
        rts

; 符号付きの割り算。余りは REM(符号は割られる数に合わせる)。
OP_DIV:
        lda ARG
        ora ARG+1
        bne :+
        jmp ERROR
:       lda ACC+1
        sta SIGN
        eor ARG+1
        pha                 ; 商の符号
        lda ACC+1
        bpl :+
        jsr NEGACC
:       lda ARG+1
        bpl :+
        sec
        lda #0
        sbc ARG
        sta ARG
        lda #0
        sbc ARG+1
        sta ARG+1
:       jsr DIVU
        pla
        bpl :+
        jsr NEGACC
:       lda WREM
        sta REM
        lda WREM+1
        sta REM+1
        bit SIGN
        bpl :+
        sec
        lda #0
        sbc REM
        sta REM
        lda #0
        sbc REM+1
        sta REM+1
:       rts

; 符号なし: ACC = ACC / ARG、WREM = 余り
DIVU:
        lda #0
        sta WREM
        sta WREM+1
        ldx #16
@l:     asl ACC
        rol ACC+1
        rol WREM
        rol WREM+1
        lda WREM
        sec
        sbc ARG
        tay
        lda WREM+1
        sbc ARG+1
        bcc :+
        sta WREM+1
        sty WREM
        inc ACC
:       dex
        bne @l
        rts

OP_EQ:
        jsr CMPEQ
        beq TRUE
FALSE:  lda #0
        .byte $2C           ; 次の2バイトを飛ばす(BIT abs)
TRUE:   lda #1
        sta ACC
        lda #0
        sta ACC+1
        rts

OP_NE:
        jsr CMPEQ
        bne TRUE
        beq FALSE

OP_LT:
        jsr LESS
        bcs TRUE
        bcc FALSE

OP_GE:
        jsr LESS
        bcc TRUE
        bcs FALSE

OP_GT:
        jsr SWAP
        jmp OP_LT

OP_LE:
        jsr SWAP
        jmp OP_GE

CMPEQ:
        lda ACC
        cmp ARG
        bne :+
        lda ACC+1
        cmp ARG+1
:       rts

; 符号付きで ACC < ARG なら C=1
LESS:
        lda ACC
        cmp ARG
        lda ACC+1
        sbc ARG+1
        bvc :+
        eor #$80
:       asl a
        rts

SWAP:
        ldx #1
:       lda ACC,x
        ldy ARG,x
        sta ARG,x
        sty ACC,x
        dex
        bpl :-
        rts

NEGACC:
        sec
        lda #0
        sbc ACC
        sta ACC
        lda #0
        sbc ACC+1
        sta ACC+1
        rts

; 項: (式)、-項、10進数、$16進数、$(1文字入力)、?(数値入力)、%項、'項、変数、配列
TERM:
        jsr GETC
        cmp #'('
        bne @t1
        jsr INCTP
        jsr EXPR
        jmp EXPECTRP
@t1:    cmp #'-'
        bne @t2
        jsr INCTP
        jsr TERM
        jmp NEGACC
@t2:    cmp #'0'
        bcc @t3
        cmp #'9'+1
        bcs @t3
        jmp PARSENUM
@t3:    cmp #'$'
        bne @t4
        jsr NEXTC
        jsr ISHEX
        bcc :+
        jmp PARSEHEX
:       jmp INKEY
@t4:    cmp #'?'
        bne @t5
        jsr INCTP
        jmp INNUM
@t5:    cmp #'%'
        bne @t6
        jsr INCTP
        jsr TERM
        lda REM
        sta ACC
        lda REM+1
        sta ACC+1
        rts
@t6:    cmp #$27            ; '
        bne @t7
        jsr INCTP
        jsr TERM
        jmp RND
@t7:    jsr VARADDR
        bcc :+
        jmp ERROR
:       jsr SKIPVAR
        cmp #'('
        beq @w
        cmp #':'
        beq @b
        lda 0,x
        sta ACC
        lda 1,x
        sta ACC+1
        rts
@w:     jsr INCTP
        jsr ARRW
        ldy #1
        lda (PTR2),y
        sta ACC+1
        dey
        lda (PTR2),y
        sta ACC
        rts
@b:     jsr INCTP
        jsr ARRB
        ldy #0
        lda (PTR2),y
        sta ACC
        sty ACC+1
        rts

; 配列の番地: PTR2 = (X の変数の値) + 添字(ARRW は 2 倍)。TP は ( か : の次。
ARRW:
        sec
        .byte $24           ; 次の1バイトを飛ばす(BIT zp)
ARRB:
        clc
        php
        lda 1,x
        pha
        lda 0,x
        pha
        jsr EXPR
        jsr EXPECTRP
        pla
        sta PTR2
        pla
        sta PTR2+1
        plp
        bcc :+
        asl ACC
        rol ACC+1
:       clc
        lda ACC
        adc PTR2
        sta PTR2
        lda ACC+1
        adc PTR2+1
        sta PTR2+1
        rts

; 10進数
PARSENUM:
        lda #0
        sta ACC
        sta ACC+1
@l:     jsr GETC
        cmp #'0'
        bcc @r
        cmp #'9'+1
        bcs @r
        and #$0F
        pha
        lda ACC             ; ACC = ACC * 10
        sta TMP
        lda ACC+1
        sta TMP+1
        asl ACC
        rol ACC+1
        asl ACC
        rol ACC+1
        clc
        lda ACC
        adc TMP
        sta ACC
        lda ACC+1
        adc TMP+1
        sta ACC+1
        asl ACC
        rol ACC+1
        pla
        clc
        adc ACC
        sta ACC
        bcc :+
        inc ACC+1
:       jsr INCTP
        jmp @l
@r:     rts

; 16進数(TP は最初の桁)
PARSEHEX:
        lda #0
        sta ACC
        sta ACC+1
@l:     jsr GETC
        jsr ISHEX
        bcc @r
        cmp #'A'
        bcc :+
        sbc #7
:       and #$0F
        ldx #4
:       asl ACC
        rol ACC+1
        dex
        bne :-
        ora ACC
        sta ACC
        jsr INCTP
        jmp @l
@r:     rts

; 1文字入力(待たない。なければ 0)
INKEY:
        jsr GETBUF
        bne @s
        jsr GETKEY
        cmp #3
        bne @s
        jmp BREAK
@s:     sta ACC
        lda #0
        sta ACC+1
        rts

; 数値入力: 1行を読み、式として評価する
INNUM:
        lda TP+1
        pha
        lda TP
        pha
        lda #<INBUF
        ldy #>INBUF
        jsr GETLINE
        jsr SKIPSP
        jsr EXPR
        pla
        sta TP
        pla
        sta TP+1
        rts

; 乱数: ACC が n なら 1-n(n=0 なら 0)。xorshift 16 ビット(7、9、8)。
RND:
        lda ACC
        ora ACC+1
        beq @r
        lda ACC
        sta ARG
        lda ACC+1
        sta ARG+1
        lda RNDV
        ora RNDV+1
        bne :+
        inc RNDV
:       lda RNDV+1          ; x ^= x << 7
        lsr a
        lda RNDV
        ror a
        eor RNDV+1
        sta RNDV+1
        lda #0
        ror a
        eor RNDV
        sta RNDV
        lda RNDV+1          ; x ^= x >> 9
        lsr a
        eor RNDV
        sta RNDV
        eor RNDV+1          ; x ^= x << 8
        sta RNDV+1
        lda RNDV
        sta ACC
        lda RNDV+1
        sta ACC+1
        jsr DIVU
        clc
        lda WREM
        adc #1
        sta ACC
        lda WREM+1
        adc #0
        sta ACC+1
@r:     rts

; ---- 文字の読み取り ----
INCTP:
        inc TP
        bne :+
        inc TP+1
:       rts

NEXTC:
        jsr INCTP
GETC:
        ldy #0
        lda (TP),y
        rts

SKIPSP:
        jsr GETC
        cmp #' '
        bne :+
        jsr INCTP
        jmp SKIPSP
:       rts

; = を確かめて読み進め、式を評価する
EQEXPR:
        jsr GETC
        cmp #'='
        beq :+
        jmp ERROR
:       jsr INCTP
        jmp EXPR

EXPECTRP:
        jsr GETC
        cmp #')'
        beq :+
        jmp ERROR
:       jmp INCTP

; 変数名の文字を読み進める(英字なら続く英字も)。A = 次の文字。X は変えない。
SKIPVAR:
        jsr GETC
        jsr ISALPHA
        php
        jsr NEXTC
        plp
        bcc @r
@l:     jsr ISALPHA
        bcc @r
        jsr NEXTC
        jmp @l
@r:     rts

; A が英大文字なら C=1
ISALPHA:
        cmp #'A'
        bcc @no
        cmp #'Z'+1
        bcs @no
        sec
        rts
@no:    clc
        rts

; A が 16 進の桁なら C=1
ISHEX:
        cmp #'0'
        bcc @no
        cmp #'9'+1
        bcc @yes
        cmp #'A'
        bcc @no
        cmp #'F'+1
        bcs @no
@yes:   sec
        rts
@no:    clc
        rts

; A の変数のゼロページ番地を X に返す(C=1 なら変数ではない)
VARADDR:
        jsr ISALPHA
        bcc @sp
        sbc #'A'
        asl a
        adc #VARS
        tax
        clc
        rts
@sp:    ldx #3
@l:     cmp SpChr,x
        beq @f
        dex
        bpl @l
        sec
        rts
@f:     lda SpZp,x
        tax
        clc
        rts

; ---- 入出力 ----
; 1行を読む。A/Y = バッファの番地。TP をバッファの先頭にする。
GETLINE:
        sta PTR2
        sta TP
        sty PTR2+1
        sty TP+1
        ldy #0
@l:     jsr INCH
        cmp #$0D
        beq @done
        cmp #3
        bne :+
        jmp BREAK
:       cmp #$08
        beq @bs
        cmp #$7F
        beq @bs
        cmp #' '
        bcc @l
        cpy #120
        bcs @l
        sta (PTR2),y
        jsr OUTCH
        iny
        bne @l
@bs:    cpy #0
        beq @l
        dey
        lda #$08
        jsr OUTCH
        lda #' '
        jsr OUTCH
        lda #$08
        jsr OUTCH
        jmp @l
@done:  sta (PTR2),y
        jsr CRLF

; 文字列と注釈の外の小文字を大文字にする
UPCASE:
        ldy #0
:       lda (PTR2),y
        cmp #' '
        bne :+
        iny
        bne :-
:       ldx #0
@dig:   lda (PTR2),y
        cmp #'0'
        bcc @nd
        cmp #'9'+1
        bcs @nd
        iny
        ldx #1
        bne @dig
@nd:    cpx #0
        beq @conv
        cmp #' '
        beq @conv
        cmp #$0D
        beq @conv
        cmp #'/'
        beq @conv
        rts                 ; 行番号のあとが空白でない行は注釈
@conv:  ldx #0              ; X = 引用符の中なら 1
@cl:    lda (PTR2),y
        cmp #$0D
        beq @r
        cmp #'"'
        bne :+
        txa
        eor #1
        tax
        jmp @nx
:       cpx #0
        bne @nx
        cmp #'a'
        bcc @nx
        cmp #'z'+1
        bcs @nx
        and #$DF
        sta (PTR2),y
@nx:    iny
        bne @cl
@r:     rts

; 1文字入力(待つ)。先打ちのバッファを先に読む。Y は変えない。
INCH:
        jsr GETBUF
        bne :+
        jmp CHRIN
:       rts

; 先打ちのバッファから1文字取り出す。空なら A=0、Z=1。X を壊す。
GETBUF:
        lda #0
        ldx KHEAD
        cpx KTAIL
        beq @r
        lda KBUF,x
        pha
        inx
        txa
        and #$3F
        sta KHEAD
        pla
@r:     rts

; キーが届いていれば1文字読む。Ctrl-C なら中断し、ほかのキーは先打ちのバッファに残す
; (満杯なら捨てる)。X を壊す。
CHKBRK:
        jsr GETKEY
        beq @r
        cmp #3
        bne :+
        jmp BREAK
:       ldx KTAIL
        sta KBUF,x
        inx
        txa
        and #$3F
        cmp KHEAD
        beq @r
        sta KTAIL
@r:     rts

; 1文字出力。A、X、Y は変えない。
OUTCH:
        pha
        jsr CHROUT
        lda #0
        sta COL0
        pla
        cmp #$0A
        bne :+
        inc COL0
:       rts

CRLF:
        lda #$0D
        jsr OUTCH
        lda #$0A
        jmp OUTCH

; A/Y の文字列(0 で終わる)を表示する
PRSTR:
        sta PTR1
        sty PTR1+1
        ldy #0
:       lda (PTR1),y
        beq :+
        jsr OUTCH
        iny
        bne :-
:       rts

; ACC を符号付き 10 進で表示する。PRNUM は A 桁の右詰め。
PRDEC:
        lda #0
PRNUM:
        sta TMP
        ldx #7
        lda ACC+1
        sta SIGN
        bpl @d
        jsr NEGACC
@d:     jsr DIV10
        ora #'0'
        dex
        sta NUMBUF,x
        lda ACC
        ora ACC+1
        bne @d
        lda SIGN
        bpl :+
        dex
        lda #'-'
        sta NUMBUF,x
:       stx TMP+1           ; 桁数 = 7 - X
        lda #7
        sec
        sbc TMP+1
        sta TMP+1
@pad:   lda TMP
        cmp TMP+1
        bcc @out
        beq @out
        lda #' '
        jsr OUTCH
        dec TMP
        jmp @pad
@out:   lda NUMBUF,x
        jsr OUTCH
        inx
        cpx #7
        bne @out
        rts

; ACC = ACC / 10(符号なし)、A = 余り
DIV10:
        lda #0
        ldy #16
@l:     asl ACC
        rol ACC+1
        rol a
        cmp #10
        bcc :+
        sbc #10
        inc ACC
:       dey
        bne @l
        rts

; A を 16 進 2 桁で表示する
PRHEX2:
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        jsr @n
        pla
        and #$0F
@n:     cmp #10
        bcc :+
        adc #6
:       adc #'0'
        jmp OUTCH

; ---- エラーと中断 ----
ERROR:
        ldx #0
        .byte $2C           ; 次の2バイトを飛ばす(BIT abs)
BREAK:
        ldx #MsgBrk-MsgErr
        lda KTAIL           ; 中断したら先打ちのキーを捨てる(ERROR では捨てない)
        cpx #0
        beq :+
        sta KHEAD
:       lda COL0
        bne :+
        jsr CRLF
:       lda MsgErr,x
        beq :+
        jsr OUTCH
        inx
        bne :-
:       lda LINEP+1
        beq @d
        lda #' '
        jsr OUTCH
        ldy #0
        lda (LINEP),y
        sta ACC+1
        iny
        lda (LINEP),y
        sta ACC
        jsr PRDEC
@d:     jsr CRLF
        jmp READY

        .segment "RODATA"
Banner:
        .byte $0D, $0A, "GAME65G V1.0", $0D, $0A
        .byte "BASED ON GAME LANGUAGE (ASCII 1978)", $0D, $0A, 0
MsgErr: .byte "ERR", 0
MsgBrk: .byte "BRK", 0

StmtChr:
        .byte '"', '/', '?', '$', '.', '#', '!', ']', '>', ';', '@', '='
StmtTab:
        .word S_STR-1, CRLF-1, S_PR-1, S_CHR-1, S_TAB-1, S_GOTO-1
        .word S_GOSUB-1, S_RET-1, S_CALL-1, S_IF-1, S_DO-1, S_PROG-1

; 演算子: 0-9 は1文字、10 <>、11 <=、12 >=
OpChr:
        .byte "+-*/&.!=<>"
OpTab:
        .word OP_ADD-1, OP_SUB-1, OP_MUL-1, OP_DIV-1, OP_AND-1, OP_OR-1, OP_XOR-1
        .word OP_EQ-1, OP_LT-1, OP_GT-1, OP_NE-1, OP_LE-1, OP_GE-1

SpChr:  .byte "=&*'"
SpZp:   .byte PSTART, PEND, RAMEND, RNDV
