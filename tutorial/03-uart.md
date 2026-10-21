# Tutorial 3: talking to the UART

[English](03-uart.md) | [日本語](03-uart.ja.md) &nbsp;·&nbsp; [← 2. Addition](02-addition.md) &nbsp;·&nbsp; [4. Reading the keyboard →](04-echo.md)

So far your programs only changed memory. In this chapter a program prints text in the terminal, by writing to the UART directly. Everything below was run on Glow65 and checked by `Tests/Glow65Tests/TutorialChapterTests.swift`.

## 1. The UART is two addresses

An address on the bus does not always lead to RAM. Glow65 has a serial port (a UART, modelled on the MC6850) at two addresses. Reading or writing them talks to the device instead:

| Address | Read | Write |
|---|---|---|
| `$A000` | status: bit 0 = a received character is waiting, **bit 1 = ready to send** | control |
| `$A001` | the received character | **send this character** |

The terminal in the app is on the other end of that port. To print a character, a program waits until bit 1 of the status is set, then writes the character to `$A001`. (In Glow65 the UART is never busy, so the wait always ends at once. A real UART sends bits slowly, so the wait matters there. Write it anyway.)

## 2. The program

[`hello.s`](hello.s) sends "HELLO, GLOW65" and a line break:

```
        ldx #$00            ; X = index into the message
next:   lda message,x       ; fetch the next character
        beq done            ; a 0 byte marks the end of the message
        tay                 ; keep the character in Y while we check the UART
wait:   lda UART_STATUS
        and #$02            ; is the transmit register empty?
        beq wait            ; no: look again
        tya                 ; yes: get the character back
        sta UART_DATA       ; send it
        inx
        jmp next
done:   rts
message:
        .byte "HELLO, GLOW65", $0D, $0A, $00
```

- `lda message,x` reads the byte at `message + X`. Counting X up walks through the text.
- Loading the status into A would destroy the character, so the program parks the character in Y with `tay` and gets it back with `tya`.
- `and #$02` keeps only bit 1. If the result is 0 the UART is not ready, and `beq wait` tries again.
- `$0D, $0A` are the carriage return and line feed, so the next prompt starts on a new line. The final `$00` ends the message.

## 3. Load and run it

Load `hello.bin` (`swift run Glow65App --load tutorial/hello.bin@0300`, or **File → Load Program…**), or type the code and the message separately (40 bytes in all):

```
E 0300 A2 00 BD 18 03 F0 10 A8 AD 00 A0 29 02 F0 F9 98 8D 01 A0 E8 4C 02 03 60
E 0318 48 45 4C 4C 4F 2C 20 47 4C 4F 57 36 35 0D 0A 00
L 0300 0317
```

`L` prints:

```
0300  A2 00     LDX   #$00
0302  BD 18 03  LDA   $0318,X
0305  F0 10     BEQ   $0317
0307  A8        TAY
0308  AD 00 A0  LDA   $A000
030B  29 02     AND   #$02
030D  F0 F9     BEQ   $0308
030F  98        TYA
0310  8D 01 A0  STA   $A001
0313  E8        INX
0314  4C 02 03  JMP   $0302
0317  60        RTS
```

The message starts at `$0318`. If you list past `$0317`, the text shows up as nonsense instructions (`PHA`, ...): `L` cannot tell code from data.

Run it:

```
G 0300
```

```
HELLO, GLOW65
*
```

The text comes out of your program, and `rts` returns to the monitor.

## 4. See it on the panel

At full speed you can already see it work: each character makes the **WRITE** and **TX** LEDs flash. To look at one character, turn the program into a loop (`E 0317 4C 00 03` replaces `rts` with `jmp $0300`), run it with `G 0300`, and then set **SPEED** to **10 Hz** and **RUN/STOP** to STOP. The terminal fills with lines at first, because the loop prints the message over and over before you slow it down. If you set **G SPEED** to **10 Hz** first, the program runs at 10 Hz from the moment you type `G 0300`, so the terminal does not fill up. Press RESET to go back to the monitor, and SPEED returns to the previous speed. Then set **STEP MODE** to CYCLE and press **STEP** until the **WRITE** LED lights with `STA $A001` under INSTRUCTION AT PC:

You stopped the loop at an arbitrary place, so the character you see first may be any letter of the message. Keep pressing STEP until WRITE lights, and read the rows:

| LED row | What you see when the program writes a character |
|---|---|
| ADDRESS BUS | always `$A001`: **A15**, **A13** and **A0** lit |
| DATA BUS | the ASCII code of the character. `H` is `$48` (**D6** and **D3** lit); then `E`, `L`, `L`, `O` are `$45`, `$4C`, `$4C`, `$4F` |
| WRITE | lit |

Before each write there is a read of `$A000`: the program asking the UART whether it is ready.

## 5. A shorter way: use the monitor's routine

The monitor already has a routine that waits and sends one character: `CHROUT` at `$F003` (its address is fixed, so your programs can call it). [`hello_monitor.s`](hello_monitor.s) is hello.s without the waiting loop:

```
        ldx #$00
next:   lda message,x
        beq done
        jsr $F003           ; the monitor waits and sends A
        inx
        jmp next
done:   rts
```

It is 31 bytes. To type it in, with the message at `$030F`:

```
E 0300 A2 00 BD 0F 03 F0 07 20 03 F0 E8 4C 02 03 60
E 030F 48 45 4C 4C 4F 2C 20 47 4C 4F 57 36 35 0D 0A 00
G 0300
```

It prints the same text. BASIC's output goes through the same `CHROUT`.

## 6. Experiments

1. **Your own message.** Press RESET, then `E 0318 47 4F 4F 44 0D 0A 00` (GOOD, a line break, and the end marker), and `G 0300`. Leave out `0D 0A` and the next prompt appears right after the text. Keep the message short: it must not run into `$03F0`.
2. **Another ASCII code.** `E 0318 41 42 43 0D 0A 00` prints `ABC`. Letters go up one code at a time, so you can print `DEF` by adding 3 to each byte.
3. **Receiving.** Bit 0 of the status says that a character has arrived, and reading `$A001` returns it. A program that waits for bit 0, reads the character and sends it back is an echo. Try writing it with the same pieces.

Next: [4. Reading the keyboard →](04-echo.md)

[← 2. Addition](02-addition.md)
