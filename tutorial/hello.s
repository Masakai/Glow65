; Print "HELLO, GLOW65" by talking to the UART directly.
; Load at $0300 and start with `G 0300`. The program ends with RTS, so the
; monitor prompt comes back.
;
; UART registers:
;   $A000 status: bit 1 = transmit register empty (ready for the next character)
;   $A001 data:   write a character here to send it

        .setcpu "6502"

UART_STATUS = $A000
UART_DATA   = $A001

        ldx #$00            ; X = index into the message
next:   lda message,x       ; fetch the next character
        beq done            ; a 0 byte marks the end of the message
        tay                 ; keep the character in Y while we check the UART
wait:   lda UART_STATUS
        and #$02            ; is the transmit register empty?
        beq wait            ; no: look again
        tya                 ; yes: get the character back
        sta UART_DATA       ; send it
        inx
        jmp next
done:   rts

message:
        .byte "HELLO, GLOW65", $0D, $0A, $00
