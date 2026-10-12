# Chapter 2: Computer Basics

[English](02-basics.md) | [日本語](../ja/02-basics.md)

[← 1. The History of the 6502](01-history.md)

All a CPU handles is strings of 0s and 1s. This chapter explains how people read and write those strings. It covers bits and bytes, binary and hexadecimal, negative numbers, characters, and memory and addresses, in that order. The math you need is powers of 2 (2, 4, 8, 16 ...) and basic arithmetic (addition, subtraction, multiplication, and division).

At the end of each section there is something you can try in Glow65. How to use the monitor is described in "Monitor commands" in the [README](../../README.md). Practice problems and their answers are at the end of the chapter.

## 2.1 Bits and Bytes

A **bit** is the smallest unit. It holds either 0 or 1, like a switch that is ON or OFF.

A **byte** is a unit of 8 bits grouped together. The 6502 handles data one byte at a time. Eight bits can form 2 to the 8th power, or 256, combinations of 0s and 1s.

The 8 bits are numbered starting from 0 at the right end, then 1, 2, ..., 7 going left. Bit 0 is called the **least significant bit** (LSB), and bit 7 is called the **most significant bit** (MSB).

## 2.2 Binary

In the decimal numbers we use every day, each digit is worth 10 times the digit to its right. 345 is 3 x 100 + 4 x 10 + 5 x 1.

**Binary** is a way of writing numbers in which each digit is worth 2 times the digit to its right. The only digits are 0 and 1. The weights of the 8 bits, from the left, are as follows.

| Bit number | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Weight | 128 | 64 | 32 | 16 | 8 | 4 | 2 | 1 |

In this manual, a binary number starts with `%`. In `%01101001`, the bits with weights 64, 32, 8, and 1 are 1, so the value is 64 + 32 + 8 + 1 = 105.

To **convert binary to decimal**, add up the weights of the bits that are 1.

To **convert decimal to binary**, go from the largest weight down and check whether you can subtract it. For 200:

1. You can subtract 128 from 200. 72 remains. Bit 7 is 1.
2. You can subtract 64 from 72. 8 remains. Bit 6 is 1.
3. 8 is smaller than 32, so bit 5 is 0. It is smaller than 16, so bit 4 is 0.
4. You can subtract 8 from 8. 0 remains. Bit 3 is 1.
5. Nothing remains, so bits 2, 1, and 0 are 0.

The result is `%11001000`.

## 2.3 Hexadecimal

Binary takes many digits and is hard to read. It takes 8 digits for 8 bits and 16 digits for 16 bits. So we use **hexadecimal**, which groups 4 bits at a time and writes them as one digit.

Four bits have 16 combinations, from 0 to 15. One hexadecimal digit stands for 0 to 15. For 10 to 15, it uses the letters A to F.

| Decimal | Binary | Hex | | Decimal | Binary | Hex |
|---|---|---|---|---|---|---|
| 0 | %0000 | 0 | | 8 | %1000 | 8 |
| 1 | %0001 | 1 | | 9 | %1001 | 9 |
| 2 | %0010 | 2 | | 10 | %1010 | A |
| 3 | %0011 | 3 | | 11 | %1011 | B |
| 4 | %0100 | 4 | | 12 | %1100 | C |
| 5 | %0101 | 5 | | 13 | %1101 | D |
| 6 | %0110 | 6 | | 14 | %1110 | E |
| 7 | %0111 | 7 | | 15 | %1111 | F |

In the 6502 world, a hexadecimal number starts with `$`. `$A0` is the hexadecimal number A0. This manual follows that convention.

To **convert between binary and hexadecimal**, split the number into groups of 4 bits and look each group up in the table.

- Split `%10100000` into groups of 4 bits, and you get `1010` and `0000`. From the table, these are A and 0. The result is `$A0`.
- In `$3C`, 3 is `0011` and C is `1100`. The result is `%00111100`.

To **convert hexadecimal to decimal**, multiply the upper digit by 16 and add the lower digit. For `$A0`, A is 10, so it is 10 x 16 + 0 = 160.

To **convert decimal to hexadecimal**, divide by 16. The quotient is the upper digit and the remainder is the lower digit. Dividing 200 by 16 gives a quotient of 12 and a remainder of 8. 12 is C, so the result is `$C8`.

A 16-bit value is written with 4 hexadecimal digits. Think of `$1234` as the upper 2 digits `$12` and the lower 2 digits `$34`.

> **Column: Different Ways to Write Hexadecimal**
>
> The way to write hexadecimal differs by language and tool. In 6502 assemblers, a `$` prefix is common. In C and similar languages, you add `0x` and write `0xA0`. In Intel-style assemblers, you add an `h` at the end and write `0A0h`. All of them mean the same number.

> **What you can try in Glow65**
>
> The data bus LEDs on the panel are 8 LEDs, D7 to D0. An LED lights when the corresponding bit of the value on the bus is 1. When the value is `$A0` (`%10100000`), two LEDs light, D7 and D5. The address bus has 16 LEDs, A15 to A0.
>
> To see `$A0` on the LEDs, run `LDA #$A0` and read the A register LEDs.
>
> 1. In the monitor, enter `E 0300 A9 A0 8D F0 03 4C 00 03` and run `G 0300`. The program repeats `LDA #$A0`, `STA $03F0`, and `JMP $0300`.
> 2. Set **RUN/STOP** to STOP to stop the CPU. Set **STEP MODE** to INSTR.
> 3. Press **STEP** until INSTRUCTION AT PC shows `LDA #$A0`, then press it once more.
>
> Right after `LDA #$A0` runs, A7 and A5 are lit on the A register LEDs (Figure 2-1). On the DATA BUS, D7 and D5 are lit too, because the operand just read was `$A0`. The ADDRESS BUS shows `$0301`, the address the operand was read from. The most significant bit is 1, so the N flag LED is lit as well.
>
> ![The panel after LDA #A0. A is A0, the data bus is A0, and N is lit](../ja/images/02-gui-lda-a0.png)
>
> Figure 2-1 After `LDA #$A0`. The A LEDs are A7 and A5, the DATA BUS is D7 and D5, and the ADDRESS BUS is `$0301`

## 2.4 Range of Numbers

The numbers that 8 bits can represent run from 0, when all bits are 0, to 255, when all bits are 1. In hexadecimal, that is `$00` to `$FF`.

With 16 bits, the range is 0 to 65535, or `$0000` to `$FFFF`. 65535 is 2 to the 16th power minus 1.

| Bits | Range (decimal) | Range (hex) |
|---|---|---|
| 8 | 0 to 255 | `$00` to `$FF` |
| 16 | 0 to 65535 | `$0000` to `$FFFF` |

If a calculation goes beyond the range, the digits that do not fit are discarded. In 8 bits, 255 + 1 gives 0, not 256. The fact that a digit overflowed is recorded in a marker (a flag) called the **carry**. Chapter 6 explains the carry.

## 2.5 Negative Numbers and Two's Complement

All a CPU has is strings of bits. Negative numbers are also represented as strings of bits. The 6502 uses a method called **two's complement**.

In two's complement, if the most significant bit (bit 7) is 1, the value is read as negative, and if it is 0, as zero or positive. This bit is called the **sign bit**. The range that 8 bits can represent is -128 to 127.

| Binary | Hex | Read as unsigned | Read as signed |
|---|---|---|---|
| %00000000 | `$00` | 0 | 0 |
| %00000001 | `$01` | 1 | 1 |
| %01111111 | `$7F` | 127 | 127 |
| %10000000 | `$80` | 128 | -128 |
| %11111111 | `$FF` | 255 | -1 |

The same `$FF` is either 255 or -1, depending on how you read it. The CPU does not know which way you are reading it. The person writing the program decides.

**To make a negative number**, follow two steps. For -5:

1. Flip every 0 and 1 in the binary form of 5, `%00000101`. This gives `%11111010`.
2. Add 1. This gives `%11111011`, which is `$FB`.

**To check the result**, add 256. `$FB` is 251, and 251 - 256 is -5. Also, adding 5 to `$FB` gives 256, which wraps back to 0 in 8 bits.

Two's complement has the advantage that signed numbers can be calculated with the same addition circuit as unsigned numbers.

> **What you can try in Glow65**
>
> The branch instruction `BNE` holds its destination as a distance (a 1-byte signed number) from the next instruction. With `L` in the monitor, you can see how the distance byte turns into a destination address.
>
> ```
> *E 0300 D0 FB
> *L 0300 0301
> 0300  D0 FB     BNE   $02FD
> ```
>
> `BNE` is a 2-byte instruction, so the next instruction is at `$0302`. The distance `$FB` is -5. Going back 5 from 0302 gives `$02FD`. With `D0 7F` (distance +127) the display is `BNE $0381`, and with `D0 F0` (distance -16) it is `BNE $02F2`.
>
> You can also check two's complement on the A LEDs. With the same steps as in 2.3, enter `E 0300 A9 FB 8D F0 03 4C 00 03`, run it, and stop after `LDA #$FB`. On the A LEDs, only A2 is off, so the pattern is `%11111011` (`$FB`, -5) (Figure 2-2). The most significant bit is 1, so the N flag is lit too. The CPU can read this value as unsigned 251 or as signed -5.
>
> ![The panel after LDA #FB. A is FB and N is lit](../ja/images/02-gui-lda-fb.png)
>
> Figure 2-2 After `LDA #$FB`. Every A LED except A2 is lit

## 2.6 Character Codes (ASCII)

Computers also represent characters with numbers. A table that decides which number is assigned to which character is called a **character code**. For letters, digits, and symbols, an assignment called ASCII is widely used. ASCII is what the Glow65 UART sends and receives.

The main ASCII assignments are as follows.

| Character | Code | Note |
|---|---|---|
| `0` to `9` | `$30` to `$39` | Digit characters. `0` is `$30` and `9` is `$39` |
| `A` to `Z` | `$41` to `$5A` | Uppercase. `A` is `$41` |
| `a` to `z` | `$61` to `$7A` | Lowercase. `a` is `$61` |
| CR | `$0D` | Line break (carriage return). Sent by the Return key |

The digit character `7` is not the number 7. It is the code `$37`. To get the number 7 from the character `7`, subtract `$30`.

Uppercase and lowercase letters differ in code by exactly `$20`. `A` (`$41`) and `a` (`$61`) are an example.

ASCII fits in 7 bits. The most significant bit of an 8-bit byte is not used. The `CHROUT` routine of the Glow65 monitor discards the most significant bit of the byte it outputs (see the jump table in the README).

> **What you can try in Glow65**
>
> You write UART data to `$A001`. If you build a program with `LDA #$48` and `STA $A001`, `H` (`$48`) appears on the terminal. The following is a 16-byte program that sends `H`, `I`, and CR in order. Run it with `G`, and the final `60` (`RTS`) returns to the monitor.
>
> ```
> *E 0300 A9 48 8D 01 A0 A9 49 8D 01 A0 A9 0D 8D 01 A0 60
> *G 0300
> HI
> ```
>
> Sending `$0D` makes the terminal display move to a new line.

## 2.7 Memory and Addresses

Programs and data are placed in **memory**. Memory is a shelf with a row of boxes, each holding one byte. The boxes are numbered in order from the start. This number is the **address**.

A 6502 address is 16 bits. The numbers it can express run from `$0000` to `$FFFF`, 65,536 in all. Each box is 1 byte, so the total is 65,536 bytes. If 1 KB (kilobyte) is 1,024 bytes, this is 64 KB. This whole range is called the **address space**.

Placing a 16-bit address in memory takes 2 bytes. The 6502 places the **lower byte first** and the upper byte next. This ordering is called **little-endian**.

For example, if you place the address `$1234` starting at `$0300`, it looks like this.

| Address | `$0300` | `$0301` |
|---|---|---|
| Content | `$34` (low) | `$12` (high) |

The order is the reverse of how it looks when written, so be careful when you read it.

> **What you can try in Glow65**
>
> You can check reading and writing memory with these three commands.
>
> - `E` writes bytes in order, starting from the address you give.
> - `D` displays the contents of memory in hexadecimal. The display is in units of 16 bytes, showing 16 from the start address.
> - `L` reads the contents of memory as instructions.
>
> Here is an example that places `$1234` low byte first.
>
> ```
> *E 0300 34 12
> *D 0300 0301
> 0300: 34 12 00 00 00 00 00 00 00 00 00 00 00 00 00 00
> ```
>
> `$0300` holds `34` and `$0301` holds `12`. The first 2 bytes are in the order low, high.
>
> You can check the same thing in BASIC. Enter `B` in the monitor to start BASIC, press Return twice, and type the following.
>
> ```
> POKE 768,52 : POKE 769,18
> PRINT PEEK(769)*256+PEEK(768)
>  4660
> ```
>
> 768 is `$0300`, 52 is `$34`, and 18 is `$12`. Multiply the upper byte by 256 and add the lower byte, and you get 4660. 4660 is the decimal form of `$1234`.

There is also an example of a 16-bit value stored in 2 bytes inside the 6502 itself. When power is turned on, or on an interrupt, the CPU reads the 6 bytes from address `$FFFA` to `$FFFF`. There, three destination addresses are lined up in little-endian order. Chapter 6 explains this in detail.

> **What you can try in Glow65**
>
> You can see the last 6 bytes with the monitor command `D FFF0 FFFF`.
>
> ```
> *D FFF0 FFFF
> FFF0: FF FF FF FF FF FF FF FF FF FF 1E F4 2A F1 21 F4
> ```
>
> The last 6 bytes are three pairs: `1E F4`, `2A F1`, and `21 F4`. Because it is little-endian, they read as `$F41E`, `$F12A`, and `$F421`. The `$F12A` at `$FFFC` and `$FFFD` is the address the CPU jumps to first when power is turned on.

## 2.8 ROM, RAM, and I/O

An address space is not always made of only one kind of part. Parts with different roles are connected using the same way of assigning addresses.

- **RAM** is memory you can read and write. Its contents disappear when the power is turned off. It holds program variables and working data.
- **ROM** is read-only memory. Its contents remain when the power is turned off. It holds the program that runs at startup.
- **I/O** (input and output) is the window to devices outside. A device is assigned to some of the memory addresses. Reading or writing those addresses means exchanging data with the device. This method is called memory-mapped I/O.

The Glow65 address space is used as follows (the same content as the "Memory map" in the README).

| Address | Type | Content |
|---|---|---|
| `$0000-$7FFF` | RAM | 32KB |
| `$0200-$027F` | Inside RAM | The monitor's line input buffer |
| `$0300-$03F7` | Inside RAM | Area left free for your own programs |
| `$03F8-$03F9` | Inside RAM | Address of the NMI handler |
| `$03FA-$03FB` | Inside RAM | Address of the IRQ and BRK handler |
| `$0400-$7FFF` | Inside RAM | BASIC programs and variables |
| `$A000` | I/O | UART status and control |
| `$A001` | I/O | UART data |
| `$C000-$EFFF` | ROM | Microsoft BASIC (about 8.6KB used) |
| `$F000-$FFFF` | ROM | Monitor and vectors (`$FFFA-$FFFF`) |

`$A000-$A0FF` is assigned to the UART. Even addresses work as status and control, and odd addresses work as data. The ones normally used are `$A000` and `$A001`. Nothing is connected to the addresses not listed in the table above. Reading them returns `$FF`. Writing to ROM does not change its contents.

The UART is a device for exchanging data with a terminal. A byte written to `$A001` goes out to the terminal, and a byte typed on the terminal can be read from `$A001`. `$A000` is the status that tells whether a byte can be received or sent. Chapter 7 explains how to use it in detail.

> **What you can try in Glow65**
>
> An address with nothing connected reads as `$FF`.
>
> ```
> *D 8000 800F
> 8000: FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
> ```
>
> A write to ROM is ignored. `$F000` is ROM and holds the monitor's first `JMP` (`$4C`).
>
> ```
> *E F000 00
> *D F000 F00F
> F000: 4C 0F F0 4C 28 F0 4C 37 F0 4C 4B F1 4C 1A F0 AD
> ```
>
> After `E F000 00`, `$F000` is still `4C`. If you do the same operation on RAM at `$0300`, the value you wrote stays (the example in 2.7).

## 2.9 Practice Problems

The answers and how to solve them are in the next section.

**Problem 1** Convert the following binary numbers to decimal. (1) `%10110101` (2) `%01100110`

**Problem 2** Convert the following decimal numbers to 8-bit binary. (1) 200 (2) 77

**Problem 3** Convert the following hexadecimal numbers to decimal. (1) `$2F` (2) `$C8`

**Problem 4** Convert the following decimal numbers to hexadecimal. (1) 100 (2) 173

**Problem 5** Convert the following hexadecimal numbers to binary. (1) `$5A` (2) `$E3`

**Problem 6** Convert `%10010110` to hexadecimal.

**Problem 7** Write the following numbers in 8-bit two's complement, in hexadecimal. (1) -3 (2) -100

**Problem 8** Read the following 8-bit values as signed numbers and give them in decimal. (1) `$F0` (2) `$80`

**Problem 9** Adding `$01` to `$7F` in 8 bits gives `$80`. (1) Read as unsigned numbers, it changes from what value to what value? (2) Read as signed numbers, it changes from what value to what value?

**Problem 10** Give the ASCII codes of the string `HI` in hexadecimal. The code of the character `7` is `$37`. Give the calculation that gets the number 7 from this character.

**Problem 11** `$0300` holds `5A` and `$0301` holds `02`. If these 2 bytes are a 16-bit address, what is it? Also write how to check your answer with the Glow65 monitor.

**Problem 12** How many bytes are in each of the following address ranges? (1) `$0400` to `$7FFF` (2) `$0300` to `$03F7`

## 2.10 Answers and Solutions

**Problem 1** (1) 181 (2) 102

- (1) 128 + 32 + 16 + 4 + 1 = 181
- (2) 64 + 32 + 4 + 2 = 102

**Problem 2** (1) `%11001000` (2) `%01001101`

- (1) See 2.2 in the text. 128 + 64 + 8 = 200.
- (2) Subtracting 64 from 77 leaves 13. Subtracting 8, 4, and 1 from 13 leaves 0. Bits 6, 3, 2, and 0 are 1.

**Problem 3** (1) 47 (2) 200

- (1) 2 x 16 + 15 = 47
- (2) 12 x 16 + 8 = 200

**Problem 4** (1) `$64` (2) `$AD`

- (1) Dividing 100 by 16 gives a quotient of 6 and a remainder of 4.
- (2) Dividing 173 by 16 gives a quotient of 10 and a remainder of 13. 10 is A and 13 is D.

**Problem 5** (1) `%01011010` (2) `%11100011`

- (1) 5 is `0101` and A is `1010`.
- (2) E is `1110` and 3 is `0011`.

**Problem 6** `$96`

- `1001` is 9 and `0110` is 6.

**Problem 7** (1) `$FD` (2) `$9C`

- (1) 3 is `%00000011`. Flipping gives `%11111100`, and adding 1 gives `%11111101`, which is `$FD`.
- (2) 100 is `$64`, or `%01100100`. Flipping gives `%10011011`, and adding 1 gives `%10011100`, which is `$9C`. Check: `$9C` is 156, and 156 - 256 is -100.

**Problem 8** (1) -16 (2) -128

- (1) `$F0` is 240. 240 - 256 = -16.
- (2) `$80` is 128. 128 - 256 = -128. The value with only the most significant bit set to 1 is the smallest number in 8 bits.

**Problem 9** (1) From 127 to 128 (2) From 127 to -128

- The same change in bits is only an increase of 1 when read as unsigned numbers. When read as signed numbers, the value jumps from the largest number to the smallest number.

**Problem 10** `HI` is `$48 $49`. The number 7 is `$37 - $30 = 7`.

- `H` is `$48` and `I` is `$49`. Subtracting `$30` from a digit character gives the number.

**Problem 11** `$025A` (602 in decimal)

- The lower byte comes first, so the upper byte is `$02` and the lower byte is `$5A`.
- To check in the monitor, enter `E 0300 5A 02`, then display the contents with `D 0300 0301`. The display starts with `5A 02`.
- In BASIC, `POKE 768,90 : POKE 769,2` followed by `PRINT PEEK(769)*256+PEEK(768)` gives 602.

**Problem 12** (1) 31,744 bytes (2) 248 bytes

- (1) `$7FFF - $0400 + 1`. `$7FFF` is 32767 and `$0400` is 1024. 32767 - 1024 + 1 = 31744.
- (2) `$03F7 - $0300 + 1`. 1015 - 768 + 1 = 248.

Next chapter: [3. Inside the CPU →](03-cpu.md)
