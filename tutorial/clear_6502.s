; Clear a 16-byte area, then count a 16-bit value up to $0300. Plain 6502 version.
; Load at $0300 and start with `G 0300` in the monitor.

        .setcpu "6502"

BUF   = $03D0           ; the 16-byte area to clear ($03D0-$03DF)
COUNT = $03F0           ; 16-bit counter: low byte at $03F0, high byte at $03F1

        ldx #$0F        ; X = 15: index of the last byte of the area
        lda #$00        ; a 6502 cannot store a constant: A must hold the 0
clr:    sta BUF,x       ; clear one byte
        dex
        bpl clr         ; repeat until X wraps from 0 to $FF
        sta COUNT       ; A is still 0
loop:   cmp #$03        ; A = high byte of the count: finished?
        beq done
        inc COUNT       ; low byte + 1
        bne loop        ; no wrap: next
        clc             ; the low byte wrapped: high byte + 1
        adc #$01
        jmp loop        ; the 6502 has no unconditional short branch
done:   sta COUNT+1
        rts
