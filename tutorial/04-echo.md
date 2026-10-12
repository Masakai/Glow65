# Tutorial 4: reading the keyboard, an echo program

[English](04-echo.md) | [日本語](04-echo.ja.md) &nbsp;·&nbsp; [← 3. The UART](03-uart.md)

Chapter 3 sent characters out through the UART. This chapter reads them in. The program waits for a key, reads it, and sends it back, so what you type appears on the screen. Everything below was run on Glow65 and checked by `Tests/Glow65Tests/TutorialChapterTests.swift`.

## 1. Why the screen needs an echo

The terminal in the app does not show your keys by itself. A key goes to the UART, and the terminal shows only what the UART sends out. When you type in the monitor, the **monitor** reads each key and sends it back; that is why you see it.

So a program that wants to show typed text has to do the same: read, then send. That is an echo.

Receiving uses the same two registers as sending:

| Address | Read | Write |
|---|---|---|
| `$A000` | status: **bit 0 = a received character is waiting**, bit 1 = ready to send | control |
| `$A001` | **the received character** (reading it removes it from the UART) | send a character |

A program cannot know when a key will be pressed, so it **polls**: it reads the status again and again until bit 0 is set.

## 2. The program

[`echo.s`](echo.s):

```
loop:   lda UART_STATUS
        and #$01            ; has a character arrived?
        beq loop            ; no: look again
        lda UART_DATA       ; yes: read it
        cmp #$0D            ; is it Enter?
        beq done            ; yes: finish
        tay                 ; keep the character in Y
send:   lda UART_STATUS
        and #$02            ; ready to send?
        beq send            ; no: look again
        tya
        sta UART_DATA       ; send it back
        jmp loop
done:   lda #$0D            ; send a line break
        jsr CHROUT
        lda #$0A
        jsr CHROUT
        rts
```

- The first three lines are the waiting loop. `and #$01` keeps bit 0 of the status. While it is 0, `beq loop` goes round again.
- `cmp #$0D` compares A with the code of Enter. If they are equal, the Z flag is set and `beq done` jumps. Without this exit the program would never return to the monitor.
- The middle part is the sending code from chapter 3.
- At the end it sends a carriage return and a line feed through the monitor's `CHROUT` (`$F003`), so the prompt starts on a new line.

## 3. Load and run it

Load `echo.bin` (`swift run Glow65App --load tutorial/echo.bin@0300`, or **File → Load Program…**), or type the 40 bytes:

```
E 0300 AD 00 A0 29 01 F0 F9 AD 01 A0 C9 0D F0 0F A8 AD 00 A0 29 02 F0 F9 98 8D 01 A0 4C 00 03 A9 0D 20 03 F0 A9 0A 20 03 F0 60
L 0300 0327
```

`L` prints:

```
0300  AD 00 A0  LDA   $A000
0303  29 01     AND   #$01
0305  F0 F9     BEQ   $0300
0307  AD 01 A0  LDA   $A001
030A  C9 0D     CMP   #$0D
030C  F0 0F     BEQ   $031D
030E  A8        TAY
030F  AD 00 A0  LDA   $A000
0312  29 02     AND   #$02
0314  F0 F9     BEQ   $030F
0316  98        TYA
0317  8D 01 A0  STA   $A001
031A  4C 00 03  JMP   $0300
031D  A9 0D     LDA   #$0D
031F  20 03 F0  JSR   $F003
0322  A9 0A     LDA   #$0A
0324  20 03 F0  JSR   $F003
0327  60        RTS
```

Run it and type:

```
G 0300
hello
```

Each letter is echoed by your program, not by the monitor. Press **Enter**: the program sends a line break, returns, and the `*` prompt comes back:

```
hello
*
```

## 4. Watch it on the panel

1. Run the program with `G 0300` at full speed. The prompt does not come back, because the program is waiting for a key.
2. Set **SPEED** to **10 Hz**, and type a letter in the terminal. Nothing appears yet: the CPU is now so slow that it has not looked at the UART. The letter is waiting inside the UART.
3. Watch **INSTRUCTION AT PC**. It cycles through `LDA $A000`, `AND #$01`, `BEQ $0300`: the polling loop. Whenever the program reads `$A000`, the address bus shows `$A000` (**A15** and **A13** lit), and **READ** is lit.
4. The next time round the loop, the status has bit 0 set, and `beq` no longer jumps. The program reads `$A001`: the address bus shows `$A001` (**A15**, **A13**, **A0**), the data bus shows the ASCII code of the letter (`h` is `$68`: **D6**, **D5**, **D3**), and the **RX** LED lights.
5. A few instructions later the program writes the same code to `$A001`. This time **WRITE** and **TX** light, and the letter appears in the terminal.

Before you press Enter, set **SPEED** back to 1 MHz, so the monitor is fast again.

## 5. Experiments

Press RESET first. A program loaded in RAM is still there.

1. **Finish with another key.** `E 030B 2E` changes `cmp #$0D` to `cmp #$2E`, so the program ends at `.` (ASCII `$2E`) instead of Enter. Now Enter is echoed like any other key: it moves the cursor back to the start of the line, without a line feed.
2. **Capital letters.** [`echo_upper.s`](echo_upper.s) (50 bytes, `echo_upper.bin`) echoes `a`-`z` as `A`-`Z`. Between reading the key and sending it, it adds:

   ```
   cmp #$61            ; 'a'
   bcc send_it         ; below 'a': leave it alone
   cmp #$7B            ; one past 'z'
   bcs send_it         ; 'z' or above: leave it alone
   and #$DF            ; clear bit 5
   ```

   In ASCII, `a`-`z` are `$61`-`$7A` and `A`-`Z` are `$41`-`$5A`. They differ only in bit 5 (`$20`), so `and #$DF` turns a lower-case letter into a capital. `cmp` sets the carry flag when A is greater than or equal to the operand, which is what `bcc` and `bcs` test. Load `echo_upper.bin`, run it, and type `Hello, World 123`.
3. **Count the keys.** Keep a counter in a spare memory cell (for example `$03F0`) and add 1 to it every time a character is read. After you press Enter, look at the count with `D 03F0 03FF`.

[← 3. The UART](03-uart.md)
