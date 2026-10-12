# Chapter 5 Instruction Reference

[English](05-reference.md) | [日本語](../ja/05-reference.md)

[← 4. Addressing Modes](04-addressing.md)

This chapter is a reference to the 151 official opcodes (56 instructions) of the 6502, grouped by function. For each instruction it gives the operation, the flags it affects, an opcode table, and usage examples. The instructions are split into one file per group.

## How to Read This Chapter

### Instruction Syntax

| Syntax | Meaning |
|---|---|
| `#$nn` | The value itself (immediate). `nn` is 1 byte |
| `$nn` | A zero page address. `nn` is 1 byte |
| `$nnnn` | A 2-byte address. In machine code, the low byte comes first |
| `($nn,X)`, `($nn),Y`, `($nnnn)` | The three forms of indirect |
| `A` | The accumulator (the A register itself) |
| `label` | The branch target. The assembler converts it to a distance |

Chapter 4 explains the addressing modes.

### Symbols in the Flag Tables

The "Flags affected" table of each instruction shows the six flags N, V, D, I, Z, and C with the symbols below. B (break) and bit 5 have no storage in P, so they are not in the table.

| Symbol | Meaning |
|---|---|
| ○ | Becomes 0 or 1 depending on the result |
| - | Does not change |
| 0, 1 | Always becomes 0, or always becomes 1 |
| M7, M6 | Takes bit 7 or bit 6 of the memory value as it is |
| Restored | Replaced by the value pulled from the stack |

### Reading the Opcode Tables

The columns of the "Opcodes" table are as follows.

| Column | Meaning |
|---|---|
| Addressing mode | A mode the instruction has |
| Syntax | How to write it in assembly language |
| Opcode | The first byte of the machine code (hexadecimal) |
| Bytes | The length of the whole instruction |
| Cycles | The number of cycles the instruction takes |

The notation for cycles is as follows.

| Notation | Meaning |
|---|---|
| `4` | Always 4 cycles |
| `4+` | A read instruction. If adding the index crosses into another page, it takes 1 more cycle (5 cycles) |
| `2 (+1, +2)` | A branch. 2 cycles when the condition is false, 3 when it is true, and 4 when it is true and the target is on another page |

The extra cycle for a page crossing and the cycle counts of branches are in the table of the MOS manual [1].

### Cycles and Bus Accesses in Glow65

When it calculates an address, the real 6502 performs extra reads (dummy reads) and writes (dummy writes) whose results are not used. Glow65 does not reproduce them. Glow65 counts the same number of cycles as the real chip, but the number of bus accesses shown on the panel and in the diagrams can be smaller than on the real chip. For example, `CLC` takes 2 cycles and makes 1 bus access.

## Groups

| Group | Instructions |
|---|---|
| [5.1 Load and Store](05-1-load-store.md) | LDA, LDX, LDY, STA, STX, STY |
| [5.2 Register Transfer](05-2-transfer.md) | TAX, TAY, TXA, TYA, TSX, TXS |
| [5.3 Arithmetic and Comparison](05-3-arithmetic.md) | ADC, SBC, CMP, CPX, CPY, INC, DEC, INX, INY, DEX, DEY |
| [5.4 Logic, Shift, and Bit Test](05-4-logic-shift.md) | AND, ORA, EOR, BIT, ASL, LSR, ROL, ROR |
| [5.5 Branch and Jump](05-5-branch-jump.md) | BCC, BCS, BEQ, BNE, BMI, BPL, BVC, BVS, JMP, JSR, RTS, BRK, RTI |
| [5.6 Stack and Flag Operations](05-6-stack-flags.md) | PHA, PLA, PHP, PLP, CLC, SEC, CLI, SEI, CLD, SED, CLV, NOP |

## List of All 56 Instructions

<!-- list -->
| Mnemonic | Name | Function | Flags affected |
|---|---|---|---|
| [LDA](05-1-load-store.md#lda-load-accumulator) | Load Accumulator | Loads a value from memory into A | N Z |
| [LDX](05-1-load-store.md#ldx-load-x-register) | Load X Register | Loads a value from memory into X | N Z |
| [LDY](05-1-load-store.md#ldy-load-y-register) | Load Y Register | Loads a value from memory into Y | N Z |
| [STA](05-1-load-store.md#sta-store-accumulator) | Store Accumulator | Writes the value of A to memory | None |
| [STX](05-1-load-store.md#stx-store-x-register) | Store X Register | Writes the value of X to memory | None |
| [STY](05-1-load-store.md#sty-store-y-register) | Store Y Register | Writes the value of Y to memory | None |
| [TAX](05-2-transfer.md#tax-transfer-a-to-x) | Transfer A to X | Copies the value of A to X | N Z |
| [TAY](05-2-transfer.md#tay-transfer-a-to-y) | Transfer A to Y | Copies the value of A to Y | N Z |
| [TXA](05-2-transfer.md#txa-transfer-x-to-a) | Transfer X to A | Copies the value of X to A | N Z |
| [TYA](05-2-transfer.md#tya-transfer-y-to-a) | Transfer Y to A | Copies the value of Y to A | N Z |
| [TSX](05-2-transfer.md#tsx-transfer-stack-pointer-to-x) | Transfer Stack Pointer to X | Copies the value of SP to X | N Z |
| [TXS](05-2-transfer.md#txs-transfer-x-to-stack-pointer) | Transfer X to Stack Pointer | Copies the value of X to SP | None |
| [ADC](05-3-arithmetic.md#adc-add-with-carry) | Add with Carry | Adds the memory value and the carry to A | N V Z C |
| [SBC](05-3-arithmetic.md#sbc-subtract-with-carry) | Subtract with Carry | Subtracts the memory value and the borrow from A | N V Z C |
| [CMP](05-3-arithmetic.md#cmp-compare-accumulator) | Compare Accumulator | Compares A with a memory value | N Z C |
| [CPX](05-3-arithmetic.md#cpx-compare-x-register) | Compare X Register | Compares X with a memory value | N Z C |
| [CPY](05-3-arithmetic.md#cpy-compare-y-register) | Compare Y Register | Compares Y with a memory value | N Z C |
| [INC](05-3-arithmetic.md#inc-increment-memory) | Increment Memory | Adds 1 to a memory value | N Z |
| [DEC](05-3-arithmetic.md#dec-decrement-memory) | Decrement Memory | Subtracts 1 from a memory value | N Z |
| [INX](05-3-arithmetic.md#inx-increment-x-register) | Increment X Register | Adds 1 to X | N Z |
| [INY](05-3-arithmetic.md#iny-increment-y-register) | Increment Y Register | Adds 1 to Y | N Z |
| [DEX](05-3-arithmetic.md#dex-decrement-x-register) | Decrement X Register | Subtracts 1 from X | N Z |
| [DEY](05-3-arithmetic.md#dey-decrement-y-register) | Decrement Y Register | Subtracts 1 from Y | N Z |
| [AND](05-4-logic-shift.md#and-logical-and) | Logical AND | Bitwise AND of A and a memory value | N Z |
| [ORA](05-4-logic-shift.md#ora-logical-or) | Logical OR | Bitwise OR of A and a memory value | N Z |
| [EOR](05-4-logic-shift.md#eor-exclusive-or) | Exclusive OR | Bitwise XOR of A and a memory value | N Z |
| [BIT](05-4-logic-shift.md#bit-bit-test) | Bit Test | ANDs A with a memory value to set Z, and copies the top 2 bits of the memory value to N and V | N V Z |
| [ASL](05-4-logic-shift.md#asl-arithmetic-shift-left) | Arithmetic Shift Left | Shifts left by 1 bit; the most significant bit goes out to C | N Z C |
| [LSR](05-4-logic-shift.md#lsr-logical-shift-right) | Logical Shift Right | Shifts right by 1 bit; the least significant bit goes out to C | N Z C |
| [ROL](05-4-logic-shift.md#rol-rotate-left) | Rotate Left | Rotates left by 1 bit through C | N Z C |
| [ROR](05-4-logic-shift.md#ror-rotate-right) | Rotate Right | Rotates right by 1 bit through C | N Z C |
| [BCC](05-5-branch-jump.md#bcc-branch-if-carry-clear) | Branch if Carry Clear | Branches if C is 0 | None |
| [BCS](05-5-branch-jump.md#bcs-branch-if-carry-set) | Branch if Carry Set | Branches if C is 1 | None |
| [BEQ](05-5-branch-jump.md#beq-branch-if-equal) | Branch if Equal | Branches if Z is 1 | None |
| [BNE](05-5-branch-jump.md#bne-branch-if-not-equal) | Branch if Not Equal | Branches if Z is 0 | None |
| [BMI](05-5-branch-jump.md#bmi-branch-if-minus) | Branch if Minus | Branches if N is 1 | None |
| [BPL](05-5-branch-jump.md#bpl-branch-if-plus) | Branch if Plus | Branches if N is 0 | None |
| [BVC](05-5-branch-jump.md#bvc-branch-if-overflow-clear) | Branch if Overflow Clear | Branches if V is 0 | None |
| [BVS](05-5-branch-jump.md#bvs-branch-if-overflow-set) | Branch if Overflow Set | Branches if V is 1 | None |
| [JMP](05-5-branch-jump.md#jmp-jump) | Jump | Jumps to the given address | None |
| [JSR](05-5-branch-jump.md#jsr-jump-to-subroutine) | Jump to Subroutine | Pushes the return address and jumps to the given address | None |
| [RTS](05-5-branch-jump.md#rts-return-from-subroutine) | Return from Subroutine | Pulls the return address and returns | None |
| [BRK](05-5-branch-jump.md#brk-break) | Break | Causes a software interrupt | I |
| [RTI](05-5-branch-jump.md#rti-return-from-interrupt) | Return from Interrupt | Pulls P and the return address and returns | N V D I Z C |
| [PHA](05-6-stack-flags.md#pha-push-accumulator) | Push Accumulator | Pushes A onto the stack | None |
| [PLA](05-6-stack-flags.md#pla-pull-accumulator) | Pull Accumulator | Pulls A from the stack | N Z |
| [PHP](05-6-stack-flags.md#php-push-processor-status) | Push Processor Status | Pushes P onto the stack | None |
| [PLP](05-6-stack-flags.md#plp-pull-processor-status) | Pull Processor Status | Pulls P from the stack | N V D I Z C |
| [CLC](05-6-stack-flags.md#clc-clear-carry-flag) | Clear Carry Flag | Sets C to 0 | C |
| [SEC](05-6-stack-flags.md#sec-set-carry-flag) | Set Carry Flag | Sets C to 1 | C |
| [CLI](05-6-stack-flags.md#cli-clear-interrupt-disable) | Clear Interrupt Disable | Enables interrupts | I |
| [SEI](05-6-stack-flags.md#sei-set-interrupt-disable) | Set Interrupt Disable | Disables interrupts | I |
| [CLD](05-6-stack-flags.md#cld-clear-decimal-mode) | Clear Decimal Mode | Leaves decimal mode | D |
| [SED](05-6-stack-flags.md#sed-set-decimal-mode) | Set Decimal Mode | Enters decimal mode | D |
| [CLV](05-6-stack-flags.md#clv-clear-overflow-flag) | Clear Overflow Flag | Sets V to 0 | V |
| [NOP](05-6-stack-flags.md#nop-no-operation) | No Operation | Does nothing | None |
<!-- /list -->

## Undefined Opcodes

The 105 opcodes other than the 151 official ones are not official instructions. Glow65 executes them as a 1-byte, 2-cycle NOP that has no operand. On a real NMOS 6502, each undefined opcode behaves differently, but Glow65 does not reproduce this.

Instructions added by the 65C02 (`BRA`, `STZ`, `PHX`, and others) are not covered in this chapter.

> **What you can try in Glow65**
>
> Place the undefined opcode `$02` and run it. `L` shows it as `.BYTE`.
>
> ```
> *E 0300 02 A2 05 8E F0 03 60
> *L 0300 0301
> 0300  02        .BYTE $02
> 0301  A2 05     LDX   #$05
> *G 0300
> *D 03F0 03F0
> 03F0: 05 00 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> `$02` runs as a 1-byte NOP. The `LDX #$05` after it runs, and `05` is written to `$03F0`.

## Sources

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", January 1976 edition: https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt

Next chapter: [6. Flags, the Stack, and Interrupts →](06-flags-stack-interrupts.md)
