; Glow65 モニタ ROM(自作)
;
; 配置: $F000-$FFFF(4KB)。先頭にジャンプテーブル、末尾にベクタを置く。
; $C000-$EFFF は BASIC(ROM/basic)に割り当てる。
; コマンド:
;   D aaaa [bbbb]    メモリダンプ(省略時は128バイト)
;   E aaaa bb bb ..  メモリ書き込み
;   G aaaa           JSR で実行(RTS で戻るとモニタに戻る)
;   B                BASIC をコールドスタート($C000)
;   ?                ヘルプ

        .setcpu "6502"
        .macpack longbranch

UART_CTRL = $A000       ; bit0=RDRF, bit1=TDRE
UART_DATA = $A001
BUF       = $0200       ; 行入力バッファ
BASIC     = $C000       ; BASIC のコールドスタート

PTR       = $F0         ; 2バイト: 現在アドレス
ENDP      = $F2         ; 2バイト: 終了アドレス
VAL       = $F4         ; 2バイト: 解析した16進値
IDX       = $F6         ; 入力バッファ内の読み取り位置
TMP       = $F7
STR       = $F8         ; 2バイト: 文字列ポインタ

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
        lda #<Banner
        ldy #>Banner
        jsr PRSTR
MONITOR:
        ldx #$FF
        txs
        cld
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

NMI_ISR:
IRQ_ISR:
        rti

        .segment "RODATA"
Banner:
        .byte $0D, $0A, "GLOW65 MONITOR  (? = HELP)", $0D, $0A, 0
HelpText:
        .byte "D AAAA [BBBB]  DUMP", $0D, $0A
        .byte "E AAAA BB ..   WRITE", $0D, $0A
        .byte "G AAAA         GO", $0D, $0A
        .byte "B              BASIC", $0D, $0A, 0

        .segment "VECTORS"
        .word NMI_ISR
        .word RESET
        .word IRQ_ISR
