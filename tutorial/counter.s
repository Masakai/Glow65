; LED counter: add 1 to A forever and write it to memory.
; Load at $0300 and start with `G 0300` in the monitor.

        .setcpu "6502"

COUNTER = $03F0         ; the memory cell that holds the count

        lda #$00        ; A = 0
loop:   sta COUNTER     ; write A to memory (the data bus shows it)
        clc             ; clear the carry flag before adding
        adc #$01        ; A = A + 1
        jmp loop        ; do it again, forever
