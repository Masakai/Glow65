# Tutorial 2: addition and the carry flag

[English](02-addition.md) | [日本語](02-addition.ja.md) &nbsp;·&nbsp; [← 1. LED counter](README.md) &nbsp;·&nbsp; [3. The UART →](03-uart.md)

The 6502 adds eight bits at a time. To add numbers bigger than 255 you add the low bytes, then the high bytes, and pass the **carry** from one step to the next. In this chapter you write a 16-bit addition and watch the carry flag move between the two halves. Everything below was run on Glow65 and checked by `Tests/Glow65Tests/TutorialChapterTests.swift`.

## 1. The program

[`add.s`](add.s) computes `SUM = A + B`. Each number takes two bytes, **low byte first**:

| Number | Low byte | High byte |
|---|---|---|
| A | `$03F0` | `$03F1` |
| B | `$03F2` | `$03F3` |
| SUM | `$03F4` | `$03F5` |

```
        clc             ; no carry goes into the low byte
        lda A_LO        ; low bytes first
        adc B_LO        ; A = A_LO + B_LO
        sta SUM_LO
        lda A_HI        ; then the high bytes
        adc B_HI        ; A = A_HI + B_HI + the carry from the low bytes
        sta SUM_HI
        rts             ; back to the monitor
```

`adc` means "add with carry": it adds the memory byte **and** the carry flag. `clc` clears the carry first, so the low-byte addition starts clean. If the low-byte addition overflows past 255, the CPU sets the carry flag, and the second `adc` adds it into the high byte.

The program ends with `rts`. The monitor's `G` command calls your program as a subroutine, so `rts` brings you back to the `*` prompt.

## 2. Load it

Load `add.bin` the way you did in chapter 1 (`swift run Glow65App --load tutorial/add.bin@0300`, or **File → Load Program…**), or type the 20 bytes:

```
E 0300 18 AD F0 03 6D F2 03 8D F4 03 AD F1 03 6D F3 03 8D F5 03 60
L 0300 0313
```

`L` should print:

```
0300  18        CLC
0301  AD F0 03  LDA   $03F0
0304  6D F2 03  ADC   $03F2
0307  8D F4 03  STA   $03F4
030A  AD F1 03  LDA   $03F1
030D  6D F3 03  ADC   $03F3
0310  8D F5 03  STA   $03F5
0313  60        RTS
```

If you list further than `$0313`, you will see `BRK` lines. Those are just zero bytes in empty memory: `L` cannot tell code from data.

## 3. Run it

Put numbers in A and B, run the program, and look at the result:

```
E 03F0 05 00 07 00
G 0300
D 03F0 03F5
```

A is `$0005`, B is `$0007`. The first six bytes of the dump are `05 00 07 00 0C 00`, so SUM is `$000C` (12). The `*` prompt comes back by itself.

Now an addition that needs the carry. `$01FF + $0001`:

```
E 03F0 FF 01 01 00
G 0300
D 03F0 03F5
```

The first six bytes are `FF 01 01 00 00 02`: SUM is `$0200`. The low bytes `$FF + $01` do not fit in a byte, so the low byte of the sum is `$00` and the carry is passed on. The high bytes then add up to `$01 + $00 + 1 = $02`.

## 4. Watch the carry

The program is over in a few microseconds. To watch it, turn it into a loop: replace the final `rts` with `jmp $0300`.

```
E 03F0 FF 01 01 00
E 0313 4C 00 03
G 0300
```

The prompt does not come back, because the program now repeats forever. Then:

1. Set **SPEED** to **10 Hz**, and switch **RUN/STOP** to STOP.
2. Set **STEP MODE** to INSTR, and press **STEP** until **INSTRUCTION AT PC** shows `0300  18  CLC`. (The CPU was stopped somewhere inside the loop, so it may take up to eight presses.)
3. Keep pressing STEP. After each press, look at the **A** LEDs and at the **C** flag in the STATUS P row (the rightmost LED):

| Press | Instruction at PC before the press | A after | C after | What happened |
|---|---|---|---|---|
| 1 | `0300  CLC` | unchanged | 0 | the carry is cleared |
| 2 | `0301  LDA $03F0` | `$FF` | 0 | A = low byte of A |
| 3 | `0304  ADC $03F2` | `$00` | **1** | `$FF + $01 = $100`: the low 8 bits are 0, the carry is 1. The Z flag lights too |
| 4 | `0307  STA $03F4` | `$00` | 1 | the low byte of the sum is stored |
| 5 | `030A  LDA $03F1` | `$01` | 1 | A = high byte of A. `lda` does not change C |
| 6 | `030D  ADC $03F3` | `$02` | 0 | `$01 + $00 +` the carry (1) `= $02`, and no new carry |
| 7 | `0310  STA $03F5` | `$02` | 0 | the high byte of the sum is stored |
| 8 | `0313  JMP $0300` | `$02` | 0 | back to the start |

The carry lights at press 3 and is used up at press 6. That is the whole idea of multi-byte arithmetic.

## 5. Experiments

Press RESET first, and put the `rts` back with `E 0313 60` (the loop version never returns to the monitor). The numbers in `$03F0-$03F5` are kept.

1. **Overflow.** `E 03F0 FF FF 01 00`, then `G 0300` and `D 03F0 03F5`. SUM is `$0000`. The carry out of the high byte is not stored anywhere, so a 16-bit sum wraps around.
2. **Subtract.** Subtraction works the same way, with the carry flag acting as "no borrow": `sec` before the first `sbc`. Change the opcodes with `E 0300 38` (`sec`), `E 0304 ED F2 03` (`sbc $03F2`) and `E 030D ED F3 03` (`sbc $03F3`). With A = `$0200` and B = `$0001` (`E 03F0 00 02 01 00`), SUM becomes `$01FF`.
3. **Make it 24 bits.** Add a third byte to each number, and one more `lda` / `adc` / `sta` to the program. Keep the order: low byte first, carry passed along.

Next: [3. The UART →](03-uart.md)
