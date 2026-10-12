; Echo in capital letters: the same as echo.s, but a-z become A-Z.
; Load at $0300 and start with `G 0300`. Press Enter to finish.

        .setcpu "6502"

UART_STATUS = $A000
UART_DATA   = $A001
CHROUT      = $F003

loop:   lda UART_STATUS
        and #$01
        beq loop
        lda UART_DATA
        cmp #$0D
        beq done
        cmp #$61                ; 'a'
        bcc send_it             ; below 'a': leave it alone
        cmp #$7B                ; one past 'z'
        bcs send_it             ; 'z' or above: leave it alone
        and #$DF                ; clear bit 5: 'a'-'z' ($61-$7A) become 'A'-'Z' ($41-$5A)
send_it:
        tay
send:   lda UART_STATUS
        and #$02
        beq send
        tya
        sta UART_DATA
        jmp loop

done:   lda #$0D
        jsr CHROUT
        lda #$0A
        jsr CHROUT
        rts
