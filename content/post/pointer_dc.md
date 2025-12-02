+++
categories = ["golang"]
date = "2025-12-02T02:46:35+01:00"
tags = ["golang", "dreamcast", "retro"]
title = "The Case of the Phantom Memory Corruption"

+++

*Or: How a Single Wrong Pointer Ruined My Week*

---

I'm building **libgodc** that is a Go runtime for the Sega Dreamcast. Yes, that Dreamcast. The one with the Hitachi SH-4 processor that Sega shipped (North America) in 9/9/1999. The one that ran Sonic Adventure and Crazy Taxi. I want it to run Go.

If you're wondering why anyone would do this: partly because it's fun, partly because constrained environments force you to truly understand what you're building. The Dreamcast has 16MB of RAM and no operating system to speak of just [KallistiOS](http://gamedev.allusion.net/softprj/kos/), a homebrew development library. Every byte matters when you speak to metal. And unless you code in Rust, every abstraction has a cost. And [I made it](https://x.com/falco_girgis/status/1991805987586543671), with a really barebones runtime, but that's not what this story is all about. This story is about implementing goroutines ... for Dreamcast!

Now, let's be honest about something upfront: `goroutines` on the Dreamcast are largely pointless from a practical standpoint. The SH-4 is a single-core CPU,there's no parallelism to exploit. You can't make things faster by spinning up more goroutines; they all take turns on the same processor. The "concurrency" you get is just cooperative multitasking with extra steps. If I wanted to ship a game, I'd write straightforward C and be done in a weekend. But that's not the point. The point is proving it's *possible*,and in doing so, learning exactly how Go's runtime works at the deepest level.

> Sometimes the journey matters more than the destination, especially when the destination is about retro-gamedev!

It started, as these things always do, with a test that should have been trivial. Actually, the test was embarrassingly simple:

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

The first receive worked. The second one? Kaboom. lol!

```shell
Unhandled exception: PC 8c01051e, code 1, evt 00e0
R0-R7: 00000001 8c080106 8c06d6bc 00000200...
```

A memory access violation. The program was trying to read from address `0x8c080106`, which "spoiler alert" contained nothing useful. On the Dreamcast, addresses starting with `0x8c` are in the main RAM region, but this particular address was in a no-man's land between initialized data and the heap.

I had no idea that this crash would consume the better part of two weeks (especially after midnight, when the little-ones are asleep).

---

## A Quick Primer: Stack vs Heap (and Where Things Live)

Before we go further, let's make sure we're on the same page about where data lives in memory. If you've never thought about this, here's a quick example:

```go
func example() {
    x := 42              // Lives on the STACK (local variable)
    y := new(int)        // Lives on the HEAP (dynamically allocated)
    z := make(chan bool) // Lives on the HEAP (runtime allocates it)
    
    fmt.Println(x, *y, z)
}
```

**The Stack** is like a notepad that each function gets when it's called. Local variables (`x` in the example) go here. When the function returns, that notepad is thrown away. It's fast, automatic, and limited in size.

**The Heap** is like a warehouse. When you need memory that outlives a function call,or when the compiler can't prove the data stays local,it goes here. Channels, slices, maps, and anything created with `new()` or `make()` typically live on the heap. The garbage collector's job is to clean up the warehouse when things are no longer needed.

### Where Does the Dreamcast Put These?

The Dreamcast hardware doesn't have an operating system. It just exposes 16MB of RAM starting at address `0x8C000000`. That's it,raw memory, no stack, no heap, nothing organized.

So who creates the stack and heap? **KallistiOS** (the homebrew OS library) and **libgodc** (my Go runtime) do. In libgodc's source code, you can see exactly where these regions are defined:

```c
// From runtime/dreamcast_support.c
#define DREAMCAST_RAM_BASE 0x8C000000
#define DREAMCAST_RAM_SIZE (16 * 1024 * 1024)  // 16MB

// From runtime/gc_semispace.h  
#define GC_SEMISPACE_SIZE (2 * 1024 * 1024)    // 2MB per space
#define GC_TOTAL_HEAP_SIZE (2 * GC_SEMISPACE_SIZE) // 4MB total for GC
```

The memory layout looks roughly like this:

```
Dreamcast RAM: 0x8C000000 - 0x8CFFFFFF (16MB)
┌─────────────────────────────────────────────────┐
│ Program code (.text)          ~0x8C010000       │ ← Your compiled Go code
│ Read-only data (.rodata)                        │ ← String literals, type descriptors
│ Initialized data (.data, .bss)                  │ ← Global variables
├─────────────────────────────────────────────────┤
│ GC Heap Space 0 (2MB)         ~0x8C080000       │ ← Go objects: channels, slices, etc.
│ GC Heap Space 1 (2MB)                           │ ← Used during garbage collection
├─────────────────────────────────────────────────┤
│ Goroutine stacks (8KB each)   ~0x8C480000       │ ← Each goroutine gets its own stack
│ KOS malloc arena                                │ ← General allocations
├─────────────────────────────────────────────────┤
│ Main thread stack             ~0x8CFFFFFF       │ ← KOS's main thread
└─────────────────────────────────────────────────┘
```

The GC heap is allocated by libgodc using KallistiOS's `memalign()` function,libgodc asks KOS for 4MB of memory, and KOS returns a pointer somewhere in the `0x8C08xxxx` range.

### What's "No Man's Land"?

When I said the crash address `0x8c080106` was in "no man's land," I meant it was in the gap between regions,after the initialized program data but before any actual heap objects were allocated. It's technically valid RAM, but nothing meaningful lives there. Reading from it returns garbage; writing to it corrupts nothing useful (until something *does* get allocated there).

Let me zoom into the GC heap region to show exactly where the corruption pointed:

```
GC Heap Space 0 (starts at ~0x8C080000)
┌─────────────────────────────────────────────────────────────────────┐
│ 0x8C080000  ┌───────────────────────────────────────┐               │
│             │ Heap header / metadata                │               │
│ 0x8C080100  ├───────────────────────────────────────┤               │
│             │                                       │               │
│             │   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │               │
│             │   ░░░░░ NO MAN'S LAND ░░░░░░░░░░░░░   │  ← 0x8C080106 │
│             │   ░░░░░ (unallocated space) ░░░░░░░   │    points HERE│
│             │   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │    (garbage!) │
│             │                                       │               │
│ 0x8C084000  ├───────────────────────────────────────┤               │
│             │ First real allocation (e.g. channel)  │               │
│ 0x8C084A50  │   ← The ACTUAL channel lives here     │  ← VALID ptr  │
│             │                                       │               │
│ 0x8C085000  ├───────────────────────────────────────┤               │
│             │ More Go objects...                    │               │
│             │                                       │               │
└─────────────┴───────────────────────────────────────┴───────────────┘
```

The corrupted pointer `0x8c080106` pointed to this wasteland because the memory corruption had overwritten a valid heap pointer (`0x8c084a50`, where the channel actually lived) with garbage bytes.

Now, with that context, let's look at Go's runtime internals.

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

The runtime also has `M` (machine, representing an OS thread) and `P` (processor, representing a scheduling context). Together, G, M, and P form Go's famous [GMP scheduler model](https://leapcell.io/blog/unveiling-go-s-scheduler-secrets-the-g-m-p-model-in-action). For libgodc, I implement a simplified M:1 scheduler and all goroutines share a single OS thread and cooperatively yield to each other.

Channels are another runtime construct. When you call `make(chan bool, 2)`, the runtime allocates an [`hchan` struct](https://github.com/golang/go/blob/master/src/runtime/chan.go) that manages the buffer, the wait queues, and the synchronization. When a goroutine blocks on a channel operation, it gets added to a wait queue using a `sudog` (hort for "pseudo-G") that is a structure that represents "this goroutine is waiting for this specific operation." Here's how it looks like in memory:

```
make(chan bool, 2) creates:

┌─────────────────────────────────────────────────────────────────────────┐
│                         hchan struct                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  qcount: 0          │ Number of elements currently in buffer            │
│  dataqsiz: 2        │ Buffer capacity (we asked for 2)                  │
│  buf: ──────────────┼──► [  ] [  ]   ← Circular buffer for 2 bools      │
│  elemsize: 1        │ Size of each element (bool = 1 byte)              │
│  closed: false      │ Is the channel closed?                            │
│  sendq: ────────────┼──► (empty list of waiting senders)                │
│  recvq: ────────────┼──► (empty list of waiting receivers)              │
│  lock: ...          │ Mutex for thread safety                           │
└─────────────────────────────────────────────────────────────────────────┘
```

When a goroutine blocks on a channel operation, it gets added to a wait queue using a `sudog` (short for "pseudo-G"),a structure that represents "this goroutine is waiting for this specific operation."

For example, when `main` calls `<-done` but the channel is empty, here's what happens:

```
BEFORE: main calls <-done (channel empty, must wait)

┌─────────────────────────────────────────────────────────────────────────┐
│                         hchan struct                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  qcount: 0                                                              │
│  buf: [  ] [  ]     ← Empty, nothing to receive                         │
│  sendq: ──────────► (empty)                                             │
│  recvq: ──────────► ┌─────────────────────────────────┐                 │
│                     │ sudog (main is waiting here)    │                 │
│                     │   g: ──► main's G struct        │                 │
│                     │   elem: ──► &receivedValue      │ ← Where to put  │
│                     │   c: ──► this channel           │   the data      │
│                     └─────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────┘

Main goroutine is now PARKED (sleeping), waiting for someone to send.

─────────────────────────────────────────────────────────────────────────────

AFTER: goroutine1 calls done <- true

┌─────────────────────────────────────────────────────────────────────────┐
│  Sender finds main waiting in recvq!                                    │
│                                                                         │
│  Instead of putting 'true' in the buffer, sender:                       │
│    1. Copies 'true' directly to main's elem pointer                     │
│    2. Wakes up main (marks it runnable)                                 │
│    3. Removes sudog from recvq                                          │
│                                                                         │
│  recvq: ──────────► (empty again)                                       │
│  buf: [  ] [  ]     ← Buffer never used! Direct handoff.                │
└─────────────────────────────────────────────────────────────────────────┘

Main goroutine WAKES UP with the value already in its stack variable.
```

This direct handoff optimization is elegant,but it's also where our bug lurked. The sender writes directly to the receiver's stack. If the size is wrong, it overwrites adjacent memory.

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

## Put the Struct in Order

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

## The Crime

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

In channel operations, when a sender finds a waiting receiver, it copies data directly to the receiver's stack. This is an optimization,instead of putting the data in the channel buffer and having the receiver copy it out, the sender writes straight to where the receiver wants the data.

The receiver provides a pointer (`sg->elem`) saying "put the data here." The sender does `memcpy(sg->elem, &value, size)`.

Here's how the direct handoff works:

```
SENDER (goroutine1)                         RECEIVER (main, parked)
                                            
   done <- true                              <-done (waiting)
       │                                           │
       ▼                                           ▼
┌──────────────────┐                    ┌──────────────────────────────┐
│ value = true     │                    │ Main's Stack                 │
│ (1 byte: 0x01)   │                    │                              │
└────────┬─────────┘                    │  0x8c488766: receivedValue   │◄─┐
         │                              │  0x8c488768: done (chan ptr) │  │
         │   memcpy(sg->elem,           │  0x8c48876C: other locals... │  │
         │          &value,             └──────────────────────────────┘  │
         │          elemsize)                                             │
         │                                                                │
         └──────────── sg->elem points here ──────────────────────────────┘
                       "Copy the value directly to receiver's stack"
```

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

The receiver's element pointer was at `0x8c488766`. The channel pointer was at `0x8c488768`. That's a difference of *two bytes*. The memcpy was writing *four* bytes.

Here's what SHOULD have happened (1-byte write for bool):

```
Main's Stack (addresses grow DOWN)
                                                    
Address      Before          After memcpy(1 byte)   
─────────────────────────────────────────────────────
0x8c488766   [  ??  ]        [  01  ]  ← bool 'true' written here ✓
0x8c488767   [  ??  ]        [  ??  ]  ← untouched
0x8c488768   [  50  ]  ─┐    [  50  ]  ─┐
0x8c488769   [  4a  ]   │    [  4a  ]   │  Channel pointer
0x8c48876a   [  08  ]   ├─►  [  08  ]   ├─►  0x8c084a50 (VALID!)
0x8c48876b   [  8c  ]  ─┘    [  8c  ]  ─┘
```

Here's what ACTUALLY happened (4-byte write, WRONG!):

```
Main's Stack (addresses grow DOWN)
                                                    
Address      Before          After memcpy(4 bytes)   
─────────────────────────────────────────────────────
0x8c488766   [  ??  ]        [  01  ]  ← bool 'true'
0x8c488767   [  ??  ]        [  06  ]  ← OVERFLOW! garbage byte
0x8c488768   [  50  ]  ─┐    [  01  ]  ← CORRUPTED! was part of chan ptr
0x8c488769   [  4a  ]   │    [  08  ]  ← CORRUPTED! 
0x8c48876a   [  08  ]   ├─►  [  08  ]   ├─►  0x8c080106 (GARBAGE!)
0x8c48876b   [  8c  ]  ─┘    [  8c  ]  ─┘
                        
             VALID               CORRUPTED
          0x8c084a50           0x8c080106
```

The 4-byte memcpy steamrolled right over the channel pointer!

Mystery solved,sort of. But why four bytes? The channel held `bool` values. A bool is one byte

---

## GATE-4 ΠΑΟΚ

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

Here's what I had missed. The Go compiler doesn't pass the element type to `makechan`. It passes the *channel* type. This makes sense if you think about it,the runtime might need to know things about the channel itself (like its direction: send-only, receive-only, or bidirectional).

But the channel type descriptor contains a pointer to the element type. Let me visualize the type descriptor hierarchy:

```
When you write: make(chan bool, 2)

The compiler generates TWO type descriptors in the binary:

┌─────────────────────────────────────────────────────────────────────────────┐
│  _type..bool (at 0x8c052198)                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  __go_type_descriptor                                               │    │
│  │    __size: 1          ← bool is 1 byte                              │    │
│  │    __ptrdata: 0                                                     │    │
│  │    __hash: 0x...                                                    │    │
│  │    __code: kindBool                                                 │    │
│  │    ...                                                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  _type..chan_bbool (at 0x8c0521bc)                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  __go_chan_type                                                     │    │
│  │    __common: (embedded __go_type_descriptor)                        │    │
│  │      __size: 4        ← size of the chan_type struct itself!        │    │
│  │      __code: kindChan                                               │    │
│  │      ...                                                            │    │
│  │    __element_type: ───────────────────────────────────────────────────►  │
│  │    __dir: bothDir     (send and receive)                            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                                                          │
                                              Points to _type..bool ◄─────┘
```

The Go compiler passes `_type..chan_bbool` (the channel type) to `makechan`, NOT `_type..bool` (the element type). The channel type *contains* a pointer to the element type.

Here's the structure in C:

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

So when you have a `chan bool`, the type descriptor passed to `makechan` is a `__go_chan_type`. Its `__common.__size` field is NOT the element size,it's the size of the channel type descriptor struct itself (which happens to be 4 bytes). The *actual element size* is hidden one pointer away, in `__element_type->__size`.

My original code was doing this:

```
WRONG: Reading __size from the channel type directly

  makechan receives: chantype ──► _type..chan_bbool
                                        │
                                        ▼
                              ┌─────────────────────┐
                              │ __common.__size: 4  │ ◄── I read THIS
                              │ __element_type: ─────────► _type..bool
                              │ __dir: bothDir      │            │
                              └─────────────────────┘            ▼
                                                        ┌───────────────┐
                                                        │ __size: 1     │
                                                        └───────────────┘
                                                          (never reached!)

  Result: elemsize = 4  ← WRONG! This is the chan_type struct size!
```

```c
// WRONG: This reads the channel type's size, not the element's size!
size_t elemsize = chantype->__size;  // Returns 4 (size of chan type descriptor)
```

It should have been doing this:

```
CORRECT: Following the pointer to get the element type's size

  makechan receives: chantype ──► _type..chan_bbool
                                        │
                                        ▼
                              ┌─────────────────────┐
                              │ __common.__size: 4  │   (ignored)
                              │ __element_type: ─────────► _type..bool
                              │ __dir: bothDir      │            │
                              └─────────────────────┘            ▼
                                                        ┌───────────────┐
                                                        │ __size: 1     │ ◄── Read THIS
                                                        └───────────────┘

  Result: elemsize = 1  ← CORRECT! This is the actual bool size!
```

```c
// CORRECT: Cast to chan_type, then get the element type's size
struct __go_chan_type *ct = (struct __go_chan_type *)chantype;
struct __go_type_descriptor *elemtype = ct->__element_type;
size_t elemsize = elemtype->__size;  // Returns 1 (size of bool)
```

The fix was three lines, but understanding *why* those three lines were needed took days of investigation

---

## The Corruption Pattern Explained

With the root cause understood, the corrupted value `0x8c080106` suddenly made sense. Let me walk through exactly how the bytes got mangled.

When the sender executes `done <- true`, it has a local variable containing the value `true`:

```
Sender's stack (source of memcpy):

Address       Value      Meaning
────────────────────────────────────────────
0x8c487f00    [  01  ]   ← bool 'true' (this is what we want to send)
0x8c487f01    [  06  ]   ← garbage (uninitialized stack memory)
0x8c487f02    [  08  ]   ← more garbage
0x8c487f03    [  8c  ]   ← more garbage
              ▲
              │
              └── memcpy starts here, copies 4 bytes (WRONG! should be 1)
```

The receiver (`main`) has its local variables laid out on the stack:

```
Main's stack BEFORE the memcpy:

Address       Value      Variable
────────────────────────────────────────────
0x8c488766    [  ??  ]   ← receivedValue (where bool should go)
0x8c488767    [  ??  ]   ← (padding/alignment)
0x8c488768    [  50  ]  ─┐
0x8c488769    [  4a  ]   │  'done' channel pointer
0x8c48876a    [  08  ]   │  = 0x8c084a50 (little-endian)
0x8c48876b    [  8c  ]  ─┘  Points to valid hchan on heap
```

The sender does `memcpy(sg->elem, &value, 4)` , writing 4 bytes instead of 1:

```
memcpy copies 4 bytes from sender to receiver:

Source:           Destination:
[01 06 08 8c] ──► [?? ?? 50 4a]
                       ▲
                       │
                  Overwrites into channel pointer!

Main's stack AFTER the memcpy:

Address       Value      What happened
────────────────────────────────────────────
0x8c488766    [  01  ]   ← bool 'true' ✓ (correct)
0x8c488767    [  06  ]   ← GARBAGE from sender's stack!
0x8c488768    [  08  ]  ─┐ CORRUPTED! Was [50]
0x8c488769    [  8c  ]   │ CORRUPTED! Was [4a]
0x8c48876a    [  08  ]   │ (unchanged, lucky coincidence)
0x8c48876b    [  8c  ]  ─┘ (unchanged)
```

When `main` wakes up and tries to use the channel again, it reads the pointer:

```
Reading 'done' as little-endian 32-bit pointer:

Address       Byte
────────────────────
0x8c488768    [08]  ← least significant byte
0x8c488769    [8c]
0x8c48876a    [08]
0x8c48876b    [8c]  ← most significant byte

Reassembled: 0x8c080106  ← GARBAGE POINTER!

Compare to original: 0x8c084a50  ← Valid channel

                     0x8c08 4a50
                          ↓
                     0x8c08 0106  ← Middle bytes corrupted!
```

### The Fingerprint

Notice something interesting? The corrupted value `0x8c080106` contains `01` , that's the boolean `true` we were trying to send! The corruption left a fingerprint:

```
Corrupted pointer: 0x8c080106
                        ││
                        │└── 06 = garbage from sender's stack
                        └─── 01 = the boolean 'true' value!
```

If I had recognized this pattern earlier,"why does the corrupted pointer contain `01`?",I might have connected it to the channel send much sooner.

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

The Dreamcast is a ~30-year-old console. Getting Go to run on it means understanding both the high-level abstractions and the low-level reality of how compilers generate code. The Go language presents a clean model: goroutines, channels, garbage collection. But underneath, there's assembly code shuffling registers, type descriptors encoding metadata, and memory being copied byte by byte.

Sometimes a bug that looks like black magic: registers corrupted, pointers changing spontaneously, has a perfectly mundane explanation. A type cast that should have been there. A field that should have been dereferenced. Three lines of code.

You just have to find it.

---

*The code for libgodc (will soon be available) at [github.com/drpaneas/libgodc](https://github.com/drpaneas/libgodc). If you're interested in Go internals, I recommend reading the [runtime source code](https://github.com/golang/go/tree/master/src/runtime). It's surprisingly approachable, and there's no better way to understand what your programs are actually doing.*
