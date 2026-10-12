# Chapter 1: The History of the 6502

[English](01-history.md) | [日本語](../ja/01-history.md)

The 6502 is an 8-bit CPU (central processing unit, the part that executes a program's instructions) announced in 1975. The CPUs of the Apple II, the Commodore PET 2001, and the Family Computer (Famicom, sold as the NES outside Japan) are either a 6502 or a derivative of it.

Numbers such as [1] refer to the sources at the end of the chapter.

## 1.1 1975: The $25 CPU

MOS Technology of the United States announced the 6502 in September 1975 at the WESCON trade show in San Francisco [2][3]. The price was $25 per chip [3].

The design team was led by Chuck Peddle and Bill Mensch [2][3]. Peddle led the team, and Mensch is said to have designed the chip [3].

Both had been engineers at Motorola, whose company sold a CPU called the 6800. Peddle's proposal for a cheaper CPU was not accepted. In August 1974, Peddle and several other engineers left Motorola and moved to MOS Technology [3][4].

In November 1975, Motorola sued MOS Technology, claiming that former employees had used Motorola's technology. The case was settled in April 1976, and MOS Technology stopped selling the 6501, which had the same pin layout as the 6800 [4]. Sales of the 6502 continued.

## 1.2 Specifications of the 6502

The specifications of the 6502 are as follows [1].

| Item | Description |
|---|---|
| Data width | 8 bits. It handles one byte at a time |
| Address (memory location) width | 16 bits. 2 to the 16th power, so it can specify 65,536 bytes (64KB) |
| Registers | A (accumulator), X, Y, S (stack pointer), and P (status) are 8 bits. PC (program counter) is 16 bits |
| Zero page | The first 256 bytes, where the upper byte of the address is 00 |
| Clock | 1 MHz (the assumption behind the timing tables in this manual) |

1 MHz means the clock ticks 1 million times per second. Later versions ran at 2 MHz or 3 MHz [3]. The chip has about 3,500 transistors.

> **Column: How to Count the Transistors**
>
> "About 3,500" is the number usually given for the 6502's transistors. To be exact, there are 3,510 transistors that form logic. There are also 1,018 transistors used as loads. Together they make 4,528. The difference in the numbers comes from where you draw the line on what counts as a transistor [5].

> **What you can try in Glow65**
>
> The panel LEDs show the 16-bit address bus (A0 to A15) and the 8-bit data bus (D0 to D7). There are also LEDs for PC, SP, A, X, Y, and the status flags. The monitor command `D 0000 00FF` displays the whole zero page. `L 0300 0308` reads the contents of memory as instructions. The steps are in [Tutorial Chapter 1](../../tutorial/README.md).
>
> ![The Glow65 front panel and terminal. The top has the address bus, data bus, PC, SP, A, X, Y, and status LEDs; the bottom is the terminal](../../docs/assets/frontpanel.png)
>
> Figure 1-1 The Glow65 front panel while BASIC is running. The top section has the LEDs for the address bus, data bus, PC, SP, A, X, Y, and the status flags

## 1.3 Apple I and Apple II

The Apple I went on sale in July 1976. Its CPU was a 6502 running at about 1 MHz, and the price was $666.66 [6].

The Apple II began shipping on June 10, 1977 [7]. Its CPU was a 6502 at 1.023 MHz [7]. At launch the price was $1,298 for the 4KB RAM configuration and $2,638 for the configuration with up to 48KB [7].

The Apple II outputs video as an NTSC composite signal. Text is 40 columns by 24 rows. The keyboard has uppercase letters only, and sound comes from toggling a 1-bit speaker. It can save data to cassette tape. The ROM (memory that keeps its contents when the power is off) holds Integer BASIC and a machine-code monitor [8].

> **Column: The Odd Clock of 1.023 MHz**
>
> The Apple II clock is not exactly 1 MHz. An NTSC television signal contains a color signal of about 3.579545 MHz. The Apple II clock is 2/7 of that value. To be exact it is 1.022727 MHz, which is rounded to 1.023 MHz. The value comes from the same reference as the video circuit [7].

## 1.4 Commodore PET 2001

The PET 2001 is a computer from Commodore. Its CPU was a 6502 at 1 MHz, and the price was $795 [9].

The answer to "when did it go on sale?" depends on the standard you use.

| Standard | Date |
|---|---|
| Exhibition | January 1977, a prototype shown at the Winter CES (a consumer electronics trade show) |
| Shipping | About 100 units first in October 1977. To ordinary buyers in December 1977 |

Compared with the Apple II shipping (June 1977), the PET was shown first, but the Apple II shipped first [7][9].

The PET has the screen, keyboard, and cassette tape unit built into one case. The screen is monochrome, 40 columns by 25 rows. Some models had a small buzzer for sound, and some did not. The ROM holds BASIC, the KERNAL (which handles basic input and output), and the character shapes [9].

## 1.5 The Family Computer

Nintendo's Family Computer (Famicom) went on sale in 1983 [12]. The release date was July 15, and the price was 14,800 yen [10]. Its CPU is the Ricoh RP2A03, a chip that combines a core compatible with the 6502 and circuits such as the one that produces sound [10][11].

In an interview with a former Ricoh engineer (Toyofumi Takahashi), the 2A03 is described as "a chip with a 6502 CPU core and sound" [14]. A different group built the CPU core, and Takahashi was in charge of the sound circuit. Ricoh made the CPU together with the 2C02, a chip for image processing, and supplied them to Nintendo [14].

The Famicom CPU does not have the decimal mode of the 6502 (a feature that calculates numbers while keeping them in decimal) [15].

The CPU clock is about 1.79 MHz on the NTSC version for Japan. For regions using the PAL system, the chip is the RP2A07 and the clock is about 1.66 MHz [15].

> **What you can try in Glow65**
>
> The Glow65 CPU runs the decimal mode in addition to the 6502 instructions. It passes Klaus Dormann's functional test, including the decimal mode (see the "Tests" section of the README). The Famicom chip does not have this feature.

> **Column: Why the Famicom Chose the 6502**
>
> Masayuki Uemura, who was involved in developing the Famicom, describes how it came about in an official Nintendo interview. It was Ricoh, a maker of semiconductors, that recommended the 6502. At the time, the 6502 was almost unused in Japan. Uemura says that few people could understand its inner workings, so it was hard for other companies to analyze, and that was the reason for choosing it. He says engineers inside the company objected [13].

## 1.6 Other 6502-Family Chips

Here are examples of machines and chips that used the 6502 or its derivatives.

| Machine or chip | Year | Description |
|---|---|---|
| Atari 2600 | About 1977 | Uses the 6507. About 1.19 MHz [16] |
| VIC-20 | 1980 (Japan) / 1981 (worldwide) | 6502, about 1.02 MHz (NTSC) [17] |
| BBC Micro | December 1981 | 6502A, 2 MHz [18] |
| Commodore 64 | August 1982 | 6510, about 1.023 MHz (NTSC) [19] |
| 65C02 | 1983 | A CMOS version with lower power consumption. Developed by WDC [20] |
| 65816 | About 1985 | 16 bits inside, 24-bit addresses (16MB) [21] |
| PC Engine | October 30, 1987 | Hudson Soft HuC6280 (an extended 65C02) [22][23] |
| Super Famicom | November 21, 1990 | Ricoh 5A22 (a derivative of the 65816) [24] |

CMOS is a way of making transistors that uses little power.

> **Column: The 6507 with Fewer Address Pins**
>
> The CPU of the Atari 2600 is the 6507, a 6502 with some of its pins removed. The 6502 has 40 pins, and the 6507 has 28. The address pins drop from 16 to 13, so it can specify only up to 2 to the 13th power, or 8,192 bytes (8KB). It also has no interrupt pins. It was a CPU made cheaply by cutting pins. The inside of the chip is the same as the 6502 [16].

## 1.7 A 6502 You Can Buy Today

The 6502 family is still on sale. WDC (Western Design Center) lists the W65C02S on its official page. It comes in three packages: 40-pin DIP, 44-pin PLCC, and 44-pin QFP, and the official page points to distributors such as Mouser and Jameco [25].

The 6502 is an inexpensive CPU that was announced at $25. It has about 3,500 transistors, and MOS Technology published a hardware manual [1][3]. Derivatives were also made to suit different uses, including the 6507, 6510, 2A03, 65C02, 65816, and HuC6280.

## 1.8 What Glow65 Has and Does Not Have

Glow65 is an emulator of a fictional single-board computer, made for learning the 6502. The differences from three real machines are shown in the table below.

| Item | Apple II (1977) | PET 2001 (1977) | Famicom (1983) | Glow65 |
|---|---|---|---|---|
| CPU | 6502, 1.023 MHz [7] | 6502, 1 MHz [9] | RP2A03 (6502-compatible, no decimal mode), about 1.79 MHz [15] | NMOS 6502 (default). The SPEED control on the panel switches from 1 Hz to 1 MHz. The CPU switch can also select the 65C02 |
| Memory | RAM 4KB to 48KB [7] | RAM 4KB or 8KB [9] | 2KB of RAM for the CPU, 2KB of RAM for video [26] | 32KB of RAM (`$0000-$7FFF`) |
| Display | NTSC composite output, 40 columns by 24 rows [8] | Built-in monochrome screen, 40 columns by 25 rows [9] | Image processing chip 2C02, 256 x 240 dots [26] | Only a terminal connected through the UART. No dedicated graphics screen. A front panel (LEDs) shows the CPU state |
| Input | Keyboard (uppercase only) [8] | Built-in keyboard [9] | Game pads (two, fixed to the console) [26] | Keyboard input from the terminal (through the UART) |
| Sound | 1-bit speaker [8] | A small buzzer only (some models have none) [9] | 5 channels [26] | None |
| External storage | Cassette tape [8] | Built-in cassette unit [9] | None built in [26] | None. BASIC `SAVE` and `LOAD` cannot be used. File loading (File → Load Program) is a feature where the emulator writes directly into RAM |
| Software in ROM | Integer BASIC, machine-code monitor (8KB) [8] | BASIC, KERNAL, character shapes [9] | Game cartridges (the program chip is often up to 32KB) [26] | Monitor (`$F000-$FFFF`) and Microsoft BASIC (`$C000-$EFFF`) |

The BASIC in Glow65 is Microsoft's BASIC for the 6502 (v1.1 from 1978), converted for this board.

The goal of Glow65 is to let you watch how the CPU works, not to reproduce real hardware. It does not reproduce the extra dummy reads and dummy writes of the real chip, so the bus display differs slightly from an actual 6502.

## Sources

1. MOS Technology, "MCS6500 Microcomputer Family Hardware Manual", January 1976 edition: https://www.commodore.ca/wp-content/uploads/2018/11/kim1_hardware.txt
2. IEEE Spectrum, "Chip Hall of Fame: MOS Technology 6502 Microprocessor": https://spectrum.ieee.org/chip-hall-of-fame-mos-technology-6502-microprocessor
3. Wikipedia, "MOS Technology 6502": https://en.wikipedia.org/wiki/MOS_Technology_6502
4. Wikipedia, "Motorola 6800": https://en.wikipedia.org/wiki/Motorola_6800
5. Ken Shirriff, "Intel x86 documentation has more pages than the 6502 has transistors": https://www.righto.com/2013/09/intel-x86-documentation-has-more-pages.html
6. Wikipedia, "Apple I": https://en.wikipedia.org/wiki/Apple_I
7. Wikipedia, "Apple II": https://en.wikipedia.org/wiki/Apple_II
8. Wikipedia, "Apple II (original)": https://en.wikipedia.org/wiki/Apple_II_(original)
9. Wikipedia, "Commodore PET": https://en.wikipedia.org/wiki/Commodore_PET
10. Japanese Wikipedia, "ファミリーコンピュータ" (Family Computer): https://ja.wikipedia.org/wiki/ファミリーコンピュータ
11. Wikipedia, "Ricoh 2A03": https://en.wikipedia.org/wiki/Ricoh_2A03
12. 任天堂 沿革 (Nintendo company history): https://www.nintendo.co.jp/corporate/history/index.html
13. 任天堂「社長が訊く マリオ25周年 Vol.2」(Nintendo, "Iwata Asks: Mario's 25th Anniversary, Vol. 2"): https://www.nintendo.co.jp/n10/interview/mario25th/vol2/index2.html
14. 高橋豊文氏オーラルヒストリー(第2回前半)、一橋大学 IIR Working Paper WP#19-17、2019年 (Toyofumi Takahashi oral history, part 2 first half, Hitotsubashi University IIR Working Paper WP#19-17, 2019): https://pubs.iir.hit-u.ac.jp/admin/ja/pdfs/file/2267
15. NESdev Wiki, "CPU": https://www.nesdev.org/wiki/CPU
16. Wikipedia, "Atari 2600": https://en.wikipedia.org/wiki/Atari_2600
17. Wikipedia, "VIC-20": https://en.wikipedia.org/wiki/VIC-20
18. Wikipedia, "BBC Micro": https://en.wikipedia.org/wiki/BBC_Micro
19. Wikipedia, "Commodore 64": https://en.wikipedia.org/wiki/Commodore_64
20. Wikipedia, "WDC 65C02": https://en.wikipedia.org/wiki/WDC_65C02
21. Wikipedia, "WDC 65C816": https://en.wikipedia.org/wiki/WDC_65C816
22. Wikipedia, "TurboGrafx-16": https://en.wikipedia.org/wiki/TurboGrafx-16
23. Wikipedia, "Hudson Soft HuC6280": https://en.wikipedia.org/wiki/Hudson_Soft_HuC6280
24. Wikipedia, "Super Nintendo Entertainment System": https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System
25. Western Design Center, "W65C02S": https://www.westerndesigncenter.com/wdc/w65c02s-chip.php
26. Wikipedia, "Nintendo Entertainment System": https://en.wikipedia.org/wiki/Nintendo_Entertainment_System

Next chapter: [2. Computer Basics →](02-basics.md)
