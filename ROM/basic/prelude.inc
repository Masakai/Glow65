; 元ソースが `SEARCH M6502` で読み込むライブラリに相当するマクロ(ca65 版)。
        .setcpu "6502"
        .include "board.inc"

; 即値
.macro LDAI v
        lda #(v)
.endmacro
.macro LDXI v
        ldx #(v)
.endmacro
.macro LDYI v
        ldy #(v)
.endmacro
.macro CMPI v
        cmp #(v)
.endmacro
.macro CPXI v
        cpx #(v)
.endmacro
.macro CPYI v
        cpy #(v)
.endmacro
.macro ADCI v
        adc #(v)
.endmacro
.macro SBCI v
        sbc #(v)
.endmacro
.macro ANDI v
        and #(v)
.endmacro
.macro ORAI v
        ora #(v)
.endmacro
.macro EORI v
        eor #(v)
.endmacro

; (ゼロページ),Y
.macro LDADY v
        lda (v),y
.endmacro
.macro STADY v
        sta (v),y
.endmacro
.macro CMPDY v
        cmp (v),y
.endmacro
.macro ADCDY v
        adc (v),y
.endmacro
.macro SBCDY v
        sbc (v),y
.endmacro

; 間接ジャンプ
.macro JMPD v
        jmp (v)
.endmacro

; 文字列を出力し、最後の1文字だけ最上位ビットを立てる(DC)
.macro DC s
        .repeat .strlen(s)-1, i
        .byte .strat(s, i)
        .endrepeat
        .byte .strat(s, .strlen(s)-1) | $80
.endmacro
