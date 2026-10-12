# Glow65

**English** | [日本語](README.ja.md) | [Website](https://masakai.github.io/Glow65/) | [Promo video](https://masakai.github.io/Glow65/#video) | [Manual](manual/en/README.md)

**I built this emulator to learn the 6502.** It has a GUI with LEDs that light up like the front panel of an old computer, so you can see what the CPU is doing.

A 6502 single-board computer emulator for macOS, written in Swift. It has a front panel with LEDs that show what the CPU is doing, and it runs Microsoft BASIC.

![status](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![license](https://img.shields.io/badge/license-MIT-blue)

<p align="center"><img src="documents/images/frontpanel.png" alt="The Glow65 front panel with LEDs, switches and a terminal running Microsoft BASIC" width="860"></p>

## What it is

Glow65 emulates an imaginary 6502 board: a CPU, 32 KB of RAM, a serial port (UART), and ROM holding a small monitor and Microsoft BASIC. The window has two parts:

- **Front panel.** LEDs for the address bus, data bus, PC, SP, A, X, Y, the status flags, and bus signals, and a display of the instruction at the PC (disassembled). Switches for POWER, RESET, NMI, RUN/STOP, STEP, STEP MODE and SPEED.
- **Terminal.** Connected to the UART. Use it to talk to the monitor and BASIC.

The panel is for watching the CPU work. At 1 kHz and below, each bus access is shown one at a time. At 100 kHz and above, LED brightness is the fraction of accesses in which the bit was 1, which imitates the glow of an old panel's LEDs. The extra dummy reads and writes of real hardware are not reproduced, so the bus view differs slightly from a real 6502.

The startup banner (click the (i) button on the panel to show it again) lists what is and is not original work:

<p align="center"><img src="documents/images/splash.png" alt="The Glow65 startup banner with credits" width="560"></p>

## Related resources

Glow65 is **not** entirely original work.

| Part | Origin |
|---|---|
| 6502 CPU core, board, monitor ROM, front panel, app, BASIC conversion script | Written for this project (MIT License) |
| Microsoft BASIC for 6502 v1.1 | Copyright (c) Microsoft Corporation, MIT License. Source: [microsoft/BASIC-M6502](https://github.com/microsoft/BASIC-M6502) |
| cc65 (assembler and linker) | Used to build the ROMs. zlib License. Not included |
| Klaus Dormann's 6502 functional test | Used to verify the CPU. GPLv3. Not included |

See [NOTICE.md](NOTICE.md) for details.

## Requirements

- macOS 14 or later
- Xcode (Swift 5.9 or later)
- [cc65](https://cc65.github.io/) to build the ROMs: `brew install cc65`
- Python 3 (standard library only) to convert the BASIC source

## Write your own program

Glow65 is for learning, so the first thing to try is your own program. The [tutorial](tutorial/README.md) has six chapters: [an LED counter](tutorial/README.md) (assemble or type the bytes, load, run, then slow the CPU down and step through every bus access), [16-bit addition and the carry flag](tutorial/02-addition.md), [printing text through the UART](tutorial/03-uart.md), [reading the keyboard with an echo program](tutorial/04-echo.md), [calling machine code from BASIC with `USR`](tutorial/05-usr.md), and [interrupts](tutorial/06-interrupts.md) (the NMI button and a UART receive IRQ).

To learn how the 6502 works, read the [manual](manual/en/README.md): the history of the 6502, bits and bytes, the CPU, addressing modes, all 151 instructions, flags, the stack, interrupts, and the memory map. It is also available in [Japanese](manual/ja/README.md).

## Quick start

```bash
git clone https://github.com/Masakai/Glow65.git
cd Glow65

brew install cc65
Tools/build_monitor.sh     # builds ROM/monitor.bin
Tools/build_basic.sh       # converts and builds ROM/basic/build/basic.bin

swift run Glow65App         # front panel app
```

1. Click the terminal area, then flip the **POWER** switch up. The monitor starts.
2. Type `B` and press Return to start BASIC.
3. Press Return at `MEMORY SIZE?` and `TERMINAL WIDTH?` to accept the defaults.

```
GLOW65 BASIC  (MICROSOFT BASIC V1.1 FOR 6502)
COPYRIGHT 1978 MICROSOFT

OK
10 FOR I=1 TO 5
20 PRINT I, SQR(I)
30 NEXT
RUN
```

Without `basic.bin` the app still starts, with the monitor only.

### Command-line version

```bash
swift run glow65-cli                    # run from the repository root
swift run glow65-cli --mhz 2            # change the clock
swift run glow65-cli --rom file.bin@C000
swift run glow65-cli --load tutorial/counter.bin@0300   # a program for RAM, loaded after power-on
swift run glow65-cli --cpu 65c02        # run as a 65C02 (default: 6502)
```

`--rom` replaces the default ROMs, so list every ROM you need (for example both `ROM/monitor.bin@F000` and `ROM/basic/build/basic.bin@C000`). Quit with Ctrl-\\. Ctrl-C is passed to the program (BASIC uses it to break).

### CPU type: 6502 or 65C02

The board runs an NMOS 6502 by default. Pass `--cpu 65c02` to `glow65-cli` or `Glow65App` to run it as a 65C02 (equivalent to the WDC W65C02S: the base 65C02 instructions, the Rockwell/WDC extensions BBR/BBS/RMB/SMB, and WAI/STP). `--cpu 6502` is the default. `glow65-cli` prints its usage and exits on any other value, and `Glow65App` ignores it.

In the app, the **CPU** switch on the panel chooses between them. It works only while POWER is off, and it shows the selected CPU name. The monitor's `L` command detects the CPU at run time (it executes `INC A` and checks the result) and lists the 65C02 instructions only on a 65C02, for example `BBR0  $10,$0305` or `LDA   ($12)`. On a 6502 the same bytes are listed as `.BYTE`.

Assembly for the 65C02 can be written with `.setcpu "65C02"` at the top of the source for `Tools/assemble.sh` (checked with ca65 V2.18: STZ, BRA, BBR0, RMB7, SMB3, WAI, STP and others assemble).

## Front panel

| Control | Action |
|---|---|
| POWER | On: clears RAM and starts from reset. Off: all LEDs go dark |
| RESET | Resets the CPU. RAM is kept |
| NMI | Raises a non-maskable interrupt (once per press). The monitor sends it to the handler address in RAM at `$03F8` |
| RUN/STOP | Stops or resumes the CPU |
| STEP | While stopped, runs one instruction (INSTR) or one bus access (CYCLE) |
| STEP MODE | Chooses between INSTR and CYCLE stepping |
| SPEED | 1 Hz, 10 Hz, 100 Hz, 1 kHz, 100 kHz, 1 MHz |
| CPU | Chooses 6502 (down) or 65C02 (up). Works only while POWER is off. The label shows the selected CPU |
| (i) button | Shows the credits |
| INSTRUCTION AT PC | Not a switch: the instruction at the PC, for example `0302  8D F0 03  STA $03F0`. While an instruction is replayed access by access, it shows the instruction being replayed |

While an instruction is shown access by access, the register LEDs show the values from before the instruction.

The HALT LED is on while the RUN/STOP switch is at STOP. On a 65C02 it is also on while the CPU waits after `WAI` (until an interrupt) or stops after `STP` (until RESET). In those states the RUN LED stays on, because it follows the switch. A waiting or stopped CPU uses one cycle per step and makes no bus accesses.

To load your own program, use **File → Load Program…** (⌘O) after turning POWER on, or the launch option `--load file.bin@0300`. Build a binary from assembly with `Tools/assemble.sh` (needs cc65).

For automated checks, `Glow65App --power-on --input 'd f000 f00f\r'` powers on and types the given text. `--no-splash` skips the startup banner. `--script "3:poweron;5:input=g 0300\r;10:speed=10"` runs a timed script of operations (`poweron`, `poweroff`, `reset`, `run`, `stop`, `step`, `nmi`, `speed=<Hz>`, `mode=cycle|instr`, `input=<text>`), which is handy for screen recordings.

## Memory map

| Address | Contents |
|---|---|
| `$0000-$7FFF` | RAM, 32 KB |
| `$0200-$027F` | (inside RAM) the monitor's line buffer |
| `$0300-$03F7` | (inside RAM) free for your programs |
| `$03F8-$03F9` | (inside RAM) NMI handler address (the monitor jumps through it) |
| `$03FA-$03FB` | (inside RAM) IRQ and BRK handler address (same) |
| `$0400-$7FFF` | (inside RAM) BASIC programs and variables |
| `$A000` | UART status (bit 0: receive ready, bit 1: transmit empty, bit 7: interrupt request) / control (bit 7: enable the receive interrupt) |
| `$A001` | UART data |
| `$C000-$EFFF` | Microsoft BASIC (about 8.6 KB used) |
| `$F000-$FFFF` | Monitor ROM and vectors |

The UART is a minimal MC6850-style device. It answers on all of `$A000-$A0FF`: even addresses are the status/control register and odd addresses are the data register. Other addresses that nothing is connected to (for example `$8000-$9FFF`) read as `$FF`, and writes are ignored.

The monitor has a fixed jump table that BASIC and your programs can call:

| Address | Routine |
|---|---|
| `$F000` | CHRIN: read a character (waits) |
| `$F003` | CHROUT: write a character (bit 7 is dropped) |
| `$F006` | ISCNTC: return with carry set if Ctrl-C was typed |
| `$F009` | Monitor warm start |
| `$F00C` | GETKEY: read a character without waiting (A = 0 if none) |

### Monitor commands

| Command | Action |
|---|---|
| `D aaaa [bbbb]` | Dump memory (128 bytes if the end is omitted) |
| `E aaaa bb bb ...` | Write bytes |
| `L aaaa [bbbb]` | Disassemble (16 instructions if the end is omitted) |
| `G aaaa` | Call the routine at `aaaa` (returns to the monitor on RTS) |
| `B` | Start BASIC |
| `?` | Help |

## How BASIC is built

Microsoft's source is written for a 1970s cross assembler (MACRO-10 syntax). `Tools/convert_m6502.py` converts it to ca65 syntax, and `Tools/build_basic.sh` assembles and links it. The conversion is based on the original's OSI configuration, which expects a 6850-style UART like this board's. A handful of constants are replaced (ROM address, program memory start, UART addresses, long error messages, banner). The full list is the `PATCHES` table in the script and section 12 of the [design document](documents/designs/2026-10-11-6502-sbc-emulator.md).

## Tests

```bash
swift test
```

The test suite covers the CPU, the board, the monitor, the front panel logic, and BASIC. BASIC tests are skipped if `basic.bin` has not been built.

To run Klaus Dormann's functional test, download `6502_functional_test.bin` from [Klaus2m5/6502_65C02_functional_tests](https://github.com/Klaus2m5/6502_65C02_functional_tests) (`bin_files/`) and place it at `Tests/Fixtures/klaus/6502_functional_test.bin`. It is skipped when the file is missing. A release build is much faster:

```bash
swift test -c release -Xswiftc -enable-testing --filter KlausFunctionalTests
```

The CPU core passes it (96,241,367 cycles, decimal mode included).

The 65C02 mode uses Klaus Dormann's 65C02 extended opcodes test the same way. Download `65C02_extended_opcodes_test.bin` and `65C02_extended_opcodes_test.lst` (the listing is read for the start and success addresses) from the same repository and place both in `Tests/Fixtures/klaus/`. It is skipped when they are missing. The CPU core passes it (66,907,084 cycles, BBR/BBS/RMB/SMB and decimal mode included). The test ignores the V flag in decimal mode, so the V rule in `CPU6502.adc` for the 65C02 is not verified by it. WAI and STP are not part of this test (they belong to Klaus's interrupt test, which is not used here), and are covered by unit tests only.

## Project layout

```
Sources/Core6502/     6502 CPU core and the Bus protocol (no UI dependency)
Sources/Glow65/        Board: bus, UART, machine, runner, front panel state
Sources/glow65-cli/    Command-line front end
Sources/Glow65App/     SwiftUI app: front panel, terminal, startup banner
ROM/monitor.s         Monitor ROM source (ca65)
ROM/basic/            BASIC: upstream source, prelude, linker config
Tools/                Build and conversion scripts (assemble.sh builds your own programs)
manual/               Manual: eight chapters (English and Japanese), diagram generators
tutorial/             Tutorial: six chapters (LED counter, addition, UART, echo, USR, interrupts) with sample programs
Tests/                Unit and integration tests
documents/designs/    Design document (Japanese)
```

## Limitations

- The CPU is an NMOS 6502 (default) or a 65C02 equivalent to the WDC W65C02S. On the 6502 only the official instructions are implemented, and undefined opcodes run as a 2-cycle NOP. On the 65C02 every opcode is defined (undefined ones are NOPs of the documented length and cycles). Other variants (for example the 65C02 without the Rockwell extensions, or the 65816) are not available.
- On the 65C02, dummy reads and writes are not reproduced either, as on the 6502. The decimal-mode V flag on the 65C02 follows the NMOS rule and matches Bruce Clark's published description for the 65C02 but is not verified against real hardware.
- Dummy reads and writes (for example the extra read when an index crosses a page) are not reproduced, so the cycle-by-cycle bus view differs slightly from real hardware.
- The only interrupt sources are the NMI button and the UART receive interrupt. Interrupt entry shows five bus accesses, not the real 7 cycles (dummy reads are not reproduced).
- BASIC `SAVE` and `LOAD` are not available.
- Not everything in BASIC has been tested (for example `GET`, `WAIT`, `USR`, `ON GOTO`).

## License

MIT License for the code written for this project. See [LICENSE](LICENSE). Microsoft BASIC under `ROM/basic/upstream/` has its own MIT License; see [NOTICE.md](NOTICE.md).
