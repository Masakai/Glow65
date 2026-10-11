; The same message, using the monitor's CHROUT routine ($F003).
; CHROUT waits until the UART is ready and then sends the character in A,
; so the waiting loop of hello.s is not needed.

        .setcpu "6502"

CHROUT = $F003

        ldx #$00
next:   lda message,x
        beq done
        jsr CHROUT          ; the monitor does the waiting and the sending
        inx
        jmp next
done:   rts

message:
        .byte "HELLO, GLOW65", $0D, $0A, $00
