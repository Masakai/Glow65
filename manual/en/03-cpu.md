# Chapter 3 Inside the CPU

[English](03-cpu.md) | [日本語](../ja/03-cpu.md)

[← 2. Computer Basics](02-basics.md)

The CPU takes instructions from memory and executes them one at a time. This chapter explains the storage areas inside the 6502 (registers), the lines that carry signals between the CPU and memory (buses), and the steps for executing an instruction (fetch and execute).

## 3.1 The CPU and Memory

A program is a sequence of bytes placed in memory. The CPU reads the instruction bytes from the start of the program in order and acts on them: adding numbers, writing a value to memory, jumping to another place, and so on.

A register called the **PC** (program counter) remembers where the CPU reads next. Each time the CPU reads an instruction, the PC moves forward by the length of that instruction.

## 3.2 Registers

A **register** is a small storage area of a few bytes inside the CPU. It can be read and written faster than memory. The 6502 has the following six registers[1].

| Register | Width | Role |
|---|---|---|
| A (accumulator) | 8 bits | The center of calculation. Used for addition and comparison |
| X | 8 bits | Index register. Used, for example, to add an offset to an address |
| Y | 8 bits | A register with the same role as X |
| SP (stack pointer) | 8 bits | The current position in the stack. The stack uses `$0100-$01FF` |
| PC (program counter) | 16 bits | The address of the next instruction to execute |
| P (status register) | 8 bits | A group of flags that describe the result of the previous instruction |

A, X, and Y can be used freely by a program. SP is covered in Chapter 6. How to use X and Y is covered in Chapter 4.

### Flags

Each bit of P has its own meaning. One such bit is called a **flag**. From the most significant bit down, they are arranged as follows.

| Bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Name | N | V | - | B | D | I | Z | C |
| Meaning | Negative. The most significant bit of the result is 1 | Overflow. A signed result went out of range | Unused | Break | Decimal mode | Interrupt disable | Zero. The result is 0 | Carry. A carry out of the top bit |

Chapter 6 explains what each flag does. For now, remember **N and Z**. Most instructions that put a value into A or X set Z to 1 if the value is 0, and set N to 1 if the most significant bit of the value is 1.

### Values After Reset

After a reset (power-on or the RESET switch), the CPU starts from a fixed state. In Glow65, the values after reset are as follows.

| Register | Value after reset |
|---|---|
| A, X, Y | 0 |
| SP | `$FD` |
| P | `$24` (`%00100100`). The I flag is 1, and bit 5 is 1 |
| PC | The 2 bytes at addresses `$FFFC` and `$FFFD` (low byte first) |

Section 3.7 explains how the PC is determined from `$FFFC` and `$FFFD`. On a real 6502, the internal state of the registers after reset is not defined, so the program must initialize them[1].

> **What you can try in Glow65**
>
> The panel has LEDs for PC, SP, A, X, Y, and the eight status flags. The status LEDs are arranged from left to right as `N`, `V`, `-`, `B`, `D`, `I`, `Z`, `C` (bit 7 down to bit 0). An LED is lit for a bit that is 1 and dark for a bit that is 0.
>
> You can see the state right after reset with these steps.
>
> 1. Turn **POWER** ON.
> 2. Set **RUN/STOP** to STOP to halt the CPU.
> 3. Press **RESET**.
>
> The CPU stays halted after the reset and shows the following state.
>
> | Display | LEDs | Value read |
> |---|---|---|
> | PC | 15, 14, 13, 12, 8, 5, 3, 1 lit | `$F12A` |
> | SP | 7, 6, 5, 4, 3, 2, 0 lit | `$FD` |
> | A, X, Y | all dark | 0 |
> | STATUS P | `-` and `I` lit | `$24` |
> | ADDRESS BUS | all lit except A1 | `$FFFD` |
> | DATA BUS | D7, D6, D5, D4, D0 lit | `$F1` |
> | CYCLES | 7 | |
> | INSTRUCTION AT PC | `F12A  78  SEI` | |
>
> The last byte read was at `$FFFD`, and its value `$F1` became the high byte of the PC. The READ and HALT LEDs are lit, and the RUN LED is dark. The PC value `$F12A` was determined from `2A` at `$FFFC` and `F1` at `$FFFD` (section 3.7).
>
> ![The panel right after reset. PC is F12A, SP is FD, the address bus is FFFD, the data bus is F1](../ja/images/03-reset.png)
>
> Figure 3-1 The panel right after reset

## 3.3 Buses

The CPU and memory are connected by many lines. A bundle of such lines is called a **bus**.

| Bus / signal | Lines | Role |
|---|---|---|
| Address bus | 16 lines (A0 to A15) | The CPU tells memory which address it reads or writes |
| Data bus | 8 lines (D0 to D7) | The byte being read or written flows here |
| R/W | 1 line | 1 for a read, 0 for a write |
| SYNC | 1 line | 1 while the CPU reads the first byte of an instruction (the opcode) |

The 16 address bus lines correspond to the 16-bit addresses from Chapter 2. The 8 data bus lines correspond to the 8 bits of one byte[1].

R/W shows whether the CPU is **reading** or **writing** memory. To read, the CPU puts out the address and the memory puts the byte on the data bus. To write, the CPU puts out both the address and the byte.

SYNC shows that the byte being read is the first byte of an instruction. SYNC is not raised when the CPU reads a byte in the middle of an instruction, or when it writes[1].

**In one clock (cycle), the CPU accesses the bus exactly once.** It either reads or writes[1].

> **What you can try in Glow65**
>
> The panel has 16 ADDRESS BUS LEDs (A0 to A15) and 8 DATA BUS LEDs (D0 to D7). It also has READ, WRITE, and SYNC LEDs. READ lights while the CPU reads memory, WRITE while it writes, and SYNC while it reads an opcode. At a SPEED of 1 kHz or lower, the bus accesses are shown one at a time.

## 3.4 Fetch and Execute

The CPU runs a program by repeating the same steps.

1. **Fetch**: Read the first byte of the instruction (the **opcode**) from the address in the PC. Advance the PC by 1.
2. **Fetch the operand**: If the opcode needs more bytes, read them next. Advance the PC by 1 for each byte read. An operand is a byte that the instruction uses, either as a value or as part of an address.
3. **Execute**: Carry out the action of the instruction. For example, change a register, write to memory, or set the PC to another place.

Once the CPU has read the opcode, it knows how many bytes the instruction needs and what it does. Below is a table of the bus accesses when the five-line program from Tutorial Chapter 1 runs.

```
0300  A9 00        LDA #$00
0302  8D F0 03     STA $03F0
0305  18           CLC
0306  69 01        ADC #$01
0308  4C 02 03     JMP $0302
```

| # | Address | Data | Read/Write | SYNC | Instruction |
|---|---|---|---|---|---|
| 1 | `$0300` | `A9` | Read | yes | `LDA #$00` |
| 2 | `$0301` | `00` | Read | | |
| 3 | `$0302` | `8D` | Read | yes | `STA $03F0` |
| 4 | `$0303` | `F0` | Read | | |
| 5 | `$0304` | `03` | Read | | |
| 6 | `$03F0` | `00` | Write | | |
| 7 | `$0305` | `18` | Read | yes | `CLC` |
| 8 | `$0306` | `69` | Read | yes | `ADC #$01` |
| 9 | `$0307` | `01` | Read | | |
| 10 | `$0308` | `4C` | Read | yes | `JMP $0302` |
| 11 | `$0309` | `02` | Read | | |
| 12 | `$030A` | `03` | Read | | |

SYNC is raised only when the first byte of an instruction is read. `STA $03F0` reads three times (the opcode and the 2-byte address), then writes once.

### Cycles and the Clock

The CPU moves forward on a **clock**, a signal that ticks at a fixed interval. One period of the clock is one **cycle**. With a 1 MHz clock, there are 1 million cycles per second, and one cycle takes 1 microsecond.

The number of cycles an instruction takes depends on the instruction. According to MOS Technology's documentation, instructions take from 2 to 7 cycles[1]. `LDA #$00` takes 2 cycles and `STA $03F0` takes 4 cycles.

On a real 6502, even a 1-byte instruction such as `CLC` takes 2 cycles, and the CPU reads the next byte once more. That read is not used[1]. Glow65 does not reproduce this extra read, which is why `CLC` has only one access in the table. The cycle counter still advances by 2, as on the real chip.

> **Column: Single-Stepping with SYNC**
>
> MOS Technology's documentation describes a use for the SYNC signal. SYNC is 1 in the cycle that reads an opcode. If the CPU's RDY pin is set to 0 at that moment, the CPU stops in that state. Setting RDY back to 1 resumes it. This mechanism makes it possible to build single-stepping, which executes one instruction at a time[1]. The STEP switch in Glow65 is also a feature for advancing one instruction or one bus access at a time.

> **What you can try in Glow65**
>
> You can follow the action cycle by cycle on the panel. After resetting as in section 3.2, set **STEP MODE** to CYCLE and press **STEP** one time at a time. The CPU runs the program at the start of the monitor (`SEI`, `CLD`, `LDX #$FF`, `TXS`).
>
> | STEP | ADDRESS BUS | DATA BUS | SYNC | What happened in that STEP |
> |---|---|---|---|---|
> | Before pressing | `$FFFD` | `$F1` | | The read from the reset (3.2) |
> | 1st | `$F12A` | `$78` | lit | The opcode of `SEI` was read. It is a one-read instruction, so the PC advances to `$F12B` and INSTRUCTION AT PC becomes `CLD` |
> | 2nd | `$F12B` | `$D8` | lit | The opcode of `CLD` was read. The PC is `$F12C` |
> | 3rd | `$F12C` | `$A2` | lit | The opcode of `LDX #$FF` was read |
> | 4th | `$F12D` | `$FF` | dark | The operand of `LDX` was read |
> | 5th | `$F12D` | `$FF` | dark | The bus does not change, and the result of `LDX` appears in the display |
>
> Between the 3rd and 4th STEP, the PC stays at `$F12C` and X stays 0. With a 2-byte instruction, **until the instruction has been read completely, the PC, registers, and flags show their values from before the instruction**. At the 5th STEP, X becomes `$FF`, the N flag lights, and the PC becomes `$F12E` (INSTRUCTION AT PC is `TXS`).
>
> CYCLES advances by the instruction's cycle count at the first bus access of the instruction. It goes from 7 to 9 at the STEP for `SEI`, to 11 at `CLD`, and to 13 at the 3rd STEP of `LDX #$FF`.
>
> ![The panel at the 1st STEP. The address bus is F12A, the data bus is 78, and SYNC is lit](../ja/images/03-cycle-1.png)
>
> Figure 3-2 1st STEP. The opcode of `SEI` has just been read
>
> ![The panel at the 3rd STEP. The address bus is F12C, the data bus is A2, SYNC is lit, and X is 0](../ja/images/03-cycle-3.png)
>
> Figure 3-3 3rd STEP. The opcode of `LDX #$FF` has just been read. The PC is `$F12C` and X is still 0
>
> ![The panel at the 4th STEP. The address bus is F12D, the data bus is FF, SYNC is dark, and X is 0](../ja/images/03-cycle-4.png)
>
> Figure 3-4 4th STEP. The operand of `LDX` has just been read. SYNC is dark and X is still 0
>
> ![The panel at the 5th STEP. The buses stay at F12D and FF, X is FF, N is lit, and PC is F12E](../ja/images/03-cycle-5.png)
>
> Figure 3-5 5th STEP. The buses do not change. X becomes `$FF`, N lights, and the PC becomes `$F12E`
>
> If you set SPEED to 10 Hz and RUN, the same actions flow continuously. The low LEDs of the address bus change each time the PC advances.
>
> If you set STEP MODE to INSTR, each press of STEP advances one instruction. The bus keeps the last bus access of that instruction. The detailed steps are in [Tutorial Chapter 1](../../tutorial/README.md).

## 3.5 Instruction Format

An instruction consists of a 1-byte opcode and 0 to 2 bytes of operand. An instruction is 1 to 3 bytes long.

| Length | Structure | Example |
|---|---|---|
| 1 byte | Opcode only | `AA` (`TAX`) |
| 2 bytes | Opcode + 1 byte | `A9 00` (`LDA #$00`) |
| 3 bytes | Opcode + 2 bytes (low byte first) | `8D F0 03` (`STA $03F0`) |

The opcode determines the length. Even for the same `LDA`, `A9` is 2 bytes and `AD` is 3 bytes. The meaning of the operand (a value itself, or an address) is determined by the **addressing mode**. Chapter 4 covers this in detail.

In a 3-byte instruction, the address is stored in little-endian order, as in Chapter 2. In `8D F0 03`, `F0 03` is the address `$03F0`.

> **What you can try in Glow65**
>
> Write bytes with `E` in the monitor and read them back as instructions with `L`.
>
> ```
> *E 0300 A9 00 8D F0 03
> *L 0300 0304
> 0300  A9 00     LDA   #$00
> 0302  8D F0 03  STA   $03F0
> ```
>
> `L 0300 0304` disassembles the range from `$0300` to `$0304`. You can see that `LDA` is 2 bytes and `STA` is 3 bytes from how the addresses increase.
>
> The same byte sequence becomes different instructions if you change where you start reading.
>
> ```
> *E 0300 AD 34 12 A9 10 8D 00 04 AA
> *L 0300 0308
> 0300  AD 34 12  LDA   $1234
> 0303  A9 10     LDA   #$10
> 0305  8D 00 04  STA   $0400
> 0308  AA        TAX
> ```
>
> `AD 34 12` is the 3-byte `LDA $1234`. `34 12` becomes `$1234` in little-endian order.

## 3.6 An Example of Executing Instructions

Let us follow the next program through its bus activity and its changes to registers and flags.

```
0300  A9 80        LDA #$80
0302  AA           TAX
0303  8D F0 03     STA $03F0
0306  8E F1 03     STX $03F1
0309  60           RTS
```

| Instruction | Bus accesses | A | X | N | Z | Change in memory |
|---|---|---|---|---|---|---|
| `LDA #$80` | 2 reads (opcode, value) | `$80` | unchanged | 1 | 0 | none |
| `TAX` | 1 read (opcode) | `$80` | `$80` | 1 | 0 | none |
| `STA $03F0` | 3 reads, 1 write | `$80` | `$80` | 1 | 0 | `$03F0` becomes `$80` |
| `STX $03F1` | 3 reads, 1 write | `$80` | `$80` | 1 | 0 | `$03F1` becomes `$80` |

- `LDA #$80` puts `$80` into A. The most significant bit of `$80` is 1, so N becomes 1. The value is not 0, so Z is 0.
- `TAX` copies the value of A into X. A stays as it is. N and Z are set according to the `$80` that went into X.
- `STA` and `STX` write a register's value to memory. The registers and flags do not change.
- `RTS` is the instruction that returns to the monitor that called the program with `G`. Chapter 6 covers it.

When the value is 0, Z becomes 1 and N becomes 0. After `LDA #$00`, only Z is 1.

> **What you can try in Glow65 (panel)**
>
> Reset as in section 3.2, set STEP MODE to INSTR, and press STEP to advance one instruction at a time. With the program at the start of the monitor, you can watch the registers and flags change.
>
> | STEP | Instruction executed | Change in registers and flags | ADDRESS BUS / DATA BUS | Next instruction |
> |---|---|---|---|---|
> | 1st | `SEI` | No change (the I flag was already 1) | `$F12A` / `$78` (SYNC lit) | `CLD` (`$F12B`) |
> | 2nd | `CLD` | No change (the D flag was already 0) | `$F12B` / `$D8` (SYNC lit) | `LDX #$FF` (`$F12C`) |
> | 3rd | `LDX #$FF` | X becomes `$FF` and N lights | `$F12D` / `$FF` (operand of `LDX`) | `TXS` (`$F12E`) |
> | 4th | `TXS` | SP becomes `$FF` (all SP LEDs lit). N stays lit | `$F12E` / `$9A` (SYNC lit) | `LDA #$03` (`$F12F`) |
> | 5th | `LDA #$03` | A becomes `$03` (bits 1 and 0 lit). N goes dark | `$F130` / `$03` | `STA $A000` (`$F131`) |
>
> The `$FF` of `LDX #$FF` has its most significant bit set, so N lights. `TXS` only copies the value of X into SP and does not change the flags. `LDA #$03` has a most significant bit of 0 and is not 0, so neither N nor Z lights.
>
> The STEP counts are counted from right after the reset in section 3.2.
>
> ![The panel after the 3rd STEP in INSTR. X is FF, N is lit, and the next instruction is TXS](../ja/images/03-instr-3.png)
>
> Figure 3-6 After the 3rd STEP. `LDX #$FF` has run, X is `$FF`, and N is lit
>
> ![The panel after the 4th STEP in INSTR. SP is FF and the next instruction is LDA #03](../ja/images/03-instr-4.png)
>
> Figure 3-7 After the 4th STEP. `TXS` has run, and all SP LEDs are lit

> **What you can try in Glow65 (monitor)**
>
> The monitor has no command to display the registers. Instead, the program writes its result to memory and you read it with `D`.
>
> First, run the five instructions above.
>
> ```
> *E 0300 A9 80 AA 8D F0 03 8E F1 03 60
> *L 0300 0309
> 0300  A9 80     LDA   #$80
> 0302  AA        TAX
> 0303  8D F0 03  STA   $03F0
> 0306  8E F1 03  STX   $03F1
> 0309  60        RTS
> *G 0300
> *D 03F0 03F1
> 03F0: 80 80 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> Both `$03F0` and `$03F1` are `80`. `D` shows 16 bytes at a time, so the following `24 F4 24 F4` are the monitor's interrupt vectors. Chapter 6 explains them.
>
> Next, check the flags. `PHP` pushes P onto the stack, and `PLA` pulls the pushed value into A. `PHP` pushes with bit 4 (B) and bit 5 set to 1. Ignore those two and look at N and Z.
>
> ```
> *E 0300 A9 80 08 68 8D F0 03 A9 00 08 68 8D F1 03 60
> *G 0300
> *D 03F0 03F1
> 03F0: B4 36 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> After `LDA #$80`, P is `$B4` (`%10110100`), and N is 1. After `LDA #$00`, P is `$36` (`%00110110`), and Z is 1. In both, the I flag (bit 2) is 1.

## 3.7 Vectors for Reset and Interrupts

On a reset or an interrupt, the CPU reads the address to jump to from a fixed place in memory. This place is called a **vector**. The vectors are in the last 6 bytes of the address space[1].

| Address | Use |
|---|---|
| `$FFFA` `$FFFB` | NMI (non-maskable interrupt) |
| `$FFFC` `$FFFD` | Reset |
| `$FFFE` `$FFFF` | IRQ and BRK |

Each vector is 2 bytes, low byte first. After a reset, the CPU reads `$FFFC` and `$FFFD` and puts that 16-bit address into the PC. The program starts from that address. Chapter 6 explains interrupts in detail.

In Glow65, the vectors are in the monitor's ROM (see the `D FFF0 FFFF` example in Chapter 2).

## 3.8 Practice Problems

The answers and explanations are in the next section.

**Problem 1** How many bits wide are the PC and A registers?

**Problem 2** What are the values of SP and P right after a reset in Glow65, in hexadecimal? Which flags are 1 in P?

**Problem 3** After a reset, where is the address of the first instruction the CPU executes taken from? If `$FFFC` and `$FFFD` of Glow65 contain `2A F1`, what is the PC?

**Problem 4** When `STA $03F0` (`8D F0 03`) is executed once, how many bus accesses are there? Give the numbers of reads and writes separately. How many times is SYNC 1?

**Problem 5** Split the byte sequence `A9 10 8D 00 04 AA` into instructions. Give the length of each instruction and the total number of bytes.

**Problem 6** After `LDA #$00` is executed, which of N and Z is 1? Which one after `LDA #$FF`?

**Problem 7** In Glow65, you enter `E 0300 A2 05 8E F0 03 60`, run it with `G 0300`, and enter `D 03F0 03F0`. What is the value of `$03F0`?

**Problem 8** You read P with the method in 3.6 and got `$B4`. Which flags are 1? List all of them.

**Problem 9** After running `A9 7F 08 68 8D F0 03 60`, what is the value of `$03F0`?

## 3.9 Answers and Explanations

**Problem 1** The PC is 16 bits and A is 8 bits.

- The PC holds a 16-bit address. A handles one byte of data.

**Problem 2** SP is `$FD` and P is `$24`. The flags that are 1 are the I flag (bit 2) and bit 5.

- `$24` is `%00100100`. Bit 5 is unused and always 1. Bit 2 is I.

**Problem 3** It is taken from `$FFFC` and `$FFFD`. The PC is `$F12A`.

- The low byte comes first, so `2A` at `$FFFC` is the low byte and `F1` at `$FFFD` is the high byte.

**Problem 4** 3 reads and 1 write. SYNC is 1 once.

- Reads: the opcode `8D`, the low byte `F0`, and the high byte `03`. Write: once, to `$03F0`. SYNC is raised only when the opcode is read.

**Problem 5** `A9 10` = `LDA #$10` (2 bytes), `8D 00 04` = `STA $0400` (3 bytes), `AA` = `TAX` (1 byte). 6 bytes in total.

- `A9` is followed by 1 value byte, `8D` is followed by a 2-byte address, and `AA` has no operand.

**Problem 6** After `LDA #$00`, Z. After `LDA #$FF`, N.

- `$00` is 0, so Z is 1. `$FF` has its most significant bit set, so N is 1.

**Problem 7** `$05`.

- `A2 05` is `LDX #$05`, `8E F0 03` is `STX $03F0`, and `60` is `RTS`. The 5 in X is written to `$03F0`.

**Problem 8** N and I. In addition, bit 4 (B) and bit 5, which PHP sets to 1 when it pushes.

- `$B4` is `%10110100`. Bits 7 (N), 5, 4 (B), and 2 (I) are 1.

**Problem 9** `$34`.

- `LDA #$7F` has a most significant bit of 0 and is not 0, so N and Z are both 0. I (bit 2) is 1, and PHP sets bits 4 and 5 to 1. That gives `%00110100`, which is `$34`.

## Sources

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", January 1976 edition: https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt

Next chapter: [4. Addressing Modes →](04-addressing.md)
