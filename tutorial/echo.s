; Echo: read characters from the UART and send them back. Press Enter to finish.
; Load at $0300 and start with `G 0300`. The program ends with RTS, so the
; monitor prompt comes back.
;
; UART registers:
;   $A000 status: bit 0 = a received character is waiting
;                 bit 1 = ready to send
;   $A001 data:   read = the received character, write = send a character

        .setcpu "6502"

UART_STATUS = $A000
UART_DATA   = $A001
CHROUT      = $F003             ; the monitor's "send A" routine

loop:   lda UART_STATUS
        and #$01                ; has a character arrived?
        beq loop                ; no: look again
        lda UART_DATA           ; yes: read it (this also removes it from the UART)
        cmp #$0D                ; is it Enter?
        beq done                ; yes: finish
        tay                     ; keep the character in Y
send:   lda UART_STATUS
        and #$02                ; ready to send?
        beq send                ; no: look again
        tya
        sta UART_DATA           ; send it back
        jmp loop

done:   lda #$0D                ; send a line break so the prompt starts on a new line
        jsr CHROUT
        lda #$0A
        jsr CHROUT
        rts
