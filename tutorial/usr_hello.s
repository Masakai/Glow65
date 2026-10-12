; USR(0) prints a message through the monitor's CHROUT routine.
; Load at $0300, tell BASIC with  POKE 11,0 : POKE 12,3  and call it with  A=USR(0)
; The FAC is not touched, so the value of A stays what the argument was.

        .setcpu "6502"

CHROUT = $F003

        ldx #$00
next:   lda message,x
        beq done
        jsr CHROUT
        inx
        jmp next
done:   rts

message:
        .byte "HELLO FROM ASSEMBLY", $0D, $0A, $00
