# 5.2 Register Transfer

[English](05-2-transfer.md) | [日本語](../ja/05-2-transfer.md)

[← 5.1 Load and Store](05-1-load-store.md) &nbsp;·&nbsp; [5.3 Arithmetic and Comparison →](05-3-arithmetic.md) &nbsp;·&nbsp; [Chapter start](05-reference.md)

These instructions copy the value of one register to another register. The source value does not change. Except for TXS, N and Z are set from the copied value.

Only A and X, A and Y, and X and SP can be copied directly. There is no transfer instruction between X and Y.

<a id="tax"></a>

### TAX (Transfer A to X)

Copies the value of A to X. N and Z are set from the copied value.

**Flags affected**

<!-- flags:TAX -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:TAX -->

**Opcodes**

<!-- opcodes:TAX -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TAX` | `$AA` | 1 | 2 |
<!-- /opcodes:TAX -->

**Examples**

```
        LDA #$80
        TAX
```

A (`$80`) is copied to X. A stays the same, and N becomes 1.

<a id="tay"></a>

### TAY (Transfer A to Y)

Copies the value of A to Y. N and Z are set from the copied value.

**Flags affected**

<!-- flags:TAY -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:TAY -->

**Opcodes**

<!-- opcodes:TAY -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TAY` | `$A8` | 1 | 2 |
<!-- /opcodes:TAY -->

**Examples**

```
        LDY #$55
        LDA #$00
        TAY
```

Y is `$55`. Copying A (`$00`) to Y makes Y `$00`, and Z becomes 1.

<a id="txa"></a>

### TXA (Transfer X to A)

Copies the value of X to A. N and Z are set from the copied value.

**Flags affected**

<!-- flags:TXA -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:TXA -->

**Opcodes**

<!-- opcodes:TXA -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TXA` | `$8A` | 1 | 2 |
<!-- /opcodes:TXA -->

**Examples**

```
        LDX #$33
        LDA #$00
        TXA
```

A is `$00`. X (`$33`) is copied to A.

<a id="tya"></a>

### TYA (Transfer Y to A)

Copies the value of Y to A. N and Z are set from the copied value.

**Flags affected**

<!-- flags:TYA -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:TYA -->

**Opcodes**

<!-- opcodes:TYA -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TYA` | `$98` | 1 | 2 |
<!-- /opcodes:TYA -->

**Examples**

```
        LDY #$44
        TYA
```

Y (`$44`) is copied to A.

<a id="tsx"></a>

### TSX (Transfer Stack Pointer to X)

Copies the value of SP to X. N and Z are set from the copied value.

**Flags affected**

<!-- flags:TSX -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:TSX -->

**Opcodes**

<!-- opcodes:TSX -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TSX` | `$BA` | 1 | 2 |
<!-- /opcodes:TSX -->

**Examples**

```
        LDX #$F0
        TXS
        LDX #$00
        TSX
```

When SP is `$F0`, `TSX` copies it to X, so X becomes `$F0` and N becomes 1.

Changing SP moves the stack. This example saves SP before it runs and restores it before it ends.

<a id="txs"></a>

### TXS (Transfer X to Stack Pointer)

Copies the value of X to SP. TXS does not change any flag.

**Flags affected**

<!-- flags:TXS -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| - | - | - | - | - | - |
<!-- /flags:TXS -->

**Opcodes**

<!-- opcodes:TXS -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Implied | `TXS` | `$9A` | 1 | 2 |
<!-- /opcodes:TXS -->

**Examples**

```
        LDX #$F0
        LDA #$00
        TXS
```

Even though X is `$F0`, Z=1 and N=0 from the preceding `LDA #$00` stay as they are.

TXS does not change the flags. This is different from the other transfer instructions.

> **What you can try in Glow65**
>
> `LDA #$80` and `TAX`, then `LDA #$00` and `TXA`, copy values between A and X. `L` shows the instructions.
>
> ```
> *E 0300 A9 80 AA A9 00 8A 8D F0 03 8E F1 03 60
> *L 0300 0305
> 0300  A9 80     LDA   #$80
> 0302  AA        TAX
> 0303  A9 00     LDA   #$00
> 0305  8A        TXA
> *G 0300
> *D 03F0 03F1
> 03F0: 80 80 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> At the last `TXA`, A changes from `$00` to the value of X, `$80`. X stays `$80`.

> **What you can try in Glow65**
>
> Set SP to `$F0` and read it with `TSX`. The program writes the original SP to `$03E4`, the X read by `TSX` to `$03E5`, and P to `$03E6`.
>
> ```
> *E 0300 BA 8E E4 03 A2 F0 9A A2 00 BA 08 68 8D E6 03 8E
> *E 0310 E5 03 AE E4 03 9A 60
> *G 0300
> *D 03E4 03E6
> 03E4: FD F0 B4 00 00 00 00 00 00 00 00 00 00 00 00 00
> ```
>
> `FD` at `$03E4` is the SP before the change. `F0` at `$03E5` is the result of `TSX`, and `B4` at `$03E6` shows that N is 1.

---

[← 5.1 Load and Store](05-1-load-store.md) &nbsp;·&nbsp; [5.3 Arithmetic and Comparison →](05-3-arithmetic.md) &nbsp;·&nbsp; [Chapter start](05-reference.md)
