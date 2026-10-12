; Interrupt-driven echo: the UART raises IRQ for every received character and the
; handler echoes it. Meanwhile the main program counts in a 16-bit counter.
; Load at $0300 and start with `G 0300`. Type anything; press Enter to finish.
; Afterwards `D 03F0 03F2` shows the counter ($03F0 low, $03F1 high) and the flag.

        .setcpu "6502"

UART_STATUS = $A000
UART_DATA   = $A001
CHROUT      = $F003
IRQVEC      = $03FA             ; the monitor's IRQ vector in RAM
COUNTL      = $03F0
COUNTH      = $03F1
DONE        = $03F2

start:  sei                     ; no interrupts while we set up
        lda #<handler
        sta IRQVEC
        lda #>handler
        sta IRQVEC+1
        lda #$00
        sta COUNTL
        sta COUNTH
        sta DONE
        lda #$80                ; UART control bit 7: raise IRQ when a character arrives
        sta UART_STATUS
        cli                     ; let the CPU accept IRQ

main:   inc COUNTL              ; the main program: count while waiting
        bne check
        inc COUNTH
check:  lda DONE
        beq main

        sei                     ; finished: stop the UART interrupt and tidy up
        lda #$00
        sta UART_STATUS
        lda #$0D
        jsr CHROUT
        lda #$0A
        jsr CHROUT
        rts

handler:
        pha                     ; save A (the CPU saved only PC and P)
        lda UART_DATA           ; reading the data register clears the IRQ request
        cmp #$0D
        beq enter
        pha                     ; keep the character while we poll
wait:   lda UART_STATUS
        and #$02
        beq wait
        pla
        sta UART_DATA           ; echo
        pla
        rti
enter:  sta DONE                ; A = $0D, not zero: tell the main program to stop
        pla
        rti
