# Chapter 8 Glossary and Index

[English](08-glossary-index.md) | [日本語](../ja/08-glossary-index.md)

[← 7. The Memory Map and I/O](07-memory-io.md)

This chapter gives the definitions of the terms in Chapters 1 to 7, and an index to look up instructions, addressing modes, flags, addresses, and figures.

| Section | Contents |
|---|---|
| [8.1 Glossary](08-1-glossary.md) | Definitions of terms in alphabetical order. 72 terms |
| [8.2 Index](08-2-index.md) | Instructions, addressing modes, flags and registers, monitor commands and routines, important addresses, figures |
| [8.3 Correspondence with the Tutorial](#83-correspondence-with-the-tutorial) | A table matching the chapters of the manual to the chapters of the tutorial |

## 8.3 Correspondence with the Tutorial

The manual is for reading and understanding, and the [tutorial](../../tutorial/README.md) is for hands-on work. After you read a chapter of the manual, try the matching chapter of the tutorial, and the content will stay with you.

| Tutorial | Contents | Matching manual chapters |
|---|---|---|
| [1. LED counter](../../tutorial/README.md) | Load a 5-line program and follow the bus accesses | [Chapter 2 Memory and Addresses](02-basics.md#27-memory-and-addresses), [Chapter 3 Fetch and Execute](03-cpu.md#34-fetch-and-execute), [Chapter 3 Instruction Format](03-cpu.md#35-instruction-format) |
| [2. Addition and the carry flag](../../tutorial/02-addition.md) | 16-bit addition and C | [Chapter 2 Range of Numbers](02-basics.md#24-range-of-numbers), [Chapter 5 Arithmetic and Comparison](05-3-arithmetic.md#53-arithmetic-and-comparison), [Chapter 6 C (Carry)](06-flags-stack-interrupts.md#612-c-carry) |
| [3. Talking to the UART](../../tutorial/03-uart.md) | Send characters with `CHROUT` | [Chapter 7 UART](07-memory-io.md#73-uart), [Chapter 7 Monitor Routines](07-memory-io.md#74-monitor-routines) |
| [4. Reading the keyboard](../../tutorial/04-echo.md) | An echo program that receives by polling | [Chapter 7 Polling](07-memory-io.md#731-polling), [Chapter 7 Monitor Routines](07-memory-io.md#74-monitor-routines) |
| [5. USR](../../tutorial/05-usr.md) | Call machine code from BASIC | [Chapter 7 How RAM Is Used](07-memory-io.md#713-how-ram-is-used), [Chapter 5 JSR and RTS](05-5-branch-jump.md#55-branch-and-jump) |
| [6. Interrupts](../../tutorial/06-interrupts.md) | NMI and IRQ handlers | [Chapter 6 Interrupts](06-flags-stack-interrupts.md#63-interrupts), [Chapter 6 The Stack](06-flags-stack-interrupts.md#62-the-stack) |

The addressing modes (Chapter 4) and the instruction reference (Chapter 5) work as a dictionary when you read the tutorial programs.
