# 8.1 Glossary

[English](08-1-glossary.md) | [日本語](../ja/08-1-glossary.md)

[← Chapter overview](08-glossary-index.md) &nbsp;·&nbsp; [8.2 Index →](08-2-index.md)

The terms from Chapters 1 to 7, in alphabetical order. The link after each definition goes to the section where the term is first explained.

## A

- **Accumulator**: The A register. It is the center of calculation, and the target of additions and comparisons. ([3.2 Registers](03-cpu.md#32-registers))
- **Address**: A number given to each byte of memory. A 6502 address has 16 bits, so there are 65,536 of them, from `$0000` to `$FFFF`. ([2.7 Memory and Addresses](02-basics.md#27-memory-and-addresses))
- **Address bus**: The 16 lines on which the CPU puts an address, A0 to A15. ([3.3 Buses](03-cpu.md#33-buses))
- **Address decoding**: The circuit (mechanism) that chooses which part, RAM, ROM, or I/O, to use for an address. ([7.1.1 Assigning Addresses](07-memory-io.md#711-assigning-addresses))
- **Address space**: The whole range of addresses the CPU can specify. For the 6502, it is 64KB. ([2.7 Memory and Addresses](02-basics.md#27-memory-and-addresses))
- **Addressing mode**: The method that decides which value in memory the operand of an instruction refers to. The 6502 has 13 modes. ([4.1 What Is an Addressing Mode](04-addressing.md#41-what-is-an-addressing-mode))
- **ASCII** (American Standard Code for Information Interchange): A character code that assigns numbers to letters, digits, and symbols. `A` is `$41`, `0` is `$30`, and CR is `$0D`. ([2.6 Character Codes (ASCII)](02-basics.md#26-character-codes-ascii))
- **Assembler**: A program that turns a program written in assembly language into machine code bytes. It also converts the label of a branch target into a distance. ([Instruction Syntax](05-reference.md#instruction-syntax))
- **Assembly language**: A way of writing instructions as text, using a mnemonic and an operand, such as `LDA #$10`. ([Instruction Syntax](05-reference.md#instruction-syntax))

## B

- **BCD** (Binary Coded Decimal): A format that treats each 4 bits as a digit from 0 to 9. ADC and SBC use it in decimal mode. ([5.3 Arithmetic and Comparison](05-3-arithmetic.md#53-arithmetic-and-comparison))
- **Binary**: A way of writing numbers with only 0 and 1. Each digit is worth twice the digit to its right. ([2.2 Binary](02-basics.md#22-binary))
- **Bit**: The smallest unit, holding either 0 or 1. ([2.1 Bits and Bytes](02-basics.md#21-bits-and-bytes))
- **BRK** (Break): An instruction that causes an interrupt from a program. It uses the IRQ vector and is not masked by I. B is 1 in the P it pushes. ([6.3.4 BRK](06-flags-stack-interrupts.md#634-brk))
- **Bus**: A bundle of lines that connects the CPU and memory. There is an address bus and a data bus. ([3.3 Buses](03-cpu.md#33-buses))
- **Byte**: A unit of 8 bits grouped together. The 6502 handles data one byte at a time. ([2.1 Bits and Bytes](02-basics.md#21-bits-and-bytes))

## C

- **Carry**: The C flag. It holds the digit that did not fit in 8 bits. In ADC it becomes 1 when the result exceeds `$FF`, and in SBC it becomes 1 when no borrow is needed. ([6.1.2 C (Carry)](06-flags-stack-interrupts.md#612-c-carry))
- **Clock**: A signal at a fixed interval that drives the CPU forward. One period of the clock is one cycle. ([3.4 Fetch and Execute](03-cpu.md#34-fetch-and-execute))
- **Conditional branch**: An instruction that looks at a flag and jumps only when the condition holds. The instructions are BCC, BCS, BEQ, BNE, BMI, BPL, BVC, and BVS. ([6.1.7 Flags Tested by Conditional Branches](06-flags-stack-interrupts.md#617-flags-tested-by-conditional-branches))
- **CPU** (Central Processing Unit): The part that takes instructions from memory one at a time and runs them. ([3.1 The CPU and Memory](03-cpu.md#31-the-cpu-and-memory))
- **Cycle**: One period of the clock. In each cycle the CPU makes one access to the bus. ([3.4 Fetch and Execute](03-cpu.md#34-fetch-and-execute))

## D

- **Data bus**: The 8 lines that carry the byte being read or written, D0 to D7. ([3.3 Buses](03-cpu.md#33-buses))
- **Decimal mode**: The mode in which ADC and SBC calculate in BCD when the D flag is 1. `$09 + $01` becomes `$10`. ([1.5 The Family Computer](01-history.md#15-the-family-computer), [6.1.4 D (Decimal Mode)](06-flags-stack-interrupts.md#614-d-decimal-mode))
- **Disassemble**: To read the bytes in memory as instructions and turn them back into written form. The monitor's `L` command does this. ([3.5 Instruction Format](03-cpu.md#35-instruction-format))
- **Dummy read**: An extra read that a real 6502 performs and whose result is not used. Glow65 does not reproduce it. ([Cycles and Bus Accesses in Glow65](05-reference.md#cycles-and-bus-accesses-in-glow65))

## E

- **Edge**: The moment a signal changes from "none" to "present". NMI is accepted once for each edge. ([6.3.3 The Difference between NMI and IRQ](06-flags-stack-interrupts.md#633-the-difference-between-nmi-and-irq))
- **Effective address**: The address in memory that an instruction actually reads or writes. How it is worked out differs for each addressing mode. ([4.1 What Is an Addressing Mode](04-addressing.md#41-what-is-an-addressing-mode))

## F

- **Fetch**: Taking the bytes of an instruction from the address in PC. ([3.4 Fetch and Execute](03-cpu.md#34-fetch-and-execute))
- **Flag**: One bit of the P register. It shows the result of the last instruction. ([3.2 Registers](03-cpu.md#32-registers))

## H

- **Handler**: The program that deals with an interrupt. It ends with RTI. ([6.3.2 The Acceptance Sequence](06-flags-stack-interrupts.md#632-the-acceptance-sequence))
- **Hexadecimal**: A way of writing numbers in which 4 bits make one digit (0 to F). On the 6502 it is written with a leading `$`. ([2.3 Hexadecimal](02-basics.md#23-hexadecimal))

## I

- **I/O** (Input/Output): The window to outside devices. A device is assigned to particular addresses in memory, and you talk to it by reading and writing those addresses. This is also called memory-mapped I/O. ([2.8 ROM, RAM, and I/O](02-basics.md#28-rom-ram-and-io))
- **Interrupt**: Pausing the running program to move to other work. The causes are NMI, IRQ, and BRK. ([6.3 Interrupts](06-flags-stack-interrupts.md#63-interrupts))
- **IRQ** (Interrupt Request): An interrupt raised by a device such as the UART. It is masked by the I flag. It is accepted again and again while the request continues (it works as a level). ([6.3.1 The Four Interrupts](06-flags-stack-interrupts.md#631-the-four-interrupts))

## L

- **Least significant bit** (LSB): Bit 0, the rightmost of the 8 bits. ([2.1 Bits and Bytes](02-basics.md#21-bits-and-bytes))
- **Level**: A state that lasts while the signal is "present". IRQ is accepted again and again while the request continues. ([6.3.3 The Difference between NMI and IRQ](06-flags-stack-interrupts.md#633-the-difference-between-nmi-and-irq))
- **Little-endian**: A way of placing a value of 2 or more bytes with the low byte first. 6502 addresses are stored in this order. ([2.7 Memory and Addresses](02-basics.md#27-memory-and-addresses))
- **Load and store**: A load puts a value from memory into a register. A store writes a register value to memory. ([5.1 Load and Store](05-1-load-store.md#51-load-and-store))

## M

- **Machine code**: A program written as opcode and operand bytes, which the CPU runs directly. ([3.5 Instruction Format](03-cpu.md#35-instruction-format))
- **Mask**: To make the CPU refuse an interrupt. While the I flag is 1, IRQ is masked. NMI cannot be masked. ([6.3.1 The Four Interrupts](06-flags-stack-interrupts.md#631-the-four-interrupts))
- **Master reset**: Writing `%11` to the UART control register to return the UART to its initial state. It discards received data and also turns off the interrupt enable. ([7.3 UART](07-memory-io.md#73-uart))
- **Memory**: A shelf of boxes in a row, each holding one byte. The boxes are numbered with addresses from the start. ([2.7 Memory and Addresses](02-basics.md#27-memory-and-addresses))
- **Memory map**: The assignment of the 64KB address space to RAM, ROM, and I/O parts. ([7.1.1 Assigning Addresses](07-memory-io.md#711-assigning-addresses))
- **Memory-mapped I/O**: A method of operating I/O the same way as memory, by reading and writing at an address. ([7.2 Memory-Mapped I/O](07-memory-io.md#72-memory-mapped-io))
- **Mirror**: One register appearing repeatedly at several addresses. In the Glow65 UART, two registers repeat across `$A000` to `$A0FF`. ([7.1.2 The Glow65 Memory Map](07-memory-io.md#712-the-glow65-memory-map))
- **Mnemonic**: The name of an instruction, such as `LDA` or `STA`. The 6502 has 56 official instructions. ([List of All 56 Instructions](05-reference.md#list-of-all-56-instructions))
- **Monitor**: A small program in the Glow65 ROM. With commands, you can show and write memory and run programs. ([7.4 Monitor Routines](07-memory-io.md#74-monitor-routines))
- **Most significant bit** (MSB): Bit 7, the leftmost of the 8 bits. In a signed number, it is the sign bit. ([2.1 Bits and Bytes](02-basics.md#21-bits-and-bytes))

## N

- **NMI** (Non-Maskable Interrupt): An interrupt that is accepted regardless of the I flag. Its vector is `$FFFA` and `$FFFB`. In Glow65 it is raised with the NMI button on the panel. ([6.3.1 The Four Interrupts](06-flags-stack-interrupts.md#631-the-four-interrupts))

## O

- **Opcode**: The first byte of an instruction. It decides the kind of instruction and the addressing mode. ([3.4 Fetch and Execute](03-cpu.md#34-fetch-and-execute))
- **Operand**: The bytes of an instruction that give a value or an address. There are 0 to 2 bytes. ([3.4 Fetch and Execute](03-cpu.md#34-fetch-and-execute))
- **Overflow**: The V flag. It shows overflow when the calculation is read as signed numbers. It becomes 1 when two numbers with the same sign are added and the sign of the result changes. ([6.1.3 V (Overflow)](06-flags-stack-interrupts.md#613-v-overflow))

## P

- **P register (status register)**: An 8-bit register that gathers the flags. The six real flags are N, V, D, I, Z, and C. ([6.1 Flags (the P Register)](06-flags-stack-interrupts.md#61-flags-the-p-register))
- **Page**: A block of 256 bytes with the same high byte. When an addition changes the high byte of the result, it is called "crossing a page". ([4.5 Absolute Modes](04-addressing.md#45-absolute-modes))
- **Polling**: A method in which the program reads a status register again and again, waiting for a bit to become 1. ([7.3.1 Polling](07-memory-io.md#731-polling))
- **Program counter** (PC): A 16-bit register that holds the address of the next instruction to run. ([3.1 The CPU and Memory](03-cpu.md#31-the-cpu-and-memory))

## R

- **RAM** (Random Access Memory): Memory that can be read and written. Its contents disappear when the power is turned off. ([2.8 ROM, RAM, and I/O](02-basics.md#28-rom-ram-and-io))
- **Register**: A storage area of a few bytes inside the CPU. It can be read and written faster than memory. ([3.2 Registers](03-cpu.md#32-registers))
- **Reset**: Throwing away the running program and starting again from a fixed state. PC is set from the vector at `$FFFC` and `$FFFD`. ([6.4 Reset](06-flags-stack-interrupts.md#64-reset))
- **ROM** (Read Only Memory): Memory that can only be read. Its contents stay when the power is off. It holds the program that runs at start-up. ([2.8 ROM, RAM, and I/O](02-basics.md#28-rom-ram-and-io))

## S

- **Shift**: Moving the bits one place sideways. ASL shifts left and LSR shifts right. ([5.4 Logic, Shift, and Bit Test](05-4-logic-shift.md#54-logic-shift-and-bit-test))
- **Sign bit**: In two's complement, the most significant bit (bit 7). 1 means negative, and 0 means zero or positive. ([2.5 Negative Numbers and Two's Complement](02-basics.md#25-negative-numbers-and-twos-complement))
- **Signature byte**: The one byte after BRK. The CPU skips it without using it. A handler can read it to tell the kinds of BRK apart. ([6.3.4 BRK](06-flags-stack-interrupts.md#634-brk))
- **Stack**: The memory from `$0100` to `$01FF`, used so that the value put in last is taken out first. ([6.2.1 Location and SP](06-flags-stack-interrupts.md#621-location-and-sp))
- **Stack pointer** (SP): An 8-bit register. The address `$0100` plus SP is the place where the next value is written. ([6.2.1 Location and SP](06-flags-stack-interrupts.md#621-location-and-sp))
- **Subroutine**: A small program that you call and use. It is called with JSR and returns with RTS. ([5.5 Branch and Jump](05-5-branch-jump.md#55-branch-and-jump))
- **SYNC**: A signal that is 1 while the CPU is reading the first byte of an instruction (the opcode). ([3.3 Buses](03-cpu.md#33-buses))

## T

- **Transfer**: Copying the value of one register to another register. The instructions are TAX, TAY, TXA, TYA, TSX, and TXS. ([5.2 Register Transfer](05-2-transfer.md#52-register-transfer))
- **Trigger**: The condition that causes an interrupt. NMI uses an edge and IRQ uses a level. ([6.3.1 The Four Interrupts](06-flags-stack-interrupts.md#631-the-four-interrupts))
- **Two's complement**: A way of representing negative numbers. Invert the bits and add 1. If the most significant bit is 1, the number is negative. With 8 bits it represents -128 to 127. ([2.5 Negative Numbers and Two's Complement](02-basics.md#25-negative-numbers-and-twos-complement))

## U

- **UART** (Universal Asynchronous Receiver/Transmitter): A device that handles serial communication with the terminal. In Glow65 it has two registers, `$A000` and `$A001`. ([7.3 UART](07-memory-io.md#73-uart))

## V

- **Vector**: A place that holds the destination address in 2 bytes (low byte first). NMI uses `$FFFA`, reset uses `$FFFC`, and IRQ and BRK use `$FFFE`. ([3.7 Vectors for Reset and Interrupts](03-cpu.md#37-vectors-for-reset-and-interrupts))

## Z

- **Zero page**: The first 256 bytes (`$0000` to `$00FF`), where the high byte of the address is `$00`. It can be addressed with a 1-byte address, which makes instructions shorter and faster. ([1.2 Specifications of the 6502](01-history.md#12-specifications-of-the-6502))

---

[← Chapter overview](08-glossary-index.md) &nbsp;·&nbsp; [8.2 Index →](08-2-index.md)
