; Glow65 モニタ ROM(自作)
;
; 配置: $F000-$FFFF(4KB)。先頭にジャンプテーブル、末尾にベクタを置く。
; $C000-$EFFF は BASIC(ROM/basic)に割り当てる。
; コマンド:
;   D aaaa [bbbb]    メモリダンプ(省略時は128バイト)
;   E aaaa bb bb ..  メモリ書き込み
;   L aaaa [bbbb]    逆アセンブル(終了アドレス省略時は16命令。65C02 なら追加の命令も表示)
;   G aaaa           JSR で実行(RTS で戻るとモニタに戻る)
;   B                BASIC をコールドスタート($C000)
;   ?                ヘルプ

        .setcpu "6502"
        .macpack longbranch

UART_CTRL = $A000       ; bit0=RDRF, bit1=TDRE
UART_DATA = $A001
BUF       = $0200       ; 行入力バッファ
BASIC     = $C000       ; BASIC のコールドスタート
NMIVEC    = $03F8       ; NMI のハンドラアドレス(RAM。ユーザーが書き換える)
IRQVEC    = $03FA       ; IRQ/BRK のハンドラアドレス(同上)

PTR       = $F0         ; 2バイト: 現在アドレス
ENDP      = $F2         ; 2バイト: 終了アドレス
VAL       = $F4         ; 2バイト: 解析した16進値
IDX       = $F6         ; 入力バッファ内の読み取り位置
TMP       = $F7
STR       = $F8         ; 2バイト: 文字列ポインタ

; 逆アセンブラの作業領域(DB1 と DB2 は連続させる)
DOP       = $FA         ; オペコード
DMN       = $FB         ; ニーモニックの番号($FF = 未定義命令)
DMODE     = $FC         ; アドレッシングモード番号
DLEN      = $FD         ; 命令の長さ(1-3)
DB1       = $FE         ; 第1オペランドバイト
DB2       = $FF         ; 第2オペランドバイト
DCNT      = TMP         ; 表示する命令数(0 = 終了アドレスまで)

        .segment "CODE"

; ---- 固定ジャンプテーブル($F000) ----
        jmp CHRIN       ; $F000: 1文字入力(待つ)A=文字
        jmp CHROUT      ; $F003: 1文字出力 A=文字
        jmp ISCNTC      ; $F006: キー確認(待たない)
        jmp MONITOR     ; $F009: モニタのウォームスタート
        jmp GETKEY      ; $F00C: 待たずに1文字読む(なければ A=0)

; ---- 入出力 ----
CHRIN:
        lda UART_CTRL
        and #$01
        beq CHRIN
        lda UART_DATA
        rts

; キーが押されていれば A=文字、なければ A=0(待たない)
GETKEY:
        lda UART_CTRL
        and #$01
        beq @none
        lda UART_DATA
        rts
@none:  lda #0
        rts

CHROUT:
        pha
:       lda UART_CTRL
        and #$02
        beq :-
        pla
        and #$7F            ; 端末は7ビット ASCII(BASIC は最上位ビットを区切りに使う)
        sta UART_DATA
        rts

; キーが押されていれば読み取り、Ctrl-C なら C=1、それ以外は C=0 で戻る。
ISCNTC:
        lda UART_CTRL
        and #$01
        beq @no
        lda UART_DATA
        cmp #$03
        beq @yes
@no:    clc
        rts
@yes:   sec
        rts

CRLF:
        lda #$0D
        jsr CHROUT
        lda #$0A
        jmp CHROUT

; A=下位, Y=上位 の文字列(0終端、256バイト未満)を出力
PRSTR:
        sta STR
        sty STR+1
        ldy #0
:       lda (STR),y
        beq @end
        jsr CHROUT
        iny
        bne :-
@end:   rts

PRHEX:
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        jsr PRNIB
        pla
        and #$0F
PRNIB:
        ora #$30
        cmp #$3A
        bcc :+
        adc #$06
:       jmp CHROUT

; ---- 行入力(小文字は大文字に変換、BS 対応) ----
GETLINE:
        ldy #0
@loop:  jsr CHRIN
        cmp #$0D
        beq @done
        cmp #$08
        beq @bs
        cmp #$7F
        beq @bs
        cmp #$20
        bcc @loop
        cmp #'a'
        bcc @store
        cmp #'z'+1
        bcs @store
        and #$DF
@store: cpy #$7F
        bcs @loop
        sta BUF,y
        iny
        jsr CHROUT
        jmp @loop
@bs:    cpy #0
        beq @loop
        dey
        lda #$08
        jsr CHROUT
        lda #' '
        jsr CHROUT
        lda #$08
        jsr CHROUT
        jmp @loop
@done:  lda #0
        sta BUF,y
        jmp CRLF

; ---- 解析 ----
; 空白を読み飛ばし、A=次の文字(Z で行末を判定)、Y=IDX で戻る
SKIPSP:
        ldy IDX
:       lda BUF,y
        cmp #' '
        bne :+
        iny
        bne :-
:       sty IDX
        lda BUF,y
        rts

; A の ASCII を 0-15 に変換。16進でなければ C=1
HEXVAL:
        cmp #'0'
        bcc @bad
        cmp #'9'+1
        bcc @dec
        cmp #'A'
        bcc @bad
        cmp #'F'+1
        bcs @bad
        sbc #'A'-11
        clc
        rts
@dec:   sbc #'0'-1
        clc
        rts
@bad:   sec
        rts

; 16進数を読み取って VAL に格納。1桁もなければ C=1
PARSEHEX:
        jsr SKIPSP
        lda #0
        sta VAL
        sta VAL+1
        sta TMP
:       lda BUF,y
        jsr HEXVAL
        bcs @end
        ldx #4
@sh:    asl VAL
        rol VAL+1
        dex
        bne @sh
        ora VAL
        sta VAL
        inc TMP
        iny
        bne :-
@end:   sty IDX
        lda TMP
        beq @none
        clc
        rts
@none:  sec
        rts

VAL_TO_PTR:
        lda VAL
        sta PTR
        lda VAL+1
        sta PTR+1
        rts

; ---- モニタ本体 ----
RESET:
        sei
        cld
        ldx #$FF
        txs
        lda #$03            ; UART マスタリセット
        sta UART_CTRL
        lda #<DEFISR        ; 割り込みベクタを RTI だけのハンドラにしておく
        sta NMIVEC
        sta IRQVEC
        lda #>DEFISR
        sta NMIVEC+1
        sta IRQVEC+1
        lda #<Banner
        ldy #>Banner
        jsr PRSTR
MONITOR:
        ldx #$FF
        txs
        cld
        lda #$00            ; UART の受信割り込みを切る(マスタリセットはしない)
        sta UART_CTRL
CMDLOOP:
        lda #'*'
        jsr CHROUT
        jsr GETLINE
        lda #0
        sta IDX
        jsr SKIPSP
        beq CMDLOOP
        inc IDX
        cmp #'D'
        bne :+
        jmp CMD_D
:       cmp #'E'
        bne :+
        jmp CMD_E
:       cmp #'G'
        bne :+
        jmp CMD_G
:       cmp #'L'
        bne :+
        jmp CMD_L
:       cmp #'B'
        bne :+
        jmp BASIC
:       cmp #'?'
        jne ERR
        lda #<HelpText
        ldy #>HelpText
        jsr PRSTR
        jmp CMDLOOP

ERR:
        lda #'?'
        jsr CHROUT
        jsr CRLF
        jmp CMDLOOP

CMD_D:
        jsr PARSEHEX
        jcs ERR
        jsr VAL_TO_PTR
        jsr PARSEHEX
        bcs @default
        lda VAL
        sta ENDP
        lda VAL+1
        sta ENDP+1
        jmp @line
@default:
        clc
        lda PTR
        adc #$7F
        sta ENDP
        lda PTR+1
        adc #0
        sta ENDP+1
@line:  lda PTR+1
        jsr PRHEX
        lda PTR
        jsr PRHEX
        lda #':'
        jsr CHROUT
        ldy #0
@byte:  lda #' '
        jsr CHROUT
        lda (PTR),y
        jsr PRHEX
        iny
        cpy #16
        bne @byte
        jsr CRLF
        clc
        lda PTR
        adc #16
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        bcs @done
        sec
        lda ENDP
        sbc PTR
        lda ENDP+1
        sbc PTR+1
        bcc @done
        jmp @line
@done:  jmp CMDLOOP

CMD_E:
        jsr PARSEHEX
        jcs ERR
        jsr VAL_TO_PTR
@next:  jsr PARSEHEX
        bcs @done
        lda VAL
        ldy #0
        sta (PTR),y
        inc PTR
        bne @next
        inc PTR+1
        jmp @next
@done:  jmp CMDLOOP

CMD_G:
        jsr PARSEHEX
        jcs ERR
        jsr @call
        jmp MONITOR
@call:  jmp (VAL)

; ---- 逆アセンブル: L aaaa [bbbb] ----
CMD_L:
        jsr PARSEHEX
        jcs ERR
        jsr VAL_TO_PTR
        jsr PARSEHEX            ; PARSEHEX は TMP(= DCNT)を使うので、DCNT はこのあとに設定する
        bcs @default
        lda VAL
        sta ENDP
        lda VAL+1
        sta ENDP+1
        lda #0                  ; 0 = 終了アドレスまで
        sta DCNT
        beq @loop
@default:
        lda #16                 ; 終了アドレスがなければ 16 命令
        sta DCNT
@loop:  jsr DISASM_ONE
        bcs @done               ; $FFFF を越えたら終わり
        lda DCNT
        beq @range
        dec DCNT
        bne @loop
        beq @done
@range: sec                     ; ENDP >= PTR の間つづける
        lda ENDP
        sbc PTR
        lda ENDP+1
        sbc PTR+1
        bcs @loop
@done:  jmp CMDLOOP

; PTR の命令を1つ表示し、PTR を次の命令に進める。$FFFF を越えたら C=1 で戻る。
DISASM_ONE:
        lda PTR+1
        jsr PRHEX
        lda PTR
        jsr PRHEX
        lda #' '
        jsr CHROUT
        jsr CHROUT
        ldy #0
        lda (PTR),y
        sta DOP
        tax
        jsr ISCMOS              ; 65C02 なら C=1(命令ごとに判定する。状態を持たなくてよい)
        bcs @cmos
        lda OPMN,x
        sta DMN
        lda OPMODE,x
        sta DMODE
        jmp @got
@cmos:  lda OPMN65,x
        sta DMN
        lda OPMODE65,x
        sta DMODE
@got:   lda DMN
        cmp #$FF
        bne @legal
        lda #3                  ; 未定義命令は「.BYTE $xx」(1バイト)として表示する
        sta DMODE
        lda DOP
        sta DB1
        lda #1
        sta DLEN
        bne @show
@legal: ldx DMODE
        lda MODELEN,x
        sta DLEN
        cmp #2
        bcc @show
        ldy #1                  ; オペランドは、命令の長さの分だけ読む(I/O を無駄に読まない)
        lda (PTR),y
        sta DB1
        lda DLEN
        cmp #3
        bcc @show
        iny
        lda (PTR),y
        sta DB2
@show:  lda DOP
        jsr PRHEX
        lda #' '
        jsr CHROUT
        ldx #1                  ; オペランドバイトの欄(2つ)
@col:   cpx DLEN
        bcs @blank
        lda DB1-1,x
        jsr PRHEX
        lda #' '
        jsr CHROUT
        jmp @next
@blank: lda #' '
        jsr CHROUT
        jsr CHROUT
        jsr CHROUT
@next:  inx
        cpx #3
        bcc @col
        lda #' '
        jsr CHROUT
        jsr DIS_MNEMONIC
        jsr DIS_OPERAND
        jsr CRLF
        clc
        lda PTR
        adc DLEN
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        rts                     ; C = $FFFF を越えたか

; CPU が 65C02 なら C=1、NMOS 6502 なら C=0 で戻る(A だけ壊す)。
; $1A は 65C02 では INC A、NMOS では 1 バイトの未定義 NOP(A は変わらない)。
ISCMOS:
        lda #0
        .byte $1A
        cmp #1
        rts

; ニーモニックを 6 文字の欄に表示する
DIS_MNEMONIC:
        lda DMN
        cmp #$FF
        bne @mn
        lda #'.'
        jsr CHROUT
        lda #'B'
        jsr CHROUT
        lda #'Y'
        jsr CHROUT
        lda #'T'
        jsr CHROUT
        lda #'E'
        jsr CHROUT
        lda #' '
        jmp CHROUT
@mn:    asl a                   ; 番号 x 3
        clc
        adc DMN
        tax
        lda MNEM,x
        jsr CHROUT
        lda MNEM+1,x
        jsr CHROUT
        lda MNEM+2,x
        jsr CHROUT
        lda DMN
        cmp #BITOP_FIRST
        bcc @plain
        lda DOP                 ; RMB/SMB/BBR/BBS は、ビット番号(オペコードの bit4-6)を続けて表示
        lsr a
        lsr a
        lsr a
        lsr a
        and #$07
        ora #'0'
        jsr CHROUT
        lda #' '
        jsr CHROUT
        jmp CHROUT
@plain: lda #' '
        jsr CHROUT
        jsr CHROUT
        jmp CHROUT

; オペランドを、モードに応じた書式で表示する
DIS_OPERAND:
        ldx DMODE
        lda MPRE,x
        beq @nopre
        jsr CHROUT
@nopre: lda MSIZE,x
        beq @suffix
        pha
        lda #'$'
        jsr CHROUT
        pla
        cmp #4
        beq @zprel
        cmp #3
        beq @rel
        cmp #2
        bne @one
        lda DB2
        jsr PRHEX
@one:   lda DB1
        jsr PRHEX
        jmp @suffix
@rel:   lda DB1                 ; 分岐先 = この命令のアドレス + 2 + 符号付きオフセット
        ldx #2
        jsr PRTARGET
        jmp @suffix
@zprel: lda DB1                 ; BBR/BBS: ゼロページのアドレス、続けて分岐先(命令のアドレス + 3 + オフセット)
        jsr PRHEX
        lda #','
        jsr CHROUT
        lda #'$'
        jsr CHROUT
        lda DB2
        ldx #3
        jsr PRTARGET
@suffix:
        lda DMODE               ; 添字 = モード番号 x 3
        asl a
        clc
        adc DMODE
        tax
        ldy #3
@sl:    lda MSUF,x
        beq @end
        jsr CHROUT
        inx
        dey
        bne @sl
@end:   rts

; 分岐先を4桁の16進で表示する。A=符号付きオフセット、X=命令の長さ。
; 分岐先 = PTR + X + オフセット
PRTARGET:
        tay
        txa
        clc
        adc PTR
        sta VAL
        lda #0
        adc PTR+1
        sta VAL+1
        ldx #0                  ; オフセットの符号拡張(上位バイト)
        cpy #$80
        bcc @pos
        dex
@pos:   tya
        clc
        adc VAL
        sta VAL
        txa
        adc VAL+1
        sta VAL+1
        jsr PRHEX               ; A = 上位バイト
        lda VAL
        jmp PRHEX

; NMI/IRQ は RAM のベクタ経由でユーザーのハンドラへ飛ぶ
NMI_ISR:
        jmp (NMIVEC)
IRQ_ISR:
        jmp (IRQVEC)
DEFISR:
        rti

        .segment "RODATA"
Banner:
        .byte $0D, $0A, "GLOW65 MONITOR  (? = HELP)", $0D, $0A, 0
HelpText:
        .byte "D AAAA [BBBB]  DUMP", $0D, $0A
        .byte "E AAAA BB ..   WRITE", $0D, $0A
        .byte "L AAAA [BBBB]  LIST", $0D, $0A
        .byte "G AAAA         GO", $0D, $0A
        .byte "B              BASIC", $0D, $0A, 0

; ---- 逆アセンブラの表 ----
; MNEM、OPMN、OPMODE、OPMN65、OPMODE65 は Tools/gen_disasm_tables.py が CPU コアの表から生成する。
        .include "disasm_tables.inc"

; モード番号 → 命令の長さ
MODELEN:
        .byte 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 3, 3
; モード番号 → オペランドの前に付ける文字(0 = なし)
MPRE:
        .byte 0, 'A', '#', 0, 0, 0, 0, 0, 0, '(', '(', '(', 0, '(', '(', 0
; モード番号 → オペランドの桁数(0 = なし、1 = 2桁、2 = 4桁、3 = 相対分岐、4 = ゼロページ + 相対分岐)
MSIZE:
        .byte 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 3, 1, 2, 4
; モード番号 → オペランドの後ろに付ける文字(3 文字ずつ、0 で終わり)
MSUF:
        .byte 0, 0, 0               ; 0 implied
        .byte 0, 0, 0               ; 1 accumulator
        .byte 0, 0, 0               ; 2 immediate
        .byte 0, 0, 0               ; 3 zeroPage
        .byte ",X", 0               ; 4 zeroPageX
        .byte ",Y", 0               ; 5 zeroPageY
        .byte 0, 0, 0               ; 6 absolute
        .byte ",X", 0               ; 7 absoluteX
        .byte ",Y", 0               ; 8 absoluteY
        .byte ")", 0, 0             ; 9 indirect
        .byte ",X)"                 ; 10 indexedIndirect
        .byte "),Y"                 ; 11 indirectIndexed
        .byte 0, 0, 0               ; 12 relative
        .byte ")", 0, 0             ; 13 zeroPageIndirect
        .byte ",X)"                 ; 14 absoluteIndexedIndirect
        .byte 0, 0, 0               ; 15 zeroPageRelative

        .segment "VECTORS"
        .word NMI_ISR
        .word RESET
        .word IRQ_ISR
