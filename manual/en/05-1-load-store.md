# 5.1 Load and Store

[English](05-1-load-store.md) | [日本語](../ja/05-1-load-store.md)

[← 5. Instruction Reference](05-reference.md) &nbsp;·&nbsp; [5.2 Register Transfer →](05-2-transfer.md)

Load instructions put a value from memory into a register. Store instructions write the value of a register to memory. Load instructions change N and Z. Store instructions do not change any flag.

Every instruction in this group handles one 8-bit value. A 16-bit value is handled in two steps.

<a id="lda"></a>

### LDA (Load Accumulator)

Loads a value from memory into A. N and Z change according to the value.

**Flags affected**

<!-- flags:LDA -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:LDA -->

**Opcodes**

<!-- opcodes:LDA -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Immediate | `LDA #$nn` | `$A9` | 2 | 2 |
| Zero page | `LDA $nn` | `$A5` | 2 | 3 |
| Zero page,X | `LDA $nn,X` | `$B5` | 2 | 4 |
| Absolute | `LDA $nnnn` | `$AD` | 3 | 4 |
| Absolute,X | `LDA $nnnn,X` | `$BD` | 3 | 4+ |
| Absolute,Y | `LDA $nnnn,Y` | `$B9` | 3 | 4+ |
| Indexed indirect `(zp,X)` | `LDA ($nn,X)` | `$A1` | 2 | 6 |
| Indirect indexed `(zp),Y` | `LDA ($nn),Y` | `$B1` | 2 | 5+ |
<!-- /opcodes:LDA -->

**Examples**

```
        LDA #$80
```

A becomes `$80`. The most significant bit is 1, so N becomes 1.

```
        LDA #$00
```

A becomes `$00`. The value is 0, so Z becomes 1.

<a id="ldx"></a>

### LDX (Load X Register)

Loads a value from memory into X. N and Z change according to the value. The indexed modes are zero page,Y and absolute,Y.

**Flags affected**

<!-- flags:LDX -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:LDX -->

**Opcodes**

<!-- opcodes:LDX -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Immediate | `LDX #$nn` | `$A2` | 2 | 2 |
| Zero page | `LDX $nn` | `$A6` | 2 | 3 |
| Zero page,Y | `LDX $nn,Y` | `$B6` | 2 | 4 |
| Absolute | `LDX $nnnn` | `$AE` | 3 | 4 |
| Absolute,Y | `LDX $nnnn,Y` | `$BE` | 3 | 4+ |
<!-- /opcodes:LDX -->

**Examples**

```
        LDX #$05
```

X becomes `$05`.

Before: memory `$0013` holds `$5A`.

```
        LDY #$03
        LDX $10,Y
```

Zero page,Y. Y (`$03`) is added to `$10`, giving `$0013`. The contents of `$0013`, `$5A`, go into X.

<a id="ldy"></a>

### LDY (Load Y Register)

Loads a value from memory into Y. N and Z change according to the value.

**Flags affected**

<!-- flags:LDY -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| ○ | - | - | - | ○ | - |
<!-- /flags:LDY -->

**Opcodes**

<!-- opcodes:LDY -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Immediate | `LDY #$nn` | `$A0` | 2 | 2 |
| Zero page | `LDY $nn` | `$A4` | 2 | 3 |
| Zero page,X | `LDY $nn,X` | `$B4` | 2 | 4 |
| Absolute | `LDY $nnnn` | `$AC` | 3 | 4 |
| Absolute,X | `LDY $nnnn,X` | `$BC` | 3 | 4+ |
<!-- /opcodes:LDY -->

**Examples**

```
        LDY #$FF
```

Y becomes `$FF`. The most significant bit is 1, so N becomes 1.

<a id="sta"></a>

### STA (Store Accumulator)

Writes the value of A to memory. Neither A nor the flags change.

**Flags affected**

<!-- flags:STA -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| - | - | - | - | - | - |
<!-- /flags:STA -->

**Opcodes**

<!-- opcodes:STA -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Zero page | `STA $nn` | `$85` | 2 | 3 |
| Zero page,X | `STA $nn,X` | `$95` | 2 | 4 |
| Absolute | `STA $nnnn` | `$8D` | 3 | 4 |
| Absolute,X | `STA $nnnn,X` | `$9D` | 3 | 5 |
| Absolute,Y | `STA $nnnn,Y` | `$99` | 3 | 5 |
| Indexed indirect `(zp,X)` | `STA ($nn,X)` | `$81` | 2 | 6 |
| Indirect indexed `(zp),Y` | `STA ($nn),Y` | `$91` | 2 | 6 |
<!-- /opcodes:STA -->

**Examples**

Before: memory `$0400` holds `$00`.

```
        LDA #$55
        STA $0400
```

A (`$55`) is written to `$0400`.

Before: memory `$0403` holds `$00`.

```
        LDA #$55
        LDX #$03
        STA $0400,X
```

X (`$03`) is added to `$0400`, giving `$0403`, and `$55` is written there.

For STA, the absolute,X, absolute,Y, and indirect indexed modes take the same number of cycles whether or not the access crosses a page.

<a id="stx"></a>

### STX (Store X Register)

Writes the value of X to memory. It has a zero page,Y mode.

**Flags affected**

<!-- flags:STX -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| - | - | - | - | - | - |
<!-- /flags:STX -->

**Opcodes**

<!-- opcodes:STX -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Zero page | `STX $nn` | `$86` | 2 | 3 |
| Zero page,Y | `STX $nn,Y` | `$96` | 2 | 4 |
| Absolute | `STX $nnnn` | `$8E` | 3 | 4 |
<!-- /opcodes:STX -->

**Examples**

Before: memory `$0010` holds `$00`.

```
        LDX #$07
        STX $10
```

X (`$07`) is written to `$0010`.

<a id="sty"></a>

### STY (Store Y Register)

Writes the value of Y to memory. It has a zero page,X mode.

**Flags affected**

<!-- flags:STY -->
| N | V | D | I | Z | C |
|---|---|---|---|---|---|
| - | - | - | - | - | - |
<!-- /flags:STY -->

**Opcodes**

<!-- opcodes:STY -->
| Addressing mode | Syntax | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| Zero page | `STY $nn` | `$84` | 2 | 3 |
| Zero page,X | `STY $nn,X` | `$94` | 2 | 4 |
| Absolute | `STY $nnnn` | `$8C` | 3 | 4 |
<!-- /opcodes:STY -->

**Examples**

Before: memory `$0400` holds `$00`.

```
        LDY #$09
        STY $0400
```

Y (`$09`) is written to `$0400`.

> **What you can try in Glow65**
>
> After `LDA #$80`, `PHP` and `PLA` bring P into A, and `STA` writes it to `$03F0`.
>
> ```
> *E 0300 A9 80 08 68 8D F0 03 60
> *L 0300 0304
> 0300  A9 80     LDA   #$80
> 0302  08        PHP
> 0303  68        PLA
> 0304  8D F0 03  STA   $03F0
> *G 0300
> *D 03F0 03F0
> 03F0: B4 00 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```
>
> `$B4` is `%10110100`. N (bit 7) is 1. Bit 5 and B (bit 4) are set to 1 by PHP when it pushes. I (bit 2) is also 1.

> **What you can try in Glow65**
>
> Three store instructions write the values of A, X, and Y to `$03F0` and the next two addresses.
>
> ```
> *E 0300 A9 55 A2 07 A0 09 8D F0 03 8E F1 03 8C F2 03 60
> *G 0300
> *D 03F0 03F2
> 03F0: 55 07 09 00 00 00 00 00 24 F4 24 F4 00 00 00 00
> ```

---

[← 5. Instruction Reference](05-reference.md) &nbsp;·&nbsp; [5.2 Register Transfer →](05-2-transfer.md)
