; USR(X) returns X * 2. Load at $0300 and tell BASIC where it is:
;     POKE 11,0 : POKE 12,3      (the address $0300 = low byte 0, high byte 3)
; then:  PRINT USR(21)
;
; BASIC gives the argument to the routine in the floating-point accumulator (FAC),
; and takes the result from the FAC when the routine returns. BASIC provides two
; helper routines, reached through vectors in page zero:
;   (ADRAYI) turns the FAC into a 16-bit integer: high byte in FACMO, low byte in FACLO
;   (ADRGAY) turns an integer (A = high byte, Y = low byte) into the FAC

        .setcpu "6502"

ADRAYI = $06            ; vector to BASIC's "FAC to integer" routine
ADRGAY = $08            ; vector to BASIC's "integer to FAC" routine
FACMO  = $B4            ; integer high byte (after the FAC-to-integer call)
FACLO  = $B5            ; integer low byte

        jsr to_integer  ; the argument, as an integer, is now in FACMO:FACLO
        asl FACLO       ; shift the low byte left; bit 7 goes into the carry
        rol FACMO       ; rotate the carry into the high byte: 16-bit X * 2
        lda FACMO       ; A = high byte
        ldy FACLO       ; Y = low byte
        jsr to_fac      ; put the integer back into the FAC: BASIC sees it as the result
        rts

to_integer:
        jmp (ADRAYI)
to_fac: jmp (ADRGAY)
