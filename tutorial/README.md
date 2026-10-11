# Tutorial: your first program, an LED counter

**English** | [日本語](README.ja.md)

You will write a five-line 6502 program, load it into Glow65, and watch it count in binary on the LEDs. Everything below was run on Glow65 and checked by the tests in `Tests/Glow65Tests/TutorialTests.swift`.

## 1. The program

[`counter.s`](counter.s) adds 1 to the A register forever and writes it to memory:

```
        lda #$00        ; A = 0
loop:   sta COUNTER     ; write A to memory (COUNTER = $03F0)
        clc             ; clear the carry flag before adding
        adc #$01        ; A = A + 1
        jmp loop        ; do it again, forever
```

| Instruction | Machine code | What happens on the bus |
|---|---|---|
| `lda #$00` | `A9 00` | two reads: the opcode, then the value 0 |
| `sta $03F0` | `8D F0 03` | three reads (opcode, low and high address byte), then one **write** |
| `clc` | `18` | one read: the opcode |
| `adc #$01` | `69 01` | two reads |
| `jmp loop` | `4C 02 03` | three reads. PC goes back to `$0302` |

One trip around the loop takes 11 cycles.

## 2. Get it into the computer

You need to put the 11 bytes `A9 00 8D F0 03 18 69 01 4C 02 03` in RAM at `$0300`. `$0300-$03FF` is free for your programs. (`$0200-$027F` is the monitor's line buffer, so a program there would be overwritten by the command you type to start it.)

**Option A: type the bytes.** No tools needed. Start the app (`swift run Glow65App`), flip **POWER** up, click the terminal, and type:

```
E 0300 A9 00 8D F0 03 18 69 01 4C 02 03
L 0300 0308
```

`E` writes bytes. `L` lists them as instructions (a disassembler), so you can check that the bytes you typed are the program you meant. It should print:

```
0300  A9 00     LDA   #$00
0302  8D F0 03  STA   $03F0
0305  18        CLC
0306  69 01     ADC   #$01
0308  4C 02 03  JMP   $0302
```

(`D 0300 030F` shows the same memory as raw bytes instead.)

**Option B: assemble and load a file.** This needs [cc65](https://cc65.github.io/) (`brew install cc65`). The repository already contains the result as `counter.bin`, so you can skip the first command.

```bash
Tools/assemble.sh tutorial/counter.s        # builds tutorial/counter.bin (11 bytes)
swift run Glow65App --load tutorial/counter.bin@0300
```

`--load` loads the file into RAM every time you turn POWER on. In a running app you can also use **File → Load Program…** (⌘O), pick `counter.bin`, and leave the address at `0300`. Turn POWER on first, because powering on clears RAM.

## 3. Run it

In the monitor, type:

```
G 0300
```

The prompt does not come back. The program never returns, so the CPU is now running your loop. (To get the monitor back, press **RESET**. RAM is kept.)

At 1 MHz this loop runs about 90,000 times a second, so you cannot follow the count. The A LEDs look random because the panel samples the registers about 60 times a second.

## 4. Slow it down and watch

1. Set **SPEED** to **10 Hz**. The loop now takes a little over a second, and the panel shows each bus access in turn.
2. Watch the address bus. It walks through `$0300`, `$0301`, `$0302` and so on, so the PC LEDs and the low address LEDs change as the program advances.
3. Watch **SYNC**. It lights on the first access of every instruction (the opcode fetch).
4. Watch **WRITE**. It lights once per loop, for the `sta`. At that moment the address bus shows `$03F0` and the data bus shows the value of A.
5. Switch **RUN/STOP** to STOP, set **STEP MODE** to CYCLE, and press **STEP** repeatedly. One press is one bus access.

The first trip through the program, access by access:

| # | Address | Data | Read/Write | SYNC | Instruction |
|---|---|---|---|---|---|
| 1 | `$0300` | `A9` | read | yes | `lda #$00` |
| 2 | `$0301` | `00` | read | | |
| 3 | `$0302` | `8D` | read | yes | `sta $03F0` |
| 4 | `$0303` | `F0` | read | | |
| 5 | `$0304` | `03` | read | | |
| 6 | `$03F0` | `00` | **write** | | |
| 7 | `$0305` | `18` | read | yes | `clc` |
| 8 | `$0306` | `69` | read | yes | `adc #$01` |
| 9 | `$0307` | `01` | read | | |
| 10 | `$0308` | `4C` | read | yes | `jmp $0302` |
| 11 | `$0309` | `02` | read | | |
| 12 | `$030A` | `03` | read | | |

Two things to know about this view:

- While an instruction is being replayed, the A, X, Y, PC and flag LEDs show the values from **before** it. They change when the instruction finishes.
- A real 6502 takes 2 cycles for `clc` and does a second, dummy read of the next byte. Glow65 does not reproduce dummy reads, so `clc` shows one access. The cycle counter still counts 2.

## 5. Look at the result

Press **RESET** to stop the loop and get the monitor back, then type:

```
D 03F0 03FF
```

The first byte of the line is the last value the program wrote to `$03F0`.

## 6. Experiments

Press RESET, change a byte with `E`, check the result with `L 0300 0308`, and run it again with `G 0300`. The bytes are at these addresses:

```
0300  A9 00        lda #$00
0302  8D F0 03     sta $03F0
0305  18           clc
0306  69 01        adc #$01
0308  4C 02 03     jmp $0302
```

1. **Count by 2.** `E 0307 02` changes `adc #$01` to `adc #$02`. The A LEDs now skip the lowest bit.
2. **Write somewhere else.** `E 0303 F1` makes `sta` write to `$03F1`. Check with `D 03F0 03FF`.
3. **Count down.** `E 0305 38 E9 01` replaces `clc` / `adc #$01` with `sec` / `sbc #$01`. Same length, opposite direction. `L 0300 0308` now shows `SEC` and `SBC   #$01` at `$0305` and `$0306`.

When you are ready for more, change `counter.s`, run `Tools/assemble.sh` again, and load the new file. Programs must fit in the 256 bytes at `$0300-$03FF` (see `ROM/user.cfg`).
