# GAME65G Examples

[日本語](README.ja.md)

Programs written in the GAME language for [GAME65G](../GAME65G.md), the GAME interpreter in the Glow65 ROM.

| File | Contents |
|---|---|
| [startrek.gam](startrek.gam) | Star Trek: hunt down the Klingon warships in an 8x8 galaxy |

## Loading a program

GAME65G has no LOAD command. A program is sent to the terminal as if it were typed.

- **App:** type `T` in the monitor to start GAME65G. Then choose the file with **File → Send Text File…** (Shift-Command-O).
- **CLI:** `swift run glow65-cli --input 't\r' --send-text examples/startrek.gam` starts GAME65G and sends the file.

Then enter `#=1` to run it. If a program is already in memory, clear it first with `&=0`.

## Star Trek

Star Trek after the computer games of the 1970s. You command the Enterprise. Destroy every Klingon warship in the galaxy before the time runs out.

The program is 357 lines. Once loaded, it occupies `$0600-$3BCF`, and the game keeps its data at `$6000-$626F`.

### Starting

After `#=1`, the title says `PRESS ANY KEY TO START`. The game draws random numbers while it waits, so the moment you press the key decides the galaxy. Your orders follow: the number of Klingons, the last stardate, and the number of starbases.

### Entering numbers

The game reads keys itself, so a typing mistake does not stop the program.

- Digits, Backspace and Return are used, and `.` for a course or a warp factor. Other keys are ignored.
- Return on its own enters 0.
- Course and warp factor take one decimal place, for example `2.5`. Other numbers are whole numbers.

### Commands

At `COMMAND (0=HELP)?`, enter a number.

| Command | Action |
|---|---|
| 0 | List the commands |
| 1 | Navigate: set a course and a warp factor |
| 2 | Short range sensor scan of this quadrant |
| 3 | Long range sensor scan of the 3x3 quadrants around you |
| 4 | Fire phasers |
| 5 | Fire a photon torpedo |
| 6 | Shield control |
| 7 | Damage control report |
| 8 | Library computer |
| 9 | Resign your command |

### Course

```
  4  3  2
   \ | /
 5 --*-- 1
   / | \
  6  7  8
```

1 is east (right) and 3 is north (up). 9 is the same as 1. A fraction points between two directions: 1.5 is halfway between east and northeast.

Coordinates are written `X,Y`. X is the column (1 at the left) and Y is the row (1 at the top). This applies to both quadrants and sectors.

### Navigation

- Warp 1 moves 8 sectors, which is one quadrant. The maximum is warp 8.0, or 0.2 when the warp engines are damaged.
- A move uses (warp factor x 8 + 10) units of energy, even if the ship stops early.
- A move at warp 1 or more takes 1 stardate. A slower move takes the warp factor in stardates (warp 0.5 takes 0.5).
- If something is in the way inside the quadrant, the engines shut down in the sector before it.
- You cannot leave the galaxy. The ship stops at the edge.

### Short range scan

| Symbol | Meaning |
|---|---|
| `<*>` | The Enterprise |
| `+K+` | A Klingon warship |
| `>!<` | A starbase |
| ` * ` | A star |
| ` . ` | Empty space |

The status next to the map shows the stardate, condition, quadrant, sector, photon torpedoes, total energy (energy plus shields), shields, and Klingons remaining. The condition is DOCKED, *RED* (Klingons in this quadrant), YELLOW (energy below 300), or GREEN.

### Long range scan

Each quadrant is shown as three digits: Klingons, starbases, stars. `107` means one Klingon, no starbase and seven stars. `***` is outside the galaxy. What you see is stored in the computer's galactic record.

### Combat

- **Phasers:** the energy you fire is shared among the Klingons in the quadrant. The damage falls with distance. A hit of 15 percent or less of a Klingon's remaining energy does no damage. With the library computer damaged, the shot is less accurate.
- **Photon torpedoes:** you start with 10. Each costs 2 units of energy and flies along the course you give. It destroys a Klingon, is absorbed by a star, or destroys a starbase. Destroying the last starbase ends your command.
- **Klingons fire back** after you fire phasers or a torpedo, and before you move. The hits drain your shields. If the shields go below 0, the Enterprise is destroyed. Klingons do not fire while you are docked. They stay in their sectors.
- **Shields:** command 6 moves energy between the ship and the shields. You start with shields at 0, so raise them before a fight.

### Damage and repair

The Enterprise has eight devices: warp engines, short range sensors, long range sensors, phaser control, photon tubes, damage control, shield control, and the library computer. A negative value in the damage report means the device is damaged and does not work.

- A heavy hit can damage a device.
- Each move has a chance of damaging a device or improving a repair.
- While you move, damaged devices are repaired by the warp factor (at most 1.0 per move).
- While docked, the damage report offers to repair everything at once. This takes up to 0.9 stardates.

### Starbases

Move into one of the eight sectors around a starbase to dock. Docking restores energy to 3000 and torpedoes to 10, and drops the shields to 0.

### Library computer

At `COMPUTER ACTIVE AND AWAITING COMMAND`, enter a number (9 lists them).

| Number | Function |
|---|---|
| 0 | Cumulative galactic record: what you have scanned |
| 1 | Status report: Klingons left, time left, starbases, and the damage report |
| 2 | Photon torpedo data: course and distance to each Klingon in the quadrant |
| 3 | Starbase navigation data: course and distance to the starbase in the quadrant |
| 4 | Direction and distance calculator between two sector coordinates |
| 5 | Region name map of the galaxy |

The course from function 2 can be entered as it is for a torpedo.

### End of the game

- **Win:** destroy every Klingon. Your efficiency rating is about 1000 x (Klingons destroyed / stardates used) squared, computed with whole numbers and at most 9000.
- **Lose:** the time runs out, the Enterprise is destroyed, energy plus shields fall to 10 or less, or you destroy the last starbase.
- Command 9 resigns.

At the end, `PLAY AGAIN (Y/N)?` starts a new galaxy with Y.

### Notes

- The game uses all 26 GAME variables and keeps its data at `$6000-$626F`.
- `Tests/Glow65Tests/StarTrekExampleTests.swift` plays a fixed game and set-up scenes (return fire, the last torpedo, docking and repair).
- Star Trek is a trademark of its owner. This program is an unofficial game in the tradition of the 1970s computer games and is not affiliated with the owner.
