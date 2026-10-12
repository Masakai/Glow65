# Tutorial 6: interrupts

[English](06-interrupts.md) | [日本語](06-interrupts.ja.md) &nbsp;·&nbsp; [← 5. USR](05-usr.md)

Until now the program asked for everything: it polled the UART status in a loop and waited for a key. An **interrupt** turns that around. Hardware raises a signal, the CPU stops what it is doing, runs a short routine (the **handler**), and then goes back to exactly where it was. In this chapter you use both interrupt lines of the 6502, **NMI** and **IRQ**, and watch the CPU enter and leave a handler on the panel. Everything below was run on Glow65 and checked by `Tests/Glow65Tests/TutorialInterruptTests.swift`.

## 1. What the CPU does on an interrupt

Before each instruction the CPU checks two inputs:

| Input | Raised by | Can the program block it? |
|---|---|---|
| **NMI** (non-maskable) | The panel's **NMI** button | No. It is taken even when the I flag is set. It triggers once per press (on the edge) |
| **IRQ** | The UART, when it has a received character and you have enabled its interrupt | Yes: while the **I** flag is 1, IRQ is ignored. `sei` sets I, `cli` clears it. IRQ is **level**-triggered: as long as the line stays high, the CPU keeps coming back |

When the CPU takes an interrupt it:

1. pushes the **PC** high byte, the PC low byte, then the **P** register onto the stack (three writes to `$01xx`),
2. sets the **I** flag, so a handler is not interrupted by IRQ again,
3. reads the handler address from a vector: `$FFFA/$FFFB` for NMI, `$FFFE/$FFFF` for IRQ,
4. jumps there.

The handler ends with `rti`. It pulls P and then the PC back, so the program resumes with its flags as they were. Unlike `rts`, `rti` does not add 1 to the address, because the pushed PC already points at the next instruction.

The CPU saves only PC and P. If the handler uses A, X or Y, it must save and restore them itself (`pha` ... `pla`), or the main program's registers are destroyed.

## 2. The vectors on this board

The vectors at `$FFFA` and `$FFFE` are in ROM, so you cannot change them. The monitor therefore points them at two small jump instructions, which jump through two addresses in RAM:

| RAM address | Contents | Used for |
|---|---|---|
| `$03F8/$03F9` | NMI handler address (low, high) | NMI |
| `$03FA/$03FB` | IRQ handler address (low, high) | IRQ and `BRK` |

After a reset both hold the address of a lone `rti`, so an interrupt you did not expect does nothing. Your program installs its own handler by writing its address there. (The memory for your programs is now `$0300-$03F7`.)

## 3. NMI: count button presses

`tutorial/nmi_count.s` installs a handler and then spins in `jmp loop`. Each NMI runs the handler, which adds 1 to `COUNT` (`$03F0`) and prints `!`:

```
start:  lda #<handler           ; point the NMI vector at our handler
        sta NMIVEC
        lda #>handler
        sta NMIVEC+1
        lda #$00
        sta COUNT
loop:   jmp loop                ; the main program does nothing

handler:
        pha                     ; the CPU saved only PC and P: save A ourselves
        inc COUNT
wait:   lda UART_STATUS
        and #$02                ; transmit ready?
        beq wait
        lda #'!'
        sta UART_DATA
        pla
        rti                     ; restores P and PC (and the I flag with it)
```

Run it:

```bash
swift run Glow65App --load tutorial/nmi_count.bin@0300
```

Turn POWER on and type `G 0300`. The terminal shows no prompt: the CPU is busy spinning. Press the **NMI** button on the panel. Each press prints one `!`. Press RESET to stop (RESET keeps RAM), then check the count:

```
D 03F0 03F0
```

The first byte is the number of presses.

## 4. Watch an interrupt on the panel

Set the SPEED to 1 Hz or 10 Hz and STEP MODE to CYCLE, or stop the CPU with RUN/STOP and use STEP. While the program spins in `jmp loop` at `$030F`, press **NMI**, then step. You see the interrupt entry as bus accesses:

| # | Address | Data | R/W | What it is |
|---|---|---|---|---|
| 1 | `$01FD` | `03` | write | PC high byte pushed |
| 2 | `$01FC` | `0F` | write | PC low byte pushed |
| 3 | `$01FB` | `26` | write | P pushed (bit 5 is always 1 on the stack) |
| 4 | `$FFFA` | `1E` | read | NMI vector, low byte |
| 5 | `$FFFB` | `F4` | read | NMI vector, high byte |

The values are from a run of `nmi_count`: the stack pointer was `$FD` (the monitor's `G` command had already pushed its return address) and the PC `$030F` (the `jmp loop`). After step 5 the PC is `$F41E`, the monitor's `jmp (NMIVEC)`; the next steps read `$03F8/$03F9`, and the CPU lands in your `handler` at `$0312`. The first access is not marked SYNC: an interrupt entry does not fetch an opcode. A real 6502 spends 7 cycles here, with two extra dummy reads that Glow65 does not reproduce, so you see five accesses.

After `rti` the P LEDs and the PC LEDs return to what they were, and the stack pointer is back at `$FD`.

## 5. IRQ: echo by interrupt

In chapter 4 the program waited in a loop for each character. With IRQ the main program can do something else, and the UART interrupts it when a character arrives. `tutorial/irq_echo.s` counts in a 16-bit counter (`$03F0` low, `$03F1` high) while the handler echoes what you type.

The UART's control register (`$A000`) has one new bit:

| Bit | Meaning |
|---|---|
| bit 7 of the control register | 1 = raise IRQ while a received character is waiting |
| bit 7 of the status register | 1 = this UART is requesting an interrupt |

The setup, in order:

```
        sei                     ; no interrupts while we set up
        ...                     ; install the handler address in IRQVEC ($03FA)
        lda #$80                ; UART control bit 7: raise IRQ when a character arrives
        sta UART_STATUS         ; ($A000 is status when read and control when written)
        cli                     ; let the CPU accept IRQ
```

The handler reads the character, echoes it, and treats Enter as the signal to finish:

```
handler:
        pha
        lda UART_DATA           ; reading the data register clears the IRQ request
        cmp #$0D
        beq enter
        pha
wait:   lda UART_STATUS
        and #$02
        beq wait
        pla
        sta UART_DATA           ; echo
        pla
        rti
enter:  sta DONE                ; A = $0D, not zero: tell the main program to stop
        pla
        rti
```

Run it with `swift run Glow65App --load tutorial/irq_echo.bin@0300`, then `G 0300`. Whatever you type is echoed. Press Enter and the monitor's prompt comes back. Check the counter:

```
D 03F0 03F2
```

`$03F0/$03F1` is how far the main program counted while you typed, and `$03F2` is `0D`, the flag the handler set.

The line `lda UART_DATA` matters. IRQ is level-triggered: the UART keeps the line high while a character is unread. A handler that returns without reading `$A001` is interrupted again at once, forever.

## 6. BRK is an interrupt too

`brk` (opcode `$00`) pushes the PC plus 2 and P, sets I, and jumps through the **IRQ** vector. It is the same path as a hardware IRQ, so `$03FA/$03FB` serve both. The byte after `brk` is skipped on return: it is a free "signature" byte, which a handler can read to learn which `brk` it came from. (The B flag in the pushed P tells a handler whether it came from `brk` or from IRQ.)

## 7. Things to try

1. **Watch SP.** Press NMI while stepping. The SP LEDs go from `$FD` to `$FA` after the three pushes and back to `$FD` after `rti`.
2. **Count differently.** In `nmi_count.s` print the count as a letter instead of `!`: add `#'0'` to COUNT and print it (up to 9 presses).
3. **Forget the read.** In `irq_echo.s` make the handler's first instruction `rti`, so it never reads `$A001`. After you type one character, the main program stops counting and nothing is echoed. Why? (Slow the CPU down and watch the PC: it only walks through the interrupt entry, the handler and `rti`, over and over.) Press RESET to recover.
4. **Use BRK.** Enter `E 0300 A9 01 00 60 8D F0 03 60`, then `G 0300`. The `brk` at `$0302` goes through the default `rti` handler and the program resumes at `$0304`, skipping the `60` at `$0303`: `D 03F0 03F0` shows `01`.
5. **Turn it off.** `sei` blocks IRQ but not NMI. Put `sei` before the `jmp loop` in `nmi_count.s` and press NMI anyway.

## 8. Things to remember

- NMI cannot be masked; IRQ is masked by the I flag.
- The CPU saves only PC and P. Save A, X and Y in the handler if you use them.
- End a handler with `rti`, not `rts`.
- A level-triggered IRQ must be acknowledged at the source (here: read `$A001`).
- The monitor's warm start switches the UART interrupt off, so returning to the monitor with `rts` is safe even if your program left it on.

[← 5. USR](05-usr.md)
