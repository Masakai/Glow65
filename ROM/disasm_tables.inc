; Tools/gen_disasm_tables.py が生成する。直接編集しない。
; 元データ: Sources/Core6502/OpcodeTable.swift(公式 151 命令)

; アドレッシングモード番号: 0=implied, 1=accumulator, 2=immediate, 3=zeroPage, 4=zeroPageX, 5=zeroPageY, 6=absolute, 7=absoluteX, 8=absoluteY, 9=indirect, 10=indexedIndirect, 11=indirectIndexed, 12=relative
MNEM:
        .byte "ADC"
        .byte "AND"
        .byte "ASL"
        .byte "BCC"
        .byte "BCS"
        .byte "BEQ"
        .byte "BIT"
        .byte "BMI"
        .byte "BNE"
        .byte "BPL"
        .byte "BRK"
        .byte "BVC"
        .byte "BVS"
        .byte "CLC"
        .byte "CLD"
        .byte "CLI"
        .byte "CLV"
        .byte "CMP"
        .byte "CPX"
        .byte "CPY"
        .byte "DEC"
        .byte "DEX"
        .byte "DEY"
        .byte "EOR"
        .byte "INC"
        .byte "INX"
        .byte "INY"
        .byte "JMP"
        .byte "JSR"
        .byte "LDA"
        .byte "LDX"
        .byte "LDY"
        .byte "LSR"
        .byte "NOP"
        .byte "ORA"
        .byte "PHA"
        .byte "PHP"
        .byte "PLA"
        .byte "PLP"
        .byte "ROL"
        .byte "ROR"
        .byte "RTI"
        .byte "RTS"
        .byte "SBC"
        .byte "SEC"
        .byte "SED"
        .byte "SEI"
        .byte "STA"
        .byte "STX"
        .byte "STY"
        .byte "TAX"
        .byte "TAY"
        .byte "TSX"
        .byte "TXA"
        .byte "TXS"
        .byte "TYA"

OPMN:
        .byte $0A, $22, $FF, $FF, $FF, $22, $02, $FF, $24, $22, $02, $FF, $FF, $22, $02, $FF
        .byte $09, $22, $FF, $FF, $FF, $22, $02, $FF, $0D, $22, $FF, $FF, $FF, $22, $02, $FF
        .byte $1C, $01, $FF, $FF, $06, $01, $27, $FF, $26, $01, $27, $FF, $06, $01, $27, $FF
        .byte $07, $01, $FF, $FF, $FF, $01, $27, $FF, $2C, $01, $FF, $FF, $FF, $01, $27, $FF
        .byte $29, $17, $FF, $FF, $FF, $17, $20, $FF, $23, $17, $20, $FF, $1B, $17, $20, $FF
        .byte $0B, $17, $FF, $FF, $FF, $17, $20, $FF, $0F, $17, $FF, $FF, $FF, $17, $20, $FF
        .byte $2A, $00, $FF, $FF, $FF, $00, $28, $FF, $25, $00, $28, $FF, $1B, $00, $28, $FF
        .byte $0C, $00, $FF, $FF, $FF, $00, $28, $FF, $2E, $00, $FF, $FF, $FF, $00, $28, $FF
        .byte $FF, $2F, $FF, $FF, $31, $2F, $30, $FF, $16, $FF, $35, $FF, $31, $2F, $30, $FF
        .byte $03, $2F, $FF, $FF, $31, $2F, $30, $FF, $37, $2F, $36, $FF, $FF, $2F, $FF, $FF
        .byte $1F, $1D, $1E, $FF, $1F, $1D, $1E, $FF, $33, $1D, $32, $FF, $1F, $1D, $1E, $FF
        .byte $04, $1D, $FF, $FF, $1F, $1D, $1E, $FF, $10, $1D, $34, $FF, $1F, $1D, $1E, $FF
        .byte $13, $11, $FF, $FF, $13, $11, $14, $FF, $1A, $11, $15, $FF, $13, $11, $14, $FF
        .byte $08, $11, $FF, $FF, $FF, $11, $14, $FF, $0E, $11, $FF, $FF, $FF, $11, $14, $FF
        .byte $12, $2B, $FF, $FF, $12, $2B, $18, $FF, $19, $2B, $21, $FF, $12, $2B, $18, $FF
        .byte $05, $2B, $FF, $FF, $FF, $2B, $18, $FF, $2D, $2B, $FF, $FF, $FF, $2B, $18, $FF

OPMODE:
        .byte $00, $0A, $00, $00, $00, $03, $03, $00, $00, $02, $01, $00, $00, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
        .byte $06, $0A, $00, $00, $03, $03, $03, $00, $00, $02, $01, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
        .byte $00, $0A, $00, $00, $00, $03, $03, $00, $00, $02, $01, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
        .byte $00, $0A, $00, $00, $00, $03, $03, $00, $00, $02, $01, $00, $09, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
        .byte $00, $0A, $00, $00, $03, $03, $03, $00, $00, $00, $00, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $04, $04, $05, $00, $00, $08, $00, $00, $00, $07, $00, $00
        .byte $02, $0A, $02, $00, $03, $03, $03, $00, $00, $02, $00, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $04, $04, $05, $00, $00, $08, $00, $00, $07, $07, $08, $00
        .byte $02, $0A, $00, $00, $03, $03, $03, $00, $00, $02, $00, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
        .byte $02, $0A, $00, $00, $03, $03, $03, $00, $00, $02, $00, $00, $06, $06, $06, $00
        .byte $0C, $0B, $00, $00, $00, $04, $04, $00, $00, $08, $00, $00, $00, $07, $07, $00
