; NMI counter: every press of the panel's NMI button runs the handler,
; which adds 1 to COUNT and prints "!". The main program only spins.
; Load at $0300 and start with `G 0300`. Press RESET to stop, then `D 03F0 03F0`.

        .setcpu "6502"

UART_STATUS = $A000
UART_DATA   = $A001
NMIVEC      = $03F8             ; the monitor's NMI vector in RAM
COUNT       = $03F0

start:  lda #<handler           ; point the NMI vector at our handler
        sta NMIVEC
        lda #>handler
        sta NMIVEC+1
        lda #$00
        sta COUNT
loop:   jmp loop                ; the main program does nothing

handler:
        pha                     ; the CPU saved only PC and P: save A ourselves
        inc COUNT
wait:   lda UART_STATUS
        and #$02                ; transmit ready?
        beq wait
        lda #'!'
        sta UART_DATA
        pla
        rti                     ; restores P and PC (and the I flag with it)
