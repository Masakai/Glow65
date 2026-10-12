# Tutorial 5: calling machine code from BASIC (USR)

[English](05-usr.md) | [日本語](05-usr.ja.md) &nbsp;·&nbsp; [← 4. Reading the keyboard](04-echo.md) &nbsp;·&nbsp; [6. Interrupts →](06-interrupts.md)

BASIC is easy to write and slow to run. Machine code is the opposite. BASIC's `USR` function lets you use both: write the program in BASIC, and call a machine-code routine when you need one. In this chapter the routine doubles a number. Everything below was run on Glow65 and checked by `Tests/Glow65Tests/TutorialUSRTests.swift`.

## 1. How USR works

`USR(X)` does three things:

1. BASIC works out `X` and leaves it in the **FAC**, its floating-point accumulator.
2. BASIC jumps to the **USR vector** in page zero: a `JMP` instruction at address 10 (`$0A`). The two bytes after it, at addresses 11 and 12, are the address it jumps to.
3. When your routine ends with `rts`, BASIC takes whatever is in the FAC as the value of `USR(X)`.

You can look at the vector yourself. Right after BASIC starts:

```
PRINT PEEK(10);PEEK(11);PEEK(12)
 76  219  207
```

76 is `$4C`, the opcode of `JMP`. 219 and 207 are the low and high bytes of `$CFDB`, an error routine inside BASIC. That is why `PRINT USR(21)` at this point prints `?ILLEGAL QUANTITY ERROR`. To use your own routine, **POKE its address into 11 (low byte) and 12 (high byte)**.

The FAC holds a floating-point number, which is awkward to work with in machine code. BASIC offers two helper routines, reached through vectors in page zero:

| Vector | Points to | Does |
|---|---|---|
| `$06-$07` | AYINT | FAC → 16-bit signed integer, high byte in `FACMO` (`$B4`), low byte in `FACLO` (`$B5`) |
| `$08-$09` | GIVAYF | 16-bit signed integer (A = high byte, Y = low byte) → FAC |

## 2. The program

[`usr_double.s`](usr_double.s):

```
        jsr to_integer  ; the argument, as an integer, is now in FACMO:FACLO
        asl FACLO       ; shift the low byte left; bit 7 goes into the carry
        rol FACMO       ; rotate the carry into the high byte: 16-bit X * 2
        lda FACMO       ; A = high byte
        ldy FACLO       ; Y = low byte
        jsr to_fac      ; put the integer back into the FAC
        rts

to_integer:
        jmp (ADRAYI)
to_fac: jmp (ADRGAY)
```

- `jsr` cannot jump through a vector, but `jmp (vector)` can. So the program calls a small stub with `jsr`, and the stub does `jmp (ADRAYI)`. When BASIC's routine ends with `rts`, it returns to the instruction after your `jsr`.
- `asl FACLO` / `rol FACMO` is a 16-bit shift left, which doubles the number. This is the same carry idea as in chapter 2.

## 3. Load it

The routine goes at `$0300`, as before. BASIC keeps its own program and variables from `$0400` upwards, so it does not touch `$0300-$03F7`. Load the file first, then start BASIC:

```bash
swift run Glow65App --load tutorial/usr_double.bin@0300
```

Turn **POWER** on, and in the monitor type `B` to start BASIC. Press Return at the two prompts. (Or type the 21 bytes in the monitor first: `E 0300 20 0F 03 06 B5 26 B4 A5 B4 A4 B5 20 12 03 60 6C 06 00 6C 08 00`, then `L 0300 0313` to check, then `B`.)

`L 0300 0313` shows:

```
0300  20 0F 03  JSR   $030F
0303  06 B5     ASL   $B5
0305  26 B4     ROL   $B4
0307  A5 B4     LDA   $B4
0309  A4 B5     LDY   $B5
030B  20 12 03  JSR   $0312
030E  60        RTS
030F  6C 06 00  JMP   ($0006)
0312  6C 08 00  JMP   ($0008)
```

## 4. Call it

Tell BASIC where the routine is. `$0300` is 768, so the low byte is 0 and the high byte is 3:

```
POKE 11,0:POKE 12,3
PRINT USR(21)
 42
PRINT USR(1000)
 2000
PRINT USR(-5)
-10
```

It works inside a program too:

```
FOR I=1 TO 5:PRINT USR(I);:NEXT
 2  4  6  8  10
```

BASIC is now calling your routine from its own loop. Note that BASIC starts with the vector set to the error routine every time: after you start BASIC again (or press RESET and type `B`), POKE 11 and 12 again.

## 5. The limits of the routine

The integer is a 16-bit signed number, from -32768 to 32767, and `asl`/`rol` just shifts bits:

```
PRINT USR(16383)
 32766
PRINT USR(16384)
-32768
PRINT USR(20000)
-25536
```

`16384 × 2 = 32768` does not fit, so the top bit becomes the sign bit and the result is negative. A machine-code routine does exactly what its instructions say, and nothing checks the range for you.

## 6. Printing from machine code

[`usr_hello.s`](usr_hello.s) (37 bytes) sends a message through the monitor's `CHROUT` (`$F003`), as in chapter 3. It ignores the argument and leaves the FAC alone. Load it the same way (`--load tutorial/usr_hello.bin@0300`, or `E 0300 A2 00 BD 0F 03 F0 07 20 03 F0 E8 4C 02 03 60` and the message with `E 030F 48 45 4C 4C 4F 20 46 52 4F 4D 20 41 53 53 45 4D 42 4C 59 0D 0A 00`), then:

```
POKE 11,0:POKE 12,3
A=USR(0)
HELLO FROM ASSEMBLY
10 FOR I=1 TO 3:A=USR(0):NEXT
RUN
HELLO FROM ASSEMBLY
HELLO FROM ASSEMBLY
HELLO FROM ASSEMBLY
```

`A=USR(0)` is the usual way to call a routine whose result you do not need.

## 7. Experiments

Load `usr_double` again first.

1. **Halve instead of double.** Change the four bytes at `$0303-$0306` (`asl $B5` / `rol $B4`) to `lsr $B4` / `ror $B5` (`46 B4 66 B5`). From BASIC, with `POKE`, that is addresses 771 to 774:

   ```
   POKE 771,70:POKE 772,180:POKE 773,102:POKE 774,181
   PRINT USR(42)
    21
   ```

   Your routine is in RAM, so BASIC can change it. `lsr` shifts the high byte right and puts bit 0 into the carry; `ror` rotates that carry into the low byte's top bit.
2. **Find the limit.** `PRINT USR(32767)` prints `-2` (the doubled value, 65534, wraps around). `PRINT USR(40000)` prints `?ILLEGAL QUANTITY ERROR`: the argument itself is outside -32768 to 32767, so the first helper call, FAC to integer, raises the error before your routine can use the number.
3. **Add 100.** Replace the shift with an addition: `clc`, `lda FACLO`, `adc #100`, `sta FACLO`, then add the carry into `FACMO` (`bcc` over an `inc FACMO`). The routine gets longer, so write it as a new `.s` file, assemble it with `Tools/assemble.sh`, and load the new `.bin`.

## 8. Things to remember

- Your routine may use `$0300-$03F7` freely, and the FAC and the other BASIC zero-page locations only as BASIC expects. BASIC itself uses almost all of page zero, so avoid other zero-page addresses.
- A routine called with `USR` must end with `rts`.
- From machine code you can call the monitor's routines (`CHROUT` at `$F003`, `GETKEY` at `$F00C`).

Next: [6. Interrupts →](06-interrupts.md)

[← 4. Reading the keyboard](04-echo.md)
