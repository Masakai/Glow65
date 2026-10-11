; 16-bit addition: SUM = A + B
; Load at $0300 and start with `G 0300`. The program ends with RTS, so the
; monitor prompt comes back.
;
; Each number is two bytes, low byte first (little endian):
;   A   = $03F0 (low), $03F1 (high)
;   B   = $03F2 (low), $03F3 (high)
;   SUM = $03F4 (low), $03F5 (high)

        .setcpu "6502"

A_LO   = $03F0
A_HI   = $03F1
B_LO   = $03F2
B_HI   = $03F3
SUM_LO = $03F4
SUM_HI = $03F5

        clc             ; clear the carry flag: there is no carry into the low byte
        lda A_LO        ; low bytes first
        adc B_LO        ; A = A_LO + B_LO (+ carry, which is 0)
        sta SUM_LO
        lda A_HI        ; then the high bytes
        adc B_HI        ; A = A_HI + B_HI + the carry left over from the low bytes
        sta SUM_HI
        rts             ; back to the monitor
