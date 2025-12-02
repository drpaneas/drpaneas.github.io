+++
categories = ["golang"]
date = "2025-12-02T02:46:35+01:00"
tags = ["golang", "dreamcast", "retro"]
title = "The Case of the Phantom Memory Corruption"

+++

*Or: How a Single Wrong Pointer Ruined My Week*

---

It started, as these things always do, with a test that should have been trivial.

I'm building **libgodc** that is a Go runtime for the Sega Dreamcast. Yes, that Dreamcast. The one with the Hitachi SH-4 processor that Sega shipped in 1998. The one that ran Sonic Adventure and Soul Calibur. I want it to run Go.

If you're wondering why anyone would do this: partly because it's fun, partly because constrained environments force you to truly understand what you're building. The Dreamcast has 16MB of RAM and no operating system to speak of just [KallistiOS](http://gamedev.allusion.net/softprj/kos/), a homebrew development library. Every byte matters. Every abstraction has a cost.

The test was embarrassingly simple:

```go
func main() {
    done := make(chan bool, 2)
    
    go func() { done <- true }()
    go func() { done <- true }()
    
    <-done
    <-done
    println("PASS")
}
```

Two goroutines send to a channel. Main receives twice. Print "PASS". That's it.

The first receive worked. The second one? Kaboom.

```
Unhandled exception: PC 8c01051e, code 1, evt 00e0
R0-R7: 00000001 8c080106 8c06d6bc 00000200...
```

A memory access violation. The program was trying to read from address `0x8c080106`, which "spoiler alert" contained nothing useful. On the Dreamcast, addresses starting with `0x8c` are in the main RAM region, but this particular address was in a no-man's land between initialized data and the heap.

I had no idea that this crash would consume the better part of a week.

---

## A Brief Detour: How Go's Runtime Works

Before we dive into the debugging, let me explain some internals that most Go developers never need to think about.

When you write `go func() { ... }()`, the Go runtime creates a **goroutine**. Internally, the runtime represents each goroutine with a data structure called `G`. This isn't documented in the standard library. It lives in the [runtime source code](https://github.com/golang/go/blob/master/src/runtime/runtime2.go), and unless you're hacking on the runtime itself, you'll never see it.

The `G` struct contains everything the runtime needs to manage a goroutine: its stack boundaries, its current execution state, its panic/defer chains, and much more. Here's a simplified view:

```go
type g struct {
    stack       stack   // stack bounds
    _panic      *_panic // innermost panic
    _defer      *_defer // innermost defer
    m           *m      // current M (machine/OS thread)
    sched       gobuf   // scheduling state
    // ... dozens more fields
}
```

The runtime also has `M` (machine, representing an OS thread) and `P` (processor, representing a scheduling context). Together, G, M, and P form Go's famous [GMP scheduler model](https://go.dev/src/runtime/proc.go). For libgodc, I implement a simplified M:1 scheduler and all goroutines share a single OS thread and cooperatively yield to each other.

Channels are another runtime construct. When you call `make(chan bool, 2)`, the runtime allocates an [`hchan` struct](https://github.com/golang/go/blob/master/src/runtime/chan.go) that manages the buffer, the wait queues, and the synchronization. When a goroutine blocks on a channel operation, it gets added to a wait queue using a `sudog` (short for "pseudo-G") that is a structure that represents "this goroutine is waiting for this specific operation."

With that context, let's get back to the crash.

---

## Down the Rabbit Hole

My first suspect was the context switching code. Goroutines on libgodc work through cooperative scheduling: when a goroutine blocks (say, waiting on a channel), it saves its CPU state and switches to another goroutine.

The SH-4 processor has registers r8 through r14 that are "callee-saved", a.k.a. any function that uses them must restore their original values before returning. If my `swapcontext` assembly was corrupting any of them, chaos would ensue. A corrupted r14 (the frame pointer) would make the CPU look for local variables in the wrong place. A corrupted r8 might trash a value the caller was counting on.

I pulled up the disassembly. The `sh-elf-objdump` tool is part of the cross-compilation toolchain for SH-4, and the `-d` flag disassembles the binary:

```bash
sh-elf-objdump -d test_simple_exit.elf | grep -A 50 "swapcontext"
```

```asm
___go_swapcontext:
    mov.l   r8, @(0, r4)    ; Save r8 to context
    mov.l   r9, @(4, r4)    ; Save r9
    mov.l   r10, @(8, r4)   ; Save r10
    mov.l   r11, @(12, r4)  ; etc...
    mov.l   r12, @(16, r4)
    mov.l   r13, @(20, r4)
    mov.l   r14, @(24, r4)
    ; ... restore from new context ...
```

The assembly looked fine. Registers saved, registers restored, nothing obviously wrong. But "nothing obviously wrong" is the most dangerous state in. It means the bug is hiding somewhere you haven't looked yet.

---

## The Struct Layout Massacre

A friend suggested I check the `G` struct layout. Here's the thing about Go's runtime: the compiler generates code that accesses struct fields by *byte offset*, not by name. When the compiler emits code to read `gp.param`, it doesn't generate a symbolic reference to "the param field." It generates "load from address gp + 20". This is where 20 is the offset of `param` in the struct.

This means if you're implementing the runtime in C (as I am for libgodc), your struct layout must *exactly* match what the Go compiler expects. A mismatch means writes go to wrong fields, reads return garbage, and demons fly out of your nose.

I wrote a quick offset checker:

```c
printf("param offset: %zu\n", offsetof(G, param));
```

The Go compiler expected `param` at offset 20. My struct had it at offset 240.

*Two hundred and twenty bytes off.*

When Go code wrote `gp.param = something`, it was actually scribbling over my `context.r9` field, in the right in the middle of saved register state. This was a real bug. But was it *the* bug?

I spent hours reordering the struct to match the expected layout. This meant carefully reading through [gofrontend's runtime2.go](https://github.com/pgeorgia/gccgo/blob/master/libgo/go/runtime/runtime2.go) (gofrontend is GCC's Go implementation, which libgodc builds on) and matching every field:

```c
typedef struct G {
    struct _PanicRecord *_panic;     // Offset 0
    struct _GccgoDefer *_defer;      // Offset 4
    void *m;                         // Offset 8
    uintptr_t syscallsp;             // Offset 12
    uintptr_t syscallpc;             // Offset 16
    void *param;                     // Offset 20 - NOW CORRECT
    // ... 40+ more fields ...
} G;
```

Rebuilt everything. Ran the test.

Same crash. Same corrupted address: `0x8c080106`.

The struct layout was a real bug! But it wasn't *this* bug. I had fixed something important, but the phantom corruption was still there.

---

## Instrumenting the Crime Scene

Time to get surgical. I needed to know exactly when the corruption happened.

The crash occurred when `main` tried to load the channel pointer from its stack. In Go, local variables live on the stack, and the channel variable `done` is no exception. Somewhere between "main parks waiting for data" and "main wakes up," that pointer was getting trashed.

I added diagnostic prints to the channel receive code. The function `gopark` is what puts a goroutine to sleep and it saves the current state and switches to the scheduler:

```c
// Before parking
uint32_t *chan_ptr_loc = (uint32_t*)(frame_pointer + 104);
printf("BEFORE: chan_ptr at %p = %08lx\n", chan_ptr_loc, *chan_ptr_loc);

gopark(chanparkcommit, c, waitReasonChanReceive);

// After waking
printf("AFTER: chan_ptr at %p = %08lx\n", chan_ptr_loc, *chan_ptr_loc);
```

The `frame_pointer + 104` calculation came from disassembling `main.main` and seeing where the compiler stored the `done` variable. This is tedious work: you look at the assembly, count the stack offsets, and figure out where each variable lives.

The output was damning:

```
BEFORE: chan_ptr at 0x8c488728 = 8c084a50
AFTER:  chan_ptr at 0x8c488728 = 8c080106
```

The pointer was fine when main went to sleep. It was corrupted when main woke up. Something happened *while main was parked* and the only things running during that time were the sender goroutines.

This was a crucial realization. The corruption wasn't happening in main's code. It was happening in *someone else's* code, stomping on main's stack from the outside.

---

## Following the Money

In channel operations, when a sender finds a waiting receiver, it copies data directly to the receiver's stack. This is an optimization whereinstead of putting the data in the channel buffer and having the receiver copy it out, the sender writes straight to where the receiver wants the data.

The receiver provides a pointer (`sg->elem`) saying "put the data here." The sender does `memcpy(sg->elem, &value, size)`.

I added more instrumentation to the send path:

```c
printf("sg->elem = %p\n", sg->elem);
printf("channel elemsize = %u\n", c->elemsize);
printf("memcpy %u bytes to %p\n", c->elemsize, sg->elem);
```

And there it was:

```
Main's chan_ptr at 0x8c488768
sg->elem = 0x8c488766
memcpy 4 bytes to 0x8c488766
```

Do you see it?

The receiver's element pointer was at `0x8c488766`. The channel pointer was at `0x8c488768`. That's a difference of *two bytes*.

The memcpy was writing *four* bytes.

```
0x8c488766  ← byte 0 of the bool
0x8c488767  ← byte 1 (overflow!)
0x8c488768  ← byte 2 (this is where the channel pointer starts!)
0x8c488769  ← byte 3 (still the channel pointer!)
```

The send operation was overflowing into the channel pointer. The 4-byte write was stomping on adjacent memory.

Mystery solved. Well... sort of. But why four bytes? The channel held `bool` values. A bool is one byte.

---

## The Smoking Gun

I traced back to channel creation. When you call `make(chan bool, 2)`, the runtime calls an internal function `makechan` that allocates the channel structure. One of its jobs is to determine the element size:

```c
hchan *makechan(struct __go_type_descriptor *elemtype, int64_t size)
{
    size_t elemsize = elemtype->__size;
    printf("elemsize = %zu\n", elemsize);
    // ...
}
```

Output:

```
elemsize = 4
```

Four bytes. But bool is one byte. What was going on?

Here's where I need to explain something about Go's type system at the runtime level. Every type in Go has a **type descriptor**, a data structure that describes the type's size, its alignment, how to compare values of that type, how the garbage collector should scan it, and more. The compiler generates these descriptors and embeds them in the binary.

When you compile a Go program, you can see these type descriptors in the symbol table. The `nm` tool lists all symbols in a binary:

```bash
sh-elf-nm test_simple_exit.elf | grep "type\.\."
```

```
8c052198 V _type..bool
8c0521bc V _type..chan_bbool
8c0521e4 V _type..func()
```

Each `_type..XXX` symbol is a type descriptor. The address `0x8c0521bc` is the descriptor for `chan bool`.

I had printed that the type descriptor passed to `makechan` was at address `0x8c0521bc`. Looking it up:

```bash
sh-elf-nm test_simple_exit.elf | grep 8c0521bc
```

```
8c0521bc V _type..chan_bbool
```

That's `chan bool`, in which the *channel* type, not the *element* type!

---

## Understanding the Root Cause

Here's what I had missed. The Go compiler doesn't pass the element type to `makechan`. It passes the *channel* type. This makes sense if you think about it. Remember: the runtime might need to know things about the channel itself (like its direction: send-only, receive-only, or bidirectional).

But the channel type descriptor contains a pointer to the element type. The structure looks like this:

```c
// A plain type descriptor (for simple types like bool, int, etc.)
struct __go_type_descriptor {
    uintptr_t __size;        // Size of values of this type
    uintptr_t __ptrdata;     // Size of memory prefix holding pointers
    uint32_t __hash;         // Hash of the type
    // ... more fields ...
};

// A channel type descriptor (extends the base descriptor)
struct __go_chan_type {
    struct __go_type_descriptor __common;          // Base type info (36 bytes)
    struct __go_type_descriptor *__element_type;   // Pointer to element's type!
    uintptr_t __dir;                               // Channel direction
};
```

When you have a `chan bool`, the type descriptor is a `__go_chan_type`. Its `__common.__size` field is the size of the channel type descriptor itself (which happens to be a small number due to struct. In my case, 4 bytes). The *element* size is in `__element_type->__size`.

My original code was doing this:

```c
// WRONG: This reads the channel type's size, not the element's size!
size_t elemsize = chantype->__size;  // Returns 4 (size of chan type descriptor)
```

It should have been doing this:

```c
// CORRECT: Cast to chan_type, then get the element type's size
struct __go_chan_type *ct = (struct __go_chan_type *)chantype;
struct __go_type_descriptor *elemtype = ct->__element_type;
size_t elemsize = elemtype->__size;  // Returns 1 (size of bool)
```

The fix was three lines, but understanding *why* those three lines were needed took days of investigation.

---

## The Corruption Pattern Explained

With the root cause understood, the corrupted value `0x8c080106` suddenly made sense.

The original channel pointer was `0x8c084a50`. On a little-endian system (which the SH-4 is), this is stored in memory as bytes `50 4a 08 8c`.

The bool value `true` is stored as `0x01`. But we were writing 4 bytes, not 1. The extra 3 bytes came from whatever garbage happened to be adjacent to the source value.

The write started 2 bytes before the channel pointer. After the 4-byte memcpy:

```
Memory before:  ?? ?? 50 4a 08 8c
                      ^^ channel pointer starts here
                
Memory after:   ?? ?? 06 01 08 8c
                      ^^ ^^ overwritten by the 4-byte write
```

Reading those 4 bytes as a little-endian 32-bit value: `0x8c080106`. Exactly what the crash reported.

The `01` in the corrupted value was literally the boolean `true` being written. The corruption left a fingerprint. I just didn't recognize it until I understood what was happening.

---

## Could I Have Found This Faster?

Absolutely. Looking back, there were several points where I could have short-circuited the investigation:

**1. I should have checked the element size immediately.**

When the crash first happened, I could have added a simple print to `makechan`:

```c
printf("Creating channel: elemsize=%zu\n", elemsize);
```

Seeing "elemsize=4" for a `chan bool` would have been an immediate red flag. Instead, I spent days chasing register corruption theories.

**2. I should have analyzed the corrupted value sooner.**

The value `0x8c080106` wasn't random. It had structure:

- The upper bytes `08 8c` matched the heap region prefix
- The `01` byte screamed "boolean true"

If I had stared at that value and asked "where could `01` come from?", I might have connected it to the channel send much earlier.

**3. I should have added memory guards.**

A simple technique: when allocating the receive buffer, pad it with known sentinel values and check if they get overwritten:

```c
// Allocate extra space with sentinels
char buffer[16] = {0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xDE, 0xAD, 0xBE, 0xEF, ...};
// The actual receive goes into buffer[4]
// After receive, check if buffer[0..3] or buffer[5..] changed
```

This would have immediately shown that the write was overflowing.

**4. I got distracted by the struct layout issue.**

The G struct layout mismatch was a real bug, and fixing it was the right thing to do. But I spent too long on it, convinced it must be the cause of this specific crash. When the crash persisted after the fix, I should have immediately pivoted to other theories instead of double-checking the struct layout for the third time.

---

## The Lesson

This bug took about four days to find. That might sound like a lot for what turned out to be a simple type confusion. But here's the thing: debugging is rarely a straight line.

I went down the register corruption path. Dead end, but I learned my context switching was correct.

I went down the struct layout path. Found and fixed a real bug, but not *this* bug.

I went down the stack corruption path. Finally found the culprit.

Each "wrong" path wasn't wasted time. It was eliminating possibilities and building understanding. The struct layout investigation taught me exactly how gofrontend lays out its data structures. The register corruption investigation confirmed my assembly was sound. By the time I found the real bug, I understood the system much more deeply than when I started.

That's how you build expertise. Not by reading documentation (though that helps), but by breaking things and figuring out why they broke.

---

## Epilogue

The Dreamcast is a 27-year-old console. Getting Go to run on it means understanding both the high-level abstractions and the low-level reality of how compilers generate code. The Go language presents a clean model: goroutines, channels, garbage collection. But underneath, there's assembly code shuffling registers, type descriptors encoding metadata, and memory being copied byte by byte.

Sometimes a bug that looks like black magic: registers corrupted, pointers changing spontaneously, has a perfectly mundane explanation. A type cast that should have been there. A field that should have been dereferenced. Three lines of code.

You just have to find it.

---

*The code for libgodc (will soon be available) at [github.com/pgeorgia/libgodc](https://github.com/drpaneas/libgodc). If you're interested in Go internals, I recommend reading the [runtime source code](https://github.com/golang/go/tree/master/src/runtime). It's surprisingly approachable, and there's no better way to understand what your programs are actually doing.*
