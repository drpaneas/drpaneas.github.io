+++
categories = ["nes"]
date = "2026-07-02T12:19:00+02:00"
tags = ["nes", "famicom", "math", "fixed-point", "float", "retro"]
title = "NES Mathematics"

+++

# NES Math

A guide to the fixed-point arithmetic behind classic NES platformers, written for programmers porting NES games to modern languages.

---

## 1. Why This Article Exists

You are porting a classic single-screen NES platformer to a modern platform. You have access to a full disassembly of the original ROM, you know the physics constants, and you can read wiki pages describing every system. What you may not have is an intuition for *why* the numbers look the way they do - why a run speed byte is `$19` and not `$1A`, why friction values live in a three-entry table, why gravity uses two bytes when speed uses one.

This article builds that intuition. It starts with the hardware constraint (what the 6502 CPU can and cannot do), traces the design decisions that follow from that constraint, and ends with concrete advice for reproducing NES-accurate behavior in Go, Rust, C, or any language with integer types. Every concept is grounded in real assembly patterns used throughout the NES library's back catalog, using descriptive names for routines and variables rather than any one game's original internal labels.

### Three levels of fixed-point - and why existing libraries won't help

If you search for "fixed-point library" in any language, you will find dozens. None of them solve the problem you actually have. The reason is that fixed-point means different things at different levels:

**Level 1: Numeric type.** This is what libraries provide. A type like `Q16.16` that wraps an `int32` and gives you `+`, `-`, `*`, `/` with a fixed decimal point. Useful for finance, DSP, physics engines. Not useful for porting an NES platformer, because the original game does not think of its values as "numbers with a decimal point."

**Level 2: Retro fixed-point.** A `Q4_4` type backed by `uint8`, with operations like `Split()`, `Integer()`, `Fraction()`, `SignExtendedInteger()`. This maps the byte layout of NES speed values. Closer, but still not enough.

**Level 3: Hardware arithmetic model.** This is what an NES platformer actually uses. There is no "fixed-point number" in the codebase. There are independent bytes - a force byte, a speed byte, a sub-pixel accumulator, a pixel position, a page counter - connected by **carry propagation**. The carry chain is not a numeric operation. It is an algorithm:

```
Force
  ↓ carry
Speed
  ↓ carry
SubPixel accumulator
  ↓ carry
Pixel position
  ↓ carry
Page
```

Each byte is added independently. The only thing connecting them is whether the previous addition overflowed. The sub-pixel byte is not "the fractional part of position." It is a **delay counter** that accumulates crumbs until one whole pixel has been earned. The force byte is not "the fractional part of speed." It is a reservoir that takes 8 frames to fill before speed changes by 1/16.

No fixed-point library models this, because it is not a number. It is an architecture. This article teaches that architecture.

---

## 2. A Brief History of Fixed-Point

NES programmers did not invent fixed-point arithmetic. The idea of representing fractions by agreeing where an imaginary decimal point sits inside a number is centuries old. Mechanical calculators in the 1600s used it - the operator decided that the last two wheels on the machine represented hundredths, and built their arithmetic accordingly. The machine had no notion of a decimal point. The human imposed it.

Digital signal processing (DSP) chips in the 1970s formalized the technique. The Motorola 56000, a workhorse of early digital audio, used a 24-bit fixed-point format natively. By the early-to-mid 1980s, when the NES's Ricoh 2A03 CPU was designed, fixed-point was a standard tool in embedded programming. What NES programmers contributed was not the concept but the specific adaptations: the 4.4 format for velocity, the sub-pixel accumulator trick, and the carry-chain position system - all shaped by the 6502's particular strengths and limitations.

**Terminology note:** "Fixed-point arithmetic" (this article) and "fixed point of a function" (where f(x) = x) are unrelated concepts that share a name. If you encounter "fixed point" in a math or computer science context, check which one is meant. This article is entirely about the arithmetic - representing fractions with integer bytes.

The idea is simple, and a money analogy makes it concrete. The price €3.99 can also be written as 399 cents - same value, no decimal point. You convert between the two by multiplying or dividing by 100. But 100 is a power of 10, and 8-bit CPUs are bad at powers of 10. They are very good at powers of 2. So instead of grouping by hundreds (10²), fixed-point groups by 256 (2⁸). Multiplying by 256 is a single byte shift. Dividing by 256 is reading the high byte of a two-byte value. The arithmetic maps directly onto what the hardware can do.

Take an integer byte. Declare that some of its bits represent whole units and the rest represent fractions. The hardware does not know or care - it adds bytes the same way regardless. The programmer enforces the convention by placing results into the right memory locations and by interpreting the output correctly.

---

## 3. The 6502 Constraint

The NES runs a Ricoh 2A03, which is a modified MOS 6502. The CPU has:

- **An 8-bit ALU.** Every register holds one byte: 0 to 255 unsigned, or -128 to +127 signed. There are no 16-bit registers, no 32-bit accumulator, no wide operations.
- **ADC and SBC.** Add-with-carry and subtract-with-borrow. These are the *only* arithmetic instructions. There is no "plain add" - the carry flag is always involved. `CLC` before addition, `SEC` before subtraction, every time.
- **Shifts and rotates.** ASL (shift left, multiply by 2), LSR (shift right, divide by 2), ROL and ROR (rotate through carry for multi-byte shifts). These are the only way to multiply or divide.
- **No multiply instruction.** To multiply two numbers, you write a loop: shift the multiplier right, check the carry, conditionally add the multiplicand, repeat eight times. It costs roughly 70-100 cycles. NES developers avoided it wherever possible.
- **No divide instruction.** Division is even worse - repeated subtraction with shift. Most games simply do not divide.
- **No working decimal mode.** The original 6502 has a BCD (binary-coded decimal) mode activated by `SED`. The NES's Ricoh 2A03 removed it - the instruction exists but does nothing. If you see `CLD` (clear decimal) in an NES disassembly, it is a safety habit from 6502 programming, not a functional requirement. Your port can ignore it.
- **The carry flag.** This single bit is the 6502's superpower for multi-byte math. When an 8-bit addition overflows past 255, the carry flag is set to 1. The next ADC instruction automatically includes it. This lets you chain additions across as many bytes as you need, with no extra logic.

These constraints explain everything that follows. NES platformers use lookup tables instead of multiplication. They use bit shifts instead of division. They represent fractions using byte conventions instead of floating-point. They chain single-byte additions through the carry flag to accumulate precision across multiple bytes.

The 6502 has one more relevant property: it does not distinguish signed from unsigned arithmetic. ADC adds two bytes and sets the carry flag. It does not know or care whether those bytes represent 200 + 100 (unsigned) or -56 + 100 (signed, via two's complement). The bits are the same. The flags are set the same way. The programmer decides the interpretation.

---

## 4. Why Not Floating-Point?

A reasonable question. The 6502 had no floating-point hardware, but it could do software float. Applesoft BASIC, which shipped with the Apple II in 1977, included a full floating-point library written by Steve Wozniak. IEEE 754 - the standard that defines `float32` and `float64` - was finalized in 1985, the same year the NES launched in North America. Floating-point existed. NES developers largely chose not to use it for real-time physics.

### The speed problem

A software float multiply on the 6502 costs roughly 200-300 cycles. The NES CPU runs at 1.79 MHz, giving about 29,780 cycles per frame at 60fps. One float multiply consumes 1% of the entire frame budget. A platformer's physics runs dozens of add/subtract/compare operations per frame across the player, enemies, projectiles, and platforms. Replacing each integer operation with a float equivalent would consume the CPU many times over. Fixed-point operations - ADC, SBC, ASL, LSR - cost 2-5 cycles each. The performance gap is 50-100x.

### The precision model is different

Floating-point and fixed-point store fractions differently, and the difference matters for game physics.

A floating-point number has three parts: a **sign bit**, an **exponent** (which sets the scale), and a **mantissa** (which sets the precision within that scale):

```
Float16:  S EEEEE MMMMMMMMMM
          1  5       10 bits

Value = (-1)^S × 2^(E - 15) × (1 + M/1024)
```

This gives *relative* precision - the spacing between representable numbers grows with their magnitude. Between 1.0 and 2.0, there are 1024 representable values. Between 2.0 and 4.0, there are also 1024 values, but spread over twice the range - so the gaps are twice as wide. At high values, precision degrades.

A fixed-point byte has two parts: an **integer** and a **fraction**, with a fixed boundary:

```
4.4:      IIII FFFF
          4     4 bits

Value = I + F/16
```

This gives *absolute* precision - the spacing between representable values is always exactly 1/16, regardless of magnitude. A character at speed 1.0 has the same precision as at speed 2.5. No degradation. No surprises.

### Uniform gaps are an advantage for games

In a game, you constantly compare speeds to thresholds - checking whether a character's absolute speed is at or above a "running" threshold, or below a "skid" threshold. These comparisons work perfectly in fixed-point because every value is an exact multiple of 1/16.

In floating-point, the value you store might not be the value you wrote. `0.1 + 0.2 = 0.30000000000000004` in `float64`. Fixed-point cannot represent 0.1 either - the closest 4.4 value is 2/16 = 0.125 - but the set of representable values is known in advance and never changes. There are no hidden rounding surprises. A `CMP #$10` either passes or it does not.

### Determinism

Fixed-point integer math produces identical results on every CPU, every compiler, every platform. The same inputs always yield the same outputs. This is the property that makes NES speedrunning possible - runners rely on frame-perfect tricks that work because the game is fully deterministic.

Floating-point breaks this guarantee. Different CPUs may use different intermediate precision (80-bit x87 registers vs 64-bit SSE). Compilers may fuse multiply-add into a single FMA instruction that rounds differently. Go's `float64` may give subtly different results on ARM vs x86. For a game port that must feel like the original, this matters.

### Frame rate normalization

Fixed-point also solves a problem you will face on PC: variable refresh rates. The NES ran at exactly 60fps (NTSC) or 50fps (PAL). PAL games were often 20% slower unless the developer compensated by multiplying all speeds by 1.2 - something only fixed-point made possible on integer hardware. On PC, monitors run at 60, 120, 144, or 240 Hz. If your port assumes 60fps and someone plays on a 120 Hz display, you need the same kind of scaling. Integer fixed-point handles this cleanly: multiply the speed byte by a frame-rate ratio stored as an 8.8 value. No floating-point rounding surprises.

---

## 5. Splitting a Byte in Two: The 4.4 Format

A byte is 8 bits. The simplest way to represent a fractional value in a single byte is to split it down the middle: the top 4 bits hold the integer part, the bottom 4 bits hold the fraction.

```
Byte: IIII FFFF
      ^^^^ ^^^^
      |    |
      |    Fraction: 0 to 15, representing 0/16 to 15/16
      Integer: 0 to 15 (unsigned) or -8 to +7 (signed)
```

This is called **4.4 format**. Four bits for the integer, four bits for the fraction.

### Why /16?

Four bits can hold 2⁴ = 16 distinct values (0 through 15). Each value represents one sixteenth of a pixel. The denominator is always 16 because the number of bits determines the denominator: N fraction bits give you a denominator of 2^N.

If the fraction were 5 bits, the denominator would be 32. If 8 bits, 256. Splitting a byte exactly in half is free - it costs only a few shift instructions to isolate each half, and a byte is the natural unit of everything on the 6502.

### Every possible fraction in 4.4

There are exactly 16 fractional values. No others exist in this format:

```
0/16 = 0.0000      8/16 = 0.5000
1/16 = 0.0625      9/16 = 0.5625   ← a common run speed fraction
2/16 = 0.1250     10/16 = 0.6250
3/16 = 0.1875     11/16 = 0.6875
4/16 = 0.2500     12/16 = 0.7500
5/16 = 0.3125     13/16 = 0.8125
6/16 = 0.3750     14/16 = 0.8750
7/16 = 0.4375     15/16 = 0.9375
```

If you wanted exactly 1.5 pixels per frame, you could not have it - the closest options are 8/16 = 0.5000 or 9/16 = 0.5625. A designer choosing 9/16 gives a run speed of 1.5625. They did not pick 1.5625 as a decimal; they picked `$19` as a byte, and 1.5625 is what falls out.

### Precision at different speeds

The step size in 4.4 is always 1/16 - but the *relative* precision depends on the magnitude:

| Speed | Hex | Step (absolute) | Relative precision |
|-------|-----|-----------------|-------------------|
| 0.0625 | `$01` | 1/16 | 100% (one step = the whole value) |
| 1.0 | `$10` | 1/16 | 6.25% |
| 1.5625 | `$19` | 1/16 | 4.0% |
| 2.5 | `$28` | 1/16 | 2.5% |

Compare to IEEE float16 with machine epsilon ε = 2^-11 ≈ 0.05% relative precision everywhere. Float16 sounds better on paper. But fixed-point's absolute uniformity means no precision surprises when comparing speeds to thresholds. A skid-snap check triggers at exactly the same byte value every time; a run-detection check does too. These comparisons never suffer from rounding - the value is either above the threshold or it is not. In float, a rounding error of ε on a threshold comparison could trigger a state change one frame early or late.

### Maximum and minimum values

**Unsigned 4.4:** The largest value is `$FF` = 15 + 15/16 = **15.9375**. The smallest nonzero value is `$01` = 0 + 1/16 = **0.0625**.

**Signed 4.4** (two's complement, the convention used for signed speed bytes): The range is **-8.0** (`$80`) to **+7.9375** (`$7F`). The smallest positive change is still 1/16 = 0.0625.

### Lowest possible acceleration in 4.4

**0.0625 pixels per frame per frame.** That is 1/16 of a pixel of speed gained each frame. At 60 frames per second, it would take 16 frames (0.27 seconds) to accelerate by a single pixel per frame. For a nominal walk speed of 1.0 px/frame, reaching full speed from standstill would take 16 frames.

For gravity, this is far too coarse. A jump that peaks at dozens of pixels needs subtle, gradual deceleration - much less than 1/16 per frame. That is why fixed-point gravity systems use a different format for forces (section 7).

### Example horizontal speeds in 4.4

These are all example `XSpeed` values, split by a horizontal movement routine exactly as described above:

| Hex | Calculation | Decimal | What it is |
|-----|-------------|---------|------------|
| `$10` | 16/16 | 1.0 | Walk speed (max, no run button) |
| `$19` | 25/16 | 1.5625 | Run speed (observed max) |
| `$28` | 40/16 | 2.5 | Run speed (table max, run button held) |
| `$0C` | 12/16 | 0.75 | Pipe/warp entrance speed |

### Vertical speed is not 4.4

A jump-initiation table might supply the initial value of a `YSpeed` byte when the player jumps: values like `$FC, $FC, $FC, $FB, $FB, $FE, $FF`. It is tempting to read these the same way as the horizontal table above - split the byte, treat the high nybble as pixels and the low nybble as a fraction. That would be wrong. Vertical and horizontal speed are commonly stored in two genuinely different formats:

- **Horizontal** (a `MoveHorizontally`-style routine): `XSpeed` is nybble-split every frame - high nybble is the whole-pixel delta, low nybble (scaled to /256) is the sub-pixel fraction.
- **Vertical** (an `ApplyGravity`-style routine): `YSpeed` is added to `YPosition` as a **raw signed whole byte**, with no split at all:

  ```asm
  lda YSpeed,x                 ; A = YSpeed, the whole byte, unsplit
  ...
  adc YPosition,x              ; Position += YSpeed + carry
  sta YPosition,x
  ```

  So `$FC` as vertical speed is simply `int8(0xFC) = -4`: the character moves up 4 whole pixels per frame from this value alone, not -0.25. `$FB = -5`, a slightly stronger initial velocity for a running jump.

This does not mean vertical motion has no sub-pixel precision - it does, but it comes from a completely different mechanism than horizontal's nybble split. Two accumulator bytes, `YMoveForce` and `YMoveForceDelay`, form a second, independent carry chain: `YMoveForce` accumulates the gravity force value every frame, and its overflow increments `YSpeed` by one whole unit (not 1/16 - see the worked trace in section 7, which is accurate for how *fast `YSpeed` changes*, but does not describe how `YSpeed` is applied to position). Separately, `YMoveForceDelay` accumulates `YMoveForce`'s value from *before* that frame's update, and it is *that* accumulator's overflow - not any split of `YSpeed` - which contributes the extra +1/-1 pixel of position movement on top of `YSpeed`'s raw whole-pixel value each frame. The carry from the `YMoveForceDelay` addition survives across several unrelated instructions that do not touch the carry flag, and is still sitting in the carry flag by the time the gravity routine reaches its position update - a subtle but load-bearing detail of the 6502 carry model, not a fixed-point format at all.

### Other fixed-point formats from the era

The 4.4 split is not the only option. Different games and platforms chose different trade-offs:

| Format | Bits | Precision | Range (unsigned) | Used By |
|--------|------|-----------|------------------|---------|
| 4.4 | 8 (1 byte) | 1/16 | 0 to 15.9375 | Classic NES platformer horizontal velocities |
| 8.8 | 16 (2 bytes) | 1/256 | 0 to 255.996 | NES forces, SNES games |
| 1.7 | 8 (1 byte) | 1/128 | 0 to 1.992 | Sub-pixel schemes in later 16-bit platformers |
| 12.4 | 16 (2 bytes) | 1/16 | 0 to 4095.9375 | Some SNES position systems |
| 16.16 | 32 (4 bytes) | 1/65536 | 0 to 65535.999 | DOOM (1993, PC) |

The choice always reflects the same trade-off: more fraction bits give finer precision but reduce the integer range. The 6502's 8-bit bus makes single-byte formats cheapest, which is why NES platformers squeeze velocity into 4.4 and only use two-byte formats when they must.

---

## 6. Two's Complement for Programmers

A platforming character moves left and right. Speed must be signed - positive for right, negative for left. The 6502 uses two's complement for signed numbers, and understanding it is essential for porting.

### The odometer analogy

Imagine a car odometer that reads 000 to 255 and wraps around. Drive forward one mile from 000 and it reads 001. Now drive *backward* one mile from 000 - it wraps to 255. So 255 represents -1. Drive backward two miles: 254 = -2. Drive backward 128 miles: 128 = -128.

The upper half of the byte (128-255) represents negative numbers. The lower half (0-127) represents positive numbers. The conversion rule: to negate a number, invert all bits and add 1.

```
 +3 = 0000 0011
      ↓ invert
      1111 1100
      ↓ add 1
 -3 = 1111 1101 = $FD = 253 unsigned
```

### Why the 6502 does not care

The beautiful property of two's complement is that addition works identically for signed and unsigned numbers. The hardware does not need a "signed add" instruction.

```
  3 + (-1) using unsigned bytes:
  3 + 255 = 258 → wraps to 2 (carry set)
  Answer: 2. Correct.
```

The carry flag handles the wrap. The 6502's ADC instruction adds two bytes plus carry, sets flags, and stores the result. It has no concept of sign. The programmer interprets the result as signed or unsigned based on context.

### Signed 4.4 in practice

In signed 4.4, the range is -8.0 to +7.9375. The format can represent speeds well beyond what a typical platformer uses:

```
Maximum positive: $7F = +7.9375 px/frame (≈ 476 pixels/second)
Maximum negative: $80 = -8.0 px/frame (≈ 480 pixels/second)
```

A typical maximum run speed might be $28 = +2.5 px/frame (going right), or $D8 = -2.5 px/frame (going left) - well within the format's limits. Designers did not choose 4.4 to accommodate extreme speeds - they chose it because it packs a useful integer range and sufficient fractional precision into a single byte. The format was chosen for the math, not the range. A specific speed cap like +2.5 is a *game design* decision stored in a lookup table, not a format limitation.

---

## 7. When 4.4 Is Not Enough: The 8.8 Format

The smallest speed change possible in 4.4 is 1/16 per frame. For horizontal movement, this is adequate - a character accelerates noticeably each frame. But gravity is different. A good jump needs to feel smooth: the upward velocity should bleed away gradually over 20-30 frames, not in sudden 1/16-pixel steps.

Fixed-point gravity systems solve this with the **8.8 format**: two separate bytes, one for the integer part and one for the fraction.

```
Integer byte: holds the whole-pixel value (0 to 255, or signed -128 to +127)
Fraction byte: holds the fractional part (0 to 255, representing 0/256 to 255/256)

Precision: 1/256 = 0.00390625
```

This is 16 times finer than 4.4 (1/256 vs 1/16). Forces like gravity can now change speed by as little as 1/256 of a pixel per frame - imperceptible on any single frame, but accumulating into smooth curves over many frames.

### Converting a real number to 8.8

To store a value like 3.141 in 8.8 fixed-point:

1. **Multiply by 256** (the fractional denominator): 3.141 × 256 = 804.096
2. **Truncate to integer**: 804
3. **Split into bytes**: 804 = `$0324`. High byte `$03` = 3 (integer). Low byte `$24` = 36/256 = 0.140625 (fraction).

Result: 3.140625. The error is 0.000375 - lost in the truncation. For a game running on a 256-pixel-wide screen, this precision is more than sufficient. As one retro developer put it: "we're not going to notice 0.1 of a degree in accuracy."

To convert back: divide by 256, or just read the high byte. On the 6502, this is a single `LDA` of the integer byte. No computation needed.

### How the two formats interact

A typical NES platformer uses 4.4 for horizontal speed and 8.8-style accumulators for vertical forces, but they are not one single chain feeding into the next - vertical physics runs **two parallel accumulator chains that share a byte**, not four sequential levels:

```
Chain A (changes YSpeed):     force → accumulates into → YMoveForce → carry → YSpeed
Chain B (changes YPosition):  YMoveForce's OLD value → accumulates into → YMoveForceDelay → carry → YPosition
```

`YMoveForce` is read twice every frame, at two different points in its lifecycle: first its value *from before this frame's update* feeds `YMoveForceDelay` (Chain B), and only afterward does it receive this frame's gravity force and produce the carry that feeds `YSpeed` (Chain A). This ordering is why they can share one byte instead of needing four separate ones.

Here is a concrete trace of Chain A with gravity force `$20` (the upward force during a standing jump hold) - this determines how fast `YSpeed` itself changes, not how much the character moves that frame:

```
Frame 1:  YMoveForce = $00 + $20 = $20.  No overflow. YSpeed unchanged.
Frame 2:  YMoveForce = $20 + $20 = $40.  No overflow. YSpeed unchanged.
Frame 3:  YMoveForce = $40 + $20 = $60.  No overflow. YSpeed unchanged.
Frame 4:  YMoveForce = $60 + $20 = $80.  No overflow. YSpeed unchanged.
Frame 5:  YMoveForce = $80 + $20 = $A0.  No overflow. YSpeed unchanged.
Frame 6:  YMoveForce = $A0 + $20 = $C0.  No overflow. YSpeed unchanged.
Frame 7:  YMoveForce = $C0 + $20 = $E0.  No overflow. YSpeed unchanged.
Frame 8:  YMoveForce = $E0 + $20 = $00.  OVERFLOW → YSpeed += 1 (a whole unit, e.g. -4 becomes -3).
```

It took **8 frames** for this force to change `YSpeed` by a whole unit (not 1/16 - vertical speed has no fractional nybble; see "vertical speed is not 4.4" above). That is 0.125 pixels/frame² of effective acceleration on `YSpeed` itself.

Separately, Chain B is running every one of those 8 frames too, using whatever `YMoveForce` held *before* that frame's force was added. This is what lets the character's on-screen position advance smoothly even during the 7 frames where `YSpeed` itself hasn't changed yet - the position update each frame is `YSpeed + carry from Chain B`, so an occasional Chain B overflow adds one extra pixel of movement independent of whether `YSpeed` changed. Both chains together are the mechanism behind a smooth jump arc: `YSpeed` steps in whole-pixel increments only every several frames, while Chain B smooths the position update in between.

### The clamp checks two things, not one

Once `YSpeed` has been incremented by Chain A's carry, the gravity routine clamps it to a maximum falling speed. The obvious implementation is "if `YSpeed >= maxSpeed`, set it to `maxSpeed`." That is not what a real ROM typically does:

```asm
lda YSpeed,x                 ; add carry to vertical speed and store
adc #$00
sta YSpeed,x
cmp $02                      ; compare to maximum speed
bmi ChkUpM                   ; if less than preset value, skip this part
lda YMoveForce,x
cmp #$80                     ; if less positively than preset maximum, skip this part
bcc ChkUpM
lda $02
sta YSpeed,x                 ; keep vertical speed within maximum value
lda #$00
sta YMoveForce,x             ; clear fractional
```

The clamp only fires when **both** conditions hold: `YSpeed >= maxSpeed`, **and** `YMoveForce >= $80`. If `YSpeed` has just reached (or slightly exceeded) the maximum but `YMoveForce`'s fractional half hasn't crossed the halfway point yet, the clamp does nothing this frame - `YSpeed` is allowed to sit one unit above the nominal maximum until `YMoveForce` catches up.

This is not a bug, and it is not an approximation of "clamp when `YSpeed >= maxSpeed`" - it is a deliberate one-frame tolerance built into the comparison itself. Think of it as the clamp asking "has the *momentum* behind this speed change also crossed its own halfway point?", not just "has the speed number reached the ceiling?" A port that only checks `YSpeed >= maxSpeed` will clamp one frame earlier than the original in some cases, and the exact frame it happens on is precisely the kind of detail that separates a "close enough" port from a bit-exact one.

### The optional upward force: a second, mirrored chain sharing one byte

A gravity routine can have a second section that most objects never use. It applies a simultaneous *upward* deceleration in the same call that applied the downward force above, useful for objects whose motion is symmetric in both directions within a single frame - a bouncing enemy, or a moving platform that needs to decelerate as it approaches a boundary. The player character typically never uses this path; its jump deceleration comes from the caller switching which force value it passes to the downward path (a "rising" force table while ascending, a "falling" force table while falling), not from this built-in mechanism.

```asm
ChkUpM:  pla                          ; get value from stack
         beq ExVMove                  ; if set to zero, branch to leave
         lda $02
         eor #%11111111               ; otherwise get two's compliment of maximum speed
         tay
         iny
         sty $07                      ; store two's compliment here
         lda YMoveForce,x
         sec                          ; subtract upward movement amount from contents
         sbc $01                      ; of movement force, note that $01 is twice as large as $00,
         sta YMoveForce,x             ; thus it effectively undoes add we did earlier
         lda YSpeed,x
         sbc #$00                     ; subtract borrow from vertical speed and store
         sta YSpeed,x
         cmp $07                      ; compare vertical speed to two's compliment
         bpl ExVMove                  ; if less negatively than preset maximum, skip this part
         lda YMoveForce,x
         cmp #$80                     ; check if fractional part is above certain amount,
         bcs ExVMove                  ; and if so, branch to leave
         lda $07
         sta YSpeed,x                 ; keep vertical speed within maximum value
         lda #$ff
         sta YMoveForce,x             ; clear fractional
ExVMove: rts                          ; leave!
```

Three things worth pulling out of this:

1. **It is gated by a value the caller pushed onto the stack before calling the gravity routine**, not by whether the upward force happens to be zero. An object can have a nonzero upward-force constant configured and still skip this section entirely on frames where the caller didn't request it.
2. **`SBC` replaces `ADC`** - this chain undoes part of what the downward chain just did, using the borrow convention (§ "Two's Complement for Programmers"): a borrow from the `MoveForce` subtraction propagates into `Speed` via `SBC #$00`, decrementing it by one whole unit, the mirror image of the downward chain's `ADC #$00` incrementing it.
3. **The clamp condition is mirrored, not identical.** The downward clamp fires when `MoveForce >= $80`; the upward clamp fires when `MoveForce < $80` (`bcs ExVMove` skips when `MoveForce >= $80`, the opposite branch direction from the downward check). This is not inconsistent - it is the correct mirror image, because subtracting toward a negative limit and adding toward a positive limit cross their respective "halfway" thresholds from opposite sides. And the clamped `MoveForce` value differs too: the downward clamp resets it to `$00`, the upward clamp resets it to `$FF` - again the correct mirror for a byte that is being subtracted from rather than added to.

### Sub-pixel accumulation explained

The phrase "sub-pixel accumulation" means exactly this carry-chain process. A fractional amount is added to an accumulator byte each frame. Most frames, the byte just gets bigger and nothing visible happens. Occasionally it overflows past 255, setting the carry flag, and the next byte up in the chain gains 1. The overflow *is* the mechanism - there is no rounding, no truncation, no decision. The 6502's carry flag handles it automatically.

**This byte is not a number. It is an accumulator.** This is the most important distinction in NES math, and the reason generic fixed-point libraries cannot help you.

Think of the fractional accumulator as a **delay counter**. It does not represent a position. It counts up until enough fractional movement has built up to earn one whole pixel - then it overflows, the carry fires, and the pixel position advances. The next frame, the counter starts from wherever it wrapped to, not from zero. This is why position uses a separate sub-pixel byte (a `MoveForce`-style variable) rather than being stored in 8.8 format. The sub-pixel byte is an accumulator, not a coordinate. It exists only to catch the fractional crumbs from each frame and occasionally promote them into a real pixel of movement.

One architectural benefit: code that reads only the integer position byte - collision checks, sprite rendering, camera logic - does not need to know about sub-pixels at all. Loading the position byte gets a valid pixel coordinate directly. The sub-pixel system is invisible to everything except the movement routine that writes to it.

---

## 8. The Nybble Split: How Speed Becomes Movement

This is the core routine. Every moving object in a classic NES platformer - the player, enemies, projectiles, platforms - runs code like this every frame:

```asm
MoveHorizontally:
    lda XSpeed,x                ; load speed byte (4.4 format)
    asl                         ; shift left ×4: move low nybble
    asl                         ;   to the high nybble position
    asl
    asl
    sta $01                     ; $01 = fractional adder

    lda XSpeed,x                ; load speed byte again
    lsr                         ; shift right ×4: move high nybble
    lsr                         ;   to the low nybble position
    lsr
    lsr
    cmp #$08                    ; if result < 8, skip sign extension
    bcc SaveXSpd
    ora #%11110000              ; sign extend: fill upper bits with 1s

SaveXSpd:
    sta $00                     ; $00 = integer adder (whole pixels)
```

### The math behind the shifts

**ASL ×4 (shift left 4 times):** Each left shift multiplies by 2. Four shifts multiply by 16. But since we are working in 8 bits, anything in the high nybble gets shifted out and lost. Only the low nybble survives, now occupying the high nybble position.

```
Speed = $19 = 0001 1001
After ASL ×4:  1001 0000 = $90

The low nybble (1001 = 9) is now in the high position.
The old high nybble (0001 = 1) is gone.
```

Why shift it up? Because the sub-pixel accumulator is a full byte (256 values, not 16). The 4-bit fraction needs to be scaled into 8-bit space. Shifting left by 4 is the same as multiplying by 16, which converts a /16 fraction into a /256 fraction: **9/16 = 144/256 = $90**.

**LSR ×4 (shift right 4 times):** Each right shift divides by 2. Four shifts divide by 16. The high nybble slides down to the low position; the old low nybble is shifted out.

```
Speed = $19 = 0001 1001
After LSR ×4:  0000 0001 = $01

The high nybble (0001 = 1) is now the integer part: 1 pixel.
```

This gives us the whole-pixel movement per frame. For $19, that is 1 pixel.

### Why `& 0x0F` works the same way

In a modern language, `speed & 0x0F` isolates the low nybble by masking. And `speed >> 4` isolates the high nybble by shifting. These produce the same results as the 6502's ASL×4 and LSR×4.

### Sign extension: what `CMP #$08 / ORA #$F0` does

After LSR×4, we have a 4-bit value (0-15) sitting in the low half of a byte. If the original speed was negative, this 4-bit value represents a negative integer - but in an 8-bit context, it looks positive.

Example with speed `$E4` (a negative speed, -1.75 in signed 4.4):

```
$E4 = 1110 0100
After LSR ×4: 0000 1110 = $0E = 14

But 14 is wrong. The original high nybble was $E (1110 in binary).
In 4-bit signed, 1110 = -2. We need -2, not +14.
```

The `CMP #$08` checks if the 4-bit value is 8 or higher (meaning bit 3 is set, meaning the original 4-bit integer was negative). If so, `ORA #%11110000` fills the upper 4 bits with ones, turning `0000 1110` into `1111 1110` = -2 in signed 8-bit. This is **sign extension** - stretching a smaller signed value into a larger signed type by replicating the sign bit.

### Full worked example: 4 frames at speed $19

Starting state: `XPosition = $40`, `XMoveForce = $00`, `XPage = $02`. Speed `$19` splits into: integer adder = $01, fractional adder = $90.

```
Frame 1:
  XMoveForce = $00 + $90 = $90.  No overflow (carry = 0).
  XPosition  = $40 + $01 + 0 = $41.
  Moved 1 pixel.  (Position: page 2, pixel $41)

Frame 2:
  XMoveForce = $90 + $90 = $20.  OVERFLOW (carry = 1).
  XPosition  = $41 + $01 + 1 = $43.
  Moved 2 pixels.  (Position: page 2, pixel $43)

Frame 3:
  XMoveForce = $20 + $90 = $B0.  No overflow (carry = 0).
  XPosition  = $43 + $01 + 0 = $44.
  Moved 1 pixel.  (Position: page 2, pixel $44)

Frame 4:
  XMoveForce = $B0 + $90 = $40.  OVERFLOW (carry = 1).
  XPosition  = $44 + $01 + 1 = $46.
  Moved 2 pixels.  (Position: page 2, pixel $46)
```

Pattern: 1, 2, 1, 2... The visible pixel movement alternates because the sub-pixel accumulator ($90 = 144/256) overflows every other frame. The average is (1+2)/2 = 1.5 pixels per frame, but the *actual* average over many frames converges to exactly 1.5625 because 144/256 = 9/16.

This alternating 1-2 pattern is exactly what a run cycle at this speed looks like on real hardware. It is not a bug or a rounding artifact. It is the deterministic consequence of integer arithmetic with sub-pixel accumulation.

### Why the oscillation does not matter

At 60 frames per second, the human eye cannot distinguish "moved 1 pixel" from "moved 2 pixels" on any single frame. It perceives the average: roughly 1.56 pixels per frame of smooth motion. The integer oscillation is invisible, just as 8-bit float rounding is invisible in a neural network's softmax output - the difference between a probability of 0.342 and 0.341 is noise that vanishes when you sample from the distribution.

The NES and modern AI share the same insight: **match your precision to your output channel.** The NES screen has 256×240 pixels with no sub-pixel rendering. The output channel has 1-pixel resolution. Sub-pixel math buys smoothness *over time*, not per-frame accuracy. Spending more bits on higher per-frame precision would be waste - like running a language model in float128 when the output is a discrete token.

---

## 9. Lookup Tables Instead of Multiplication

The 6502 cannot multiply efficiently, but many game calculations require something like multiplication - converting an index to an offset, scaling a speed, computing a position along a curve. NES platformers replace all of these with pre-computed lookup tables stored in ROM.

### Example 1: a friction table

```asm
FrictionTable:
    .db $e4, $98, $d0
```

Three bytes. The entire acceleration/deceleration system for horizontal movement. Instead of computing friction from a formula each frame, the game loads one of three pre-computed values based on the current state (running, walking, or decelerating). The index selects the value; no multiplication needed.

```asm
lda FrictionTable,y   ; Y = 0, 1, or 2. One instruction.
```

On a CPU with multiply, you might compute `base_friction * speed_modifier * ground_type`. On the 6502, you pre-compute the three results anyone would ever need and store them in 3 bytes of ROM.

### Example 2: a rotating hazard's position table

Some NES obstacles rotate in circles. Circular motion requires sine and cosine - transcendental functions that would take hundreds of cycles to compute on a 6502. Rather than computing them, a game can store dozens of pre-computed position offsets:

```asm
HazardPosTable:
    .db $00, $01, $03, $04, $05, $06, $07, $07, $08
    .db $00, $03, $06, $09, $0b, $0d, $0e, $0f, $10
    ; ... 9 more rows, 99 bytes total
```

Each row represents a different distance from the center (each segment of the rotating hazard). Each column represents an angular position. The game reads two values per frame - one horizontal, one vertical - and the hazard traces a smooth circle from nothing but table lookups, addition, and bit shifts.

### Example 3: jump physics tables

Jump behavior is not computed from a formula. It is four parallel lookup tables:

```asm
JumpForceTable:       .db $20, $20, $1e, $28, $28, $0d, $04
FallForceTable:       .db $70, $70, $60, $90, $90, $0a, $09
InitialYSpeedTable:   .db $fc, $fc, $fc, $fb, $fb, $fe, $ff
InitialForceTable:    .db $00, $00, $00, $00, $00, $80, $00
```

The player's horizontal speed at the moment of jumping selects an index (say, 0-4 for ground jumps, 5-6 for swimming). That index pulls four values from four tables: upward force, downward force, initial Y speed, and initial motion force. The entire jump arc is determined by a single table lookup at the moment the player presses the jump button.

### Why lookup tables work here

Lookup tables are practical when the input domain is small and known. A friction system might have 3 states. A rotating hazard might have 11 distance tiers × 9 angular positions = 99 entries. Jump initiation might have 7 speed tiers. These are small, bounded sets. A table that maps 7 inputs to 4 outputs costs 28 bytes of ROM and executes in a handful of cycles. The equivalent computation would cost hundreds of cycles and dozens of instructions. On the NES, ROM is cheap; CPU cycles during gameplay are precious.

---

## 10. The Shift and Comparison Problems: Notes for Modern Language Porters

When the 6502 executes `LSR` (logical shift right), it always shifts in a zero from the left. This is an unsigned operation. The 6502 does not have an arithmetic shift right - it uses `ROR` (rotate through carry) for multi-byte operations instead.

In modern languages, right-shifting a signed integer is where trouble hides.

### The problem

In the nybble split, we need to take a signed speed byte and extract its high nybble as a raw 4-bit pattern:

```
Speed $E4 (signed: -28) → high nybble should be $0E (14 unsigned)
```

**In Go:**
```go
int8(-28) >> 4   // = -2 (arithmetic shift, fills with 1s)
uint8(228) >> 4  // = 14 (logical shift, fills with 0s) ✓
```

Go defines `>>` on signed integers as arithmetic shift (sign-preserving). To get the raw bit pattern, cast to unsigned first.

**In C:**
```c
(int8_t)(-28) >> 4   // IMPLEMENTATION-DEFINED. GCC gives -2. Other compilers may differ.
(uint8_t)(228) >> 4  // = 14. Always correct.
```

C leaves signed right shift as *implementation-defined* - the compiler may fill with zeros or ones. Most compilers sign-extend, but the language does not guarantee it.

**In Rust:**
```rust
(-28i8) >> 4          // = -2 (arithmetic shift, defined behavior)
(228u8) >> 4          // = 14 (logical shift) ✓
// or:
(-28i8 as u8) >> 4    // = 14 ✓
```

**In Java:**
```java
(byte)(-28) >> 4      // = -2 (arithmetic, >> always sign-extends)
(byte)(-28) >>> 4     // = NOT what you expect - Java promotes to int first
((byte)(-28) & 0xFF) >> 4  // = 14 ✓
```

### The safe pattern

The same approach works in every language:

1. Cast the signed speed byte to an unsigned byte
2. Perform the shift and mask on the unsigned value
3. After the split, apply sign extension if the original was negative

```go
raw := uint8(speed)          // step 1: unsigned
fracPart := raw << 4         // low nybble, scaled to 8-bit
intPart := raw >> 4          // high nybble, raw bits
if raw >= 0x80 {             // step 3: was it negative?
    intPart |= 0xF0          // sign extend
}
```

This matches the 6502 exactly: `LSR` ×4 (unsigned shift), then `CMP #$08 / ORA #%11110000` (sign extension).

### The comparison problem

The 6502's `CMP` instruction subtracts without storing the result, then sets flags exactly the way `SBC` would. `BCC`/`BCS` (branching on the carry flag) give you a correct **unsigned** less-than/greater-or-equal test - this is what most NES game code uses, and it is what magnitude comparisons rely on throughout a typical platformer.

`BMI`/`BPL` (branching on the sign bit of the result) look like they should give you a **signed** comparison, and most of the time they do. But they are only correct when the underlying subtraction does not itself overflow the signed range - that is, when the overflow flag (`V`) is clear. If it is set, the sign bit of the result is lying about the true relationship between the two operands.

Concretely: compare `$7F` (+127) to `$80` (-128) using `CMP $80` then `BMI`. The subtraction `$7F - $80` computes as `$FF` in two's complement - bit 7 is set, so `BMI` alone says "the first operand is smaller." But +127 is *obviously* greater than -128. The comparison is wrong, because the subtraction overflowed the signed range and nobody checked `V`. A fully correct signed comparison needs to combine `N` and `V` (conceptually, `N XOR V` gives you the true "less than" result), not just branch on `N`.

Most NES game code avoids this trap by only ever comparing operands it already knows share a narrow, consistent range (e.g. two horizontal speeds that are both known to be within the format's practical bounds), where the naive `BMI`/`BPL` happens to agree with the correct answer. That is a property of *how the game calls* the comparison, not a property of `CMP`/`BMI` in general - and it is exactly the kind of assumption that is easy to lose sight of when porting.

The lesson for a port: do not translate "the ROM used `BMI` here" into "use `<` naively" without checking whether your language's native signed comparison operator does the right thing. In Go, Rust, C, and Java, the native `<`/`>` operators on a signed integer type (`int8`, `i8`, etc.) are **always correct** for the full range of that type - they do not have the 6502's overflow-flag pitfall, because the CPU computes the comparison with wider internal arithmetic than 8 bits. This means a modern-language port is *safer* here than a literal translation of the 6502 branch sequence would be, as long as you compare using the language's signed type and not a raw byte pattern. The trap is comparing raw bytes as if they were unsigned when they are meant to be signed (or vice versa) - not the comparison operator itself.

---

## 11. Porting Checklist

When porting NES physics to a modern language:

**Use integer types.** `uint8` and `int8` for NES bytes, `uint16` for intermediate calculations where overflow matters. Do not use `float32` or `float64` - they introduce rounding behavior that differs from NES integer truncation, causing frame-level divergence in speed, position, and jump height.

**Detect carry manually.** The 6502 carry flag sets automatically on overflow. Modern languages do not have this. The standard pattern:

```go
old := accumulator
accumulator += addend
carry := uint8(0)
if accumulator < old {  // unsigned overflow occurred
    carry = 1
}
```

**Preserve carry between chained adds.** The #1 arithmetic bug in 6502 programming is accidentally clearing the carry between the low-byte and high-byte additions of a multi-byte operation. The same applies in your port: when adding fractional byte, then integer byte, then page byte, the carry from each stage must feed into the next. Do not reset `carry = 0` between them - exactly what the "chaining ADC" exercise on the interactive page demonstrates.

**Sign-extend after unsigned split.** Always cast to unsigned before bit manipulation. Apply sign extension afterward based on the original sign. Never right-shift a signed value when you need raw bit patterns.

**Clamp, do not modulo.** NES speed limits are typically enforced by comparison and clamping (`CMP` + `BCC/BCS`), not by modular arithmetic. When speed exceeds the table maximum, it is set to the maximum, not wrapped.

**Do not use float "for simplicity."** Modern CPUs have fast FPUs, so float seems free. But float introduces three problems that NES integer math avoids:

1. **Non-determinism across platforms.** Go's `float64` may give different results on ARM vs x86 due to FMA instruction fusion and intermediate precision differences. Integer math is identical everywhere.
2. **Threshold comparison failures.** `speed >= 1.0` can fail in float due to rounding - is your speed 0.99999999 or 1.00000001? The NES compares bytes: `CMP #$10` either passes or it does not. No epsilon tolerance needed.
3. **Invisible behavioral drift.** Float behavior subtly differs from NES integer truncation. A jump that peaks at frame 24 in integer math might peak at frame 25 in float. A slide that stops in 16 frames might stop in 17. These 1-frame differences compound across systems, and players who know the original will feel them.

**Design with fixed-point from the start.** One NES developer who retrofitted fixed-point into an existing integer-only codebase reported it took far longer than building with it from day one. If you are starting a fresh port - as you are - use integer types for position and speed from the first line of physics code. Do not prototype with floats and plan to convert later. The conversion is not mechanical; it changes overflow behavior, comparison semantics, and accumulator patterns throughout the codebase.

**Respect the determinism.** Identical inputs must produce identical outputs on every run. This is the property that makes NES speedrunning possible and that players subconsciously rely on for consistent game feel. Integer math guarantees it. Floating-point math does not (across different hardware, compilers, or optimization levels).

### Not every port needs the full stack

Everything above is one game's specific choice, not the NES's only choice. Plenty of NES games get by with a single signed velocity byte added directly into the fractional half of a 16-bit position, with no separate speed/accumulator split at all - or with no fractional component whatsoever, just a fixed whole number of pixels moved every frame. Both degrade to a single carry-chained add with nothing above it.

---

## 12. Designing Your Porting Primitives

Before writing physics code, build a small set of types that model the 6502's hardware roles. The guiding principle: **model hardware roles, not decimal values.**

### Types by role

```go
type Q4_4 uint8         // speed bytes - 4-bit integer + 4-bit fraction
type Accumulator8 uint8 // carry-producing residue buckets (MoveForce, delay accumulators)
type Carry uint8        // 0 or 1, models the 6502 carry flag

type Position16 struct {
    Page  uint8          // which 256-pixel screen
    Pixel uint8          // position within screen
}
```

`Q4_4` is a speed value - you read its integer and fractional parts. `Accumulator8` is not a value - it is a bucket that fills up and occasionally overflows. Giving them different types prevents misuse: you should never read an `Accumulator8` as a meaningful number, and you should never use a `Q4_4` as an accumulator.

### The carry chain as piping, not branching

The 6502's `ADC` instruction adds a value *plus the current carry flag* in a single operation. It does not branch on carry - it incorporates it. Your API should reflect this:

```go
func ADC(a, b uint8, c Carry) (sum uint8, carry Carry)
```

This lets you express the horizontal movement chain as a pipeline:

```go
frac, whole := speed.Split()

var carry Carry
subPixel, carry = ADC(subPixel, frac, 0)          // fractional add
pixel, carry    = ADC(pixel, whole, carry)         // integer add + carry from frac
page, _         = ADC(page, signExtend(whole), carry) // page + carry from pixel
```

Each line feeds its carry into the next. No `if carry { ... }` branching. This matches the 6502 exactly - three `ADC` instructions in sequence, with the carry flag threading through automatically.

Contrast with the wrong approach:

```go
// DON'T: models carry as a branch, not a pipeline
carry := force.Add(gravityForce)
if carry {
    speed = speed.AddRaw(1)  // misrepresents the hardware
}
```

The 6502 never checks "if carry, add 1." It executes `ADC #$00` with the carry already set - the carry propagates implicitly as part of the addition. When you later need to add a real value *and* a carry simultaneously (as horizontal movement does - integer part + carry from fractional add in one ADC), the branching model breaks down. The piping model handles it naturally.

### Horizontal and vertical motion structs

Horizontal and vertical motion use different chain depths, so model them separately:

```go
type HorizontalMotion struct {
    Position  Position16
    MoveForce Accumulator8 // horizontal sub-pixel accumulator
    Speed     Q4_4         // horizontal speed byte
}

type VerticalMotion struct {
    Position  Position16
    MoveForce Accumulator8 // vertical force accumulator
    Dummy     Accumulator8 // delayed copy of MoveForce, for the position chain
    Speed     int8         // raw signed byte, NOT Q4_4
    HighPos   uint8        // off-screen detection
}
```

**Vertical speed is `int8`, not `Q4_4`** (see §5 "Vertical speed is not 4.4"). The vertical carry chain is structurally different from horizontal:

- `MoveForce` accumulates the gravity force. Its overflow promotes `Speed` by one **whole unit** (not 1/16).
- `Dummy` accumulates `MoveForce`'s **old** (pre-update) value. Its carry feeds into the position addition alongside `Speed`'s raw byte.
- `Speed` is added directly to position - no nybble split.

The per-frame algorithm, including the two technicalities from §7 that are easy to drop in a first pass - the clamp's second condition, and the mirrored upward-force path:

```go
carryA := v.Dummy.Add(v.MoveForce.Value())        // uses OLD MoveForce
carryB := v.Position.AddSigned(v.Speed, carryA)    // raw speed, no split
// HighPos gets signExt(Speed) + carryB

carryC := v.MoveForce.Add(force)                   // gravity force input
v.Speed += int8(carryC)                            // whole unit increment

// The clamp needs BOTH conditions - Speed alone is not enough (§7 "The
// clamp checks two things, not one"). Skipping the MoveForce check here
// clamps one frame too early.
if v.Speed >= maxSpeed && v.MoveForce.Value() >= 0x80 {
    v.Speed = maxSpeed
    v.MoveForce = 0
}

// Optional: only for objects that need simultaneous upward deceleration
// in the same call (§7 "The optional upward force"). upForce == 0 skips
// this whole section - the player never uses it.
if upForce != 0 {
    carryD := v.MoveForce.Sub(upForce)
    v.Speed -= int8(1 - carryD) // SBC #$00: borrow decrements Speed by 1

    negatedMax := -maxSpeed // two's complement, mirrors "eor #$ff / iny"
    if v.Speed < negatedMax && v.MoveForce.Value() < 0x80 {
        v.Speed = negatedMax
        v.MoveForce = 0xFF // mirrors the downward clamp's MoveForce = 0
    }
}
```

The field names above describe roles, not any specific disassembly's internal variable names.

This is also a good illustration of why a first-draft port so easily drifts from bit-exact: the naive translation of "clamp Speed to maxSpeed" (one `if`, one condition) reads as complete, compiles, and even passes a casual playtest, because the missing `MoveForce >= 0x80` check only changes behavior on the specific frame where `Speed` first reaches the ceiling *and* `MoveForce`'s fraction hasn't caught up yet - a one-frame window that is easy to never notice by eye, but that a frame-by-frame trace against the real ROM will catch immediately.

### Q4_4 operations

```go
func (s Q4_4) Split() (whole int8, frac uint8) {
    raw := uint8(s)
    frac = raw << 4
    whole = int8(raw >> 4)
    if raw >= 0x80 {
        whole |= -16 // sign extend (equivalent to ORA #$F0)
    }
    return
}

func (s Q4_4) Abs() uint8 // unsigned magnitude, for table indexing
```

`Split()` mirrors a typical horizontal-movement routine exactly. `Abs()` mirrors the absolute-speed helper many games use for jump table selection and animation timing.

### What these primitives are not

They are not a math library. You cannot multiply two `Q4_4` values - a typical NES platformer never does. You cannot convert a `float64` to `Q4_4` - the constructor takes a `uint8` because the NES works in bytes. There is no `String()` method that prints "1.5625" - the decimal representation is a human convenience, not something the game computes.

These types exist to make 6502 arithmetic patterns expressible in Go without manual bit manipulation at every call site. They turn the carry-chain algorithm from section 1 into callable code.

## Next?

You can do the interactive exercises at: https://drpaneas.com/nesmath/ to better understand the concepts here :)
