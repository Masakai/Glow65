# GAME65G Guide

[日本語](GAME65G.ja.md)

GAME65G is an interpreter for the GAME language. It lives in the Glow65 ROM at `$8000-$9FFF`.

GAME is a language that 大西博 published in the Japanese magazine ASCII in 1978. It uses symbols instead of BASIC keywords, and almost every statement has the form "symbol=value". GAME65G was written for Glow65 from the published language specification. It is not GAME65, the PET version that 鈴木仁志 wrote in 1979.

## Starting and leaving

Type `T` in the monitor to start GAME65G.

```
*T

GAME65G V1.0
BASED ON GAME LANGUAGE (ASCII 1978)
>
```

`>` is the prompt.

- `T` is a cold start. It clears the program and the variables.
- To go back to the monitor, enter `>=$F009` (this calls the monitor's warm start).
- From the monitor, `G 8003` returns to GAME65G with the program kept (warm start). If you ran BASIC or anything else in between, it may not return correctly, because that rewrites the zero page.

## Typing rules

- A line can be up to 120 characters. Backspace deletes one character.
- Lowercase letters become uppercase, except inside `"` strings and in comment lines.
- Statements are separated by spaces. Do not put spaces inside an expression: `?=A+1` is correct, and `?=A + 1` is not.
- Keys typed while a program is running or listing are kept (up to 64 characters) and used by the next input.

## Sending a program

GAME65G has no LOAD or SAVE. A program written in a text file is sent as if it were typed into the terminal. Line ends arrive as Return.

- App: choose the file with **File → Send Text File…** (Shift-Command-O). Text on the clipboard can be pasted with Command-V.
- CLI: `glow65-cli --input 't\r' --send-text prog.txt`. This types `T` in the monitor, then sends the file.

A line with the same number replaces the old one, so clear the program with `&=0` before sending if you want a clean start.

## Entering and running a program

| Input | Action |
|---|---|
| `10 ?=1` | Enter line 10. A line with the same number is replaced |
| `10` | Delete line 10 |
| `10REM ...` | A line with no space after the line number is a comment and is not run |
| `0` | List the whole program |
| `100/` | List from line 100 to the end |
| `#=1` | Run from the start |
| `#=100` | Run from line 100. If there is no line 100, run from the first line after it |
| `&=0` | Clear the program (NEW) |

Line numbers are 1 to 32767. Input without a line number runs immediately.

```
>10 I=1,5 ?=I*I .=1 @=I+1
>#=1
1 4 9 16 25
>
```

## Values and variables

- Every value is a 16-bit integer. Expressions treat it as -32768 to 32767.
- Constants are decimal (`100`) or hexadecimal with `$` (`$FF`).
- There are 26 variables, `A` to `Z`. Letters after the first are ignored, so `ALPHA` and `A` are the same variable.
- Variables are 0 after starting. Running a program (`#=1`) does not clear them.

### Arrays and memory

A variable's value can be used as an address to read and write memory.

| Form | Meaning |
|---|---|
| `A(i)` | 2 bytes at `A + i*2` (low byte first) |
| `A:i)` | 1 byte at `A + i` |

```
>A=$3000 A(0)=$1234 ?$=A:0) ?$=A:1)
3412
```

To use the free memory after the program, start right after the program end (`&`), as in `A=&+1`. If you add lines after that, the program grows into the array, so be careful.

### Special registers

| Symbol | Contents | Initial value |
|---|---|---|
| `=` | Address of the program start | `$0600` |
| `&` | Address of the program end (where the EOF mark is) | |
| `*` | Address of the end of RAM | `$7FFF` |
| `'` | Random seed | |

In an expression, `=`, `&` and `*` read these values. `??==` prints the start address in hex, and `??=&` prints the end address.

## Expressions

Operators have no precedence. They are evaluated from left to right. Use parentheses for anything that must be computed first.

```
>?=2+3*4 / ?=2+(3*4)
20
14
```

| Operator | Meaning |
|---|---|
| `+` `-` `*` `/` | Arithmetic. Division is integer division, and dividing by 0 is an error |
| `=` `<>` `<` `>` `<=` `>=` | Comparison. 1 if true, 0 if false. Signed |
| `&` `.` `!` | Bitwise AND, OR, XOR |
| `-term` | Negate |
| `%term` | The remainder of the last division. The term is a dummy, so it is usually written `%(A/B)` |
| `'n` | A random number from 1 to n |
| `?` | Read one line and evaluate it as an expression |
| `$` | The character code of the key being pressed, or 0 if no key is pressed (does not wait) |

## Statements

| Statement | Form | Action |
|---|---|---|
| Assignment | `A=expr` | Store a value in a variable |
| Decimal output | `?=expr` | Print, left-aligned |
| Field width | `?(m)=expr` | Print right-aligned in m columns |
| Hex output | `??=expr`, `?$=expr` | Print 4 digits, or 2 digits (low byte) |
| Character | `$=expr` | Print the low byte as a character code |
| Spaces | `.=expr` | Print as many spaces as the low byte |
| New line | `/` | Start a new line. `//` does it twice |
| String | `"text"` | Print the text |
| GOTO | `#=expr` | Jump to that line. Does nothing if 0 |
| End | `#=-1` | Stop running |
| IF | `;=expr` | If 0, skip the rest of the line and go to the next line |
| GOSUB | `!=expr` | Call a subroutine. Does nothing if 0 |
| RETURN | `]` | Return from a subroutine |
| CALL | `>=expr` | Call the machine code at that address with `JSR`. It returns with `RTS` |
| FOR | `I=start,end` | Start a loop |
| NEXT | `@=I+1` | Store the value in `I`. Leave the loop if it is greater than the end value, otherwise go back to the start of the loop |
| DO | `@` | Start a loop |
| UNTIL | `@=(condition)` | Leave the loop if the condition is true, otherwise go back to DO |
| Random seed | `'=expr` | Set the random seed |
| Change start | `=expr` | Set the program start address and find the end again |
| Find end | `==` | Walk the program from the start and set the program end again |
| End of RAM | `*=expr` | Set the end-of-RAM address |
| LOCK | `&:0)=$F0` | Stop lines from being added or deleted. `&:0)=$FF` undoes it |

### Notes on loops

- NEXT and UNTIL are told apart by the character after `@=`: a variable name means NEXT, anything else means UNTIL. When the condition starts with a variable name, put it in parentheses, as in `@=(K=M)`.
- A FOR loop always runs at least once.
- GOSUB, FOR and DO share one stack (31 levels). Leaving a loop with `#=`, or running `]` inside a loop, leaves the stack out of step. End loops with NEXT or UNTIL.

### Notes on input

- `A=?` waits for a line without printing anything. Print a prompt first, for example `"N?"`. The input is evaluated as an expression, so typing `3+4` gives 7.
- `A=$` does not wait. To wait for a key, loop: `@ K=$ @=(K<>0)`.

## Errors and breaking

- On an error, GAME65G prints `ERR` and the line number, and returns to the prompt. An error in input without a line number prints just `ERR`.
- Ctrl-C stops a running program and prints `BRK` and the line number.

```
>10 ?=1
>20 ?=)
>#=1
1
ERR 20
>
```

## Example programs

### Multiplication table

```
10 I=1,9
20 J=1,9 ?(3)=I*J @=J+1
30 / @=I+1
```

```
>#=1
  1  2  3  4  5  6  7  8  9
  2  4  6  8 10 12 14 16 18
(...)
  9 18 27 36 45 54 63 72 81
>
```

### Guess the number

The program keeps drawing random numbers until you press a key, so the answer depends on when you press it.

```
10 "PRESS A KEY" / @ N='100 K=$ @=(K<>0)
20 C=0
30 "1-100? " G=? C=C+1
40 ;=G<N "UP" / #=30
50 ;=G>N "DOWN" / #=30
60 "OK " ?=C / #=-1
```

Longer programs, including a Star Trek game, are in [examples/](examples/README.md).

## Memory use

| Range | Use |
|---|---|
| `$0000-$002C` | GAME65G work area |
| `$0080-$00B3` | Variables A-Z |
| `$0300-$03F7` | Not used (call your own machine code with `>=$300`) |
| `$0400-$047F` | Line input buffer |
| `$0480-$04FF` | Buffer for `?` input |
| `$0500-$05BF` | Stack for GOSUB, FOR and DO |
| `$05C0-$05FF` | Type-ahead buffer (64 characters) |
| `$0600-$7FFF` | The program, and free memory for arrays |

Machine code called with `>=` must not change `$0000-$002C` or `$0080-$00B3`, or GAME65G will misbehave. GAME65G does not use `$F0-$FF`, which belongs to the monitor.

## Differences from the original

GAME65G follows the original only in the language specification. The details of its behavior were decided for Glow65. The main points:

- There is no LOAD or SAVE (Glow65 has no tape).
- There is no statement for reading a line of text (INPUT STR in the original).
- The original table does not list the comparison operators, the error display, or how to delete a line, so these were decided here.
- Single-character input with `$` returns without waiting. This follows the behavior described in the GAME65 article.

The full list of decisions is in the [design document](documents/designs/2026-10-13-game65g.md) (Japanese).
