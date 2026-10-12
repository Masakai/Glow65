; The same program as clear_6502.s, written for the 65C02.
; Load at $0300 on a 65C02 machine (--cpu 65c02) and start with `G 0300`.

        .setcpu "65C02"

BUF   = $03D0           ; the 16-byte area to clear ($03D0-$03DF)
COUNT = $03F0           ; 16-bit counter: low byte at $03F0, high byte at $03F1

        ldx #$0F        ; X = 15: index of the last byte of the area
clr:    stz BUF,x       ; STZ stores a zero without using A
        dex
        bpl clr         ; repeat until X wraps from 0 to $FF
        stz COUNT       ; the low byte of the count
        lda #$00        ; A = high byte of the count
loop:   cmp #$03        ; finished?
        beq done
        inc COUNT       ; low byte + 1
        bne loop        ; no wrap: next
        inc a           ; the low byte wrapped: INC A adds 1 to A
        bra loop        ; BRA: unconditional branch, 2 bytes
done:   sta COUNT+1
        rts
