# `wasi-threads`

A proposed [WebAssembly System Interface](https://github.com/WebAssembly/WASI)
API to add native thread support.

### Current Phase

Phase 1

### Champions

- [Alexandru Ene](https://github.com/AlexEne)

### Phase 4 Advancement Criteria

_TODO before entering Phase 2._

## Table of Contents

- [Introduction](#introduction)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [API walk-through](#api-walk-through)
  - [Use case: support various languages](#use-case-support-various-languages)
  - [Use case: support thread-local storage](#use-case-support-thread-local-storage)
- [Detailed design discussion](#detailed-design-discussion)
  - [Design choice: thread IDs](#design-choice-thread-ids)
  - [Design choice: termination](#design-choice-termination)
  - [Design choice: pthreads](#design-choice-pthreads)
  - [Design choice: instance-per-thread](#design-choice-instance-per-thread)
- [Considered alternatives](#considered-alternatives)
  - [Alternative: WebAssembly threads](#alternative-webassembly-threads)
  - [Alternative: wasi-parallel](#alternative-wasi-parallel)
- [Stakeholder Interest & Feedback](#stakeholder-interest--feedback)
- [References & acknowledgements](#references--acknowledgements)

### Introduction
This proposal looks to provide a standard API for thread creation. This is a
WASI-level proposal that augments the WebAssembly-level [threads proposal]. That
WebAssembly-level proposal provides the primitives necessary for shared memory,
atomic operations, and wait/notify. This WASI-level proposal solely provides a
mechanism for spawning threads. Any other thread-like operations (thread
joining, locking, etc.) will use primitives from the WebAssembly-level proposal.

Some background: browsers already have a mechanism for spawning threads &mdash;
[Web Workers] &mdash; and the WebAssembly-level proposal avoided specifying how
thread spawning should occur. This allows other uses of WebAssembly &mdash;
i.e., outside the browser &mdash; to specify their own mechanism for spawning
threads.

[threads proposal]: https://github.com/WebAssembly/threads
[Web Workers]: https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers


### Goals
- __`pthreads` support__: the goal of this proposal is to add the missing
  functions that are required to implement a subset of `pthreads` API. It does
  not aim to be identical to the `pthreads` API, but one must be able to create
  threads that operate on a shared Wasm memory while using the WebAssembly
  atomic instructions to synchronize on memory access.

- __library reuse__: standardizing this API would allow re-use of existing
  libraries and remove friction when porting projects from native
  execution contexts to WebAssembly and WASI environments (outside the
  browsers).

- __future-compatible__: a possible future direction for WebAssembly is towards
  supporting multiple threads per instance. We aim to expose an API that would
  be compatible with this future direction.

- __browser polyfills__: for browsers, we aim to provide a way to polyfill this
  API using Web Workers providing similar functionality to what exists in
  browsers today.



### Non-goals
- __full POSIX compatibity__: this API will not be 100% compatible with all
  functions and options described by POSIX threads standard.

- __modify core WebAssembly__: the current proposal is limited to the WASI APIs
  signatures and behavior and does not propose changes to the Wasm instruction
  set.



### API walk-through

The API consists of a single function. In pseudo-code:

```C
status wasi_thread_spawn(thread_start_arg* start_arg);
```

where the `status` is a unique non-negative integer thread ID (TID) of the new
thread (see [Design choice: thread IDs](#design-choice-thread-ids)) or a
negative number representing an error if the host failed to spawn the thread.
The host implementing `wasi_thread_spawn` will call a predetermined function
export (`wasi_thread_start`) in a new WebAssembly instance. Any necessary
locking/signaling/thread-local storage will be implemented using existing
instructions available in WebAssembly. Ideally, users will never use
`wasi_thread_spawn` directly but rather compile their threaded code from a
language that supports threads (see below).

#### Use case: support various languages

Using this API, it should be possible to implement threads in languages like:
- __C__, using the `pthreads` library (see the current work in [wasi-libc])
- __Rust__, as a part of the `std` library (in the future, e.g., [here])

The API should be able to support even more languages, but supporting these
initially is a good starting point.

[wasi-libc]: https://github.com/WebAssembly/wasi-libc
[here]: https://github.com/rust-lang/rust/blob/7308c22c6a8d77e82187e290e1f7459870e48d12/library/std/src/sys/wasm/atomics/thread.rs

#### Use case: support thread-local storage

For languages that implement thread-local storage (TLS), the start argument can
contain a language-specific structure with the address and (potentially) the
length of a TLS memory region. The host WebAssembly engine will treat this
argument as an opaque pointer &mdash; it should not introspect these
language-specific details. In C, e.g., the start function should be a static
trampoline-like wrapper (exported as `wasi_thread_start`) that reads the actual
user start function out of the start argument and calls this after doing some
TLS bookkeeping (this is not much different than how C starts threads natively).



### Detailed design discussion

Threads are tricky to implement. This proposal relies on a specific convention
in order to work correctly. When instantiating a module which is expected to run
with `wasi-threads`, the WASI host must first allocate shared memories to
satisfy the module's imports.

Upon a call to `wasi_thread_spawn`, the WASI host must:

1. instantiate the module again &mdash; this child instance will be used for the
   new thread
2. in the child instance, import all of the same WebAssembly objects,
   including the above mentioned shared memories, as the parent
3. optionally, spawn a new host-level thread (other spawning mechanisms are
   possible)
4. calculate a positive, non-duplicate thread ID, `tid`, and return it to the
   caller; any error in the previous steps is indicated by returning a negative
   error code.
5. in the new thread, call the child instance's exported entry function with the
   thread ID and the start argument: `wasi_thread_start(tid, start_arg)`

A WASI host that implements the above should be able to spawn threads for a
variety of languages.

#### Design choice: thread IDs

When `wasi_thread_spawn` successfully spawns a thread, it returns a thread ID
(TID) &mdash; 32-bit integer with several restrictions. TIDs are managed and
provided by the WASI host. To avoid leaking information, the host may choose to
return arbitrary TIDs (as opposed to leaking OS TIDs).

Valid TIDs fall in the range $[1, 2^{29})$. Some considerations apply:
- `0` is reserved for compatibility reasons with existing libraries (e.g.,
  wasi-libc) and must not be returned by `wasi_thread_spawn`
- the uppermost three bits of a valid TID must always be `0`. The most
  significant bit is the sign bit and recall that `wasi_thread_spawn` uses
  negative values to indicate errors. The remaining bits are reserved for
  compatibility with existing language implementations.

#### Design choice: termination

A `wasi-threads` module initially executes a single thread &mdash; the main
thread. As `wasi_thread_spawn` is called, more threads begin to execute. Threads
terminate in the following ways:

- __upon return__ from `wasi_thread_start`, and other threads continue to
  execute
- __upon a trap__ in any thread; all threads are immediately terminated
- __upon a `proc_exit` call__ in any thread; all threads are immediately
  terminated.

#### Design choice: pthreads

One of the goals of this API is to be able to support `pthreads` for C compiled
to WebAssembly. Given a WASI host that implements `thread_spawn` as described
above, what responsibility would the C language have (i.e., `libc`) to properly
implement `pthreads`?

`pthread_create` must not only call WASI's `wasi_thread_spawn` but is also
responsible for setting up the new thread's stack, TLS/TSD space, and updating
the `pthread_t` structure. This could be implemented by the following steps
(ignoring error conditions):
1. configure a `struct start_args` with the user's `void *(*start_func)(void *)`
   and `void *start_arg` (as done natively) but also with `pthread_t *thread`
2. call `malloc` (instead of `mmap`) to allocate TLS/TSD in the shared
   WebAssembly memory
3. define a static, exported `wasi_thread_start` function that takes as
   parameters `int tid` and `void *start_args`
4. in `pthread_create`, call `wasi_thread_spawn` with the configured
   `start_args` and use `atomic.wait` to wait for the `start_args->thread->tid`
   value to change (note that for web polyfills this may not be necessary since
   creation of web workers is not synchronous)
5. now in the child thread: once the WASI host creates the new thread instance
   and calls `wasi_thread_start`, then a) set `args->thread->tid` to the
   host-provided `tid`, b) set the `__wasilibc_pthread_self` global to point to
   `args->thread` (this is used by `pthread_self`, e.g.), c) use `atomic.notify`
   to inform the parent thread that the child now has a `tid`, d) start
   executing the user's `start_func` with the user's `start_arg` &mdash; at this
   point the new instance is executing separately in its own thread
6. back in the parent thread: once it has been notified that the child has
   recorded its TID, it can safely return with the `pthread_t` structure
   properly filled out.

`pthread_join` has a similar `wait`/`notify` implementation, but in reverse: the
parent thread can `wait` on the `thread->return` address to change and the child
thread can `notify` it of this once the user's start function finishes (i.e., at
the end of the `wasi_thread_start` wrapper).

The remainder of the `pthreads` API can be split up into what can be implemented
and what can safely be skipped until some later date.

##### What can easily be implemented

- `pthread_self` can use the `__wasilibc_pthread_self` global to return the
  address to the current thread's `pthread_t` structure; this relies on each
  thread mapping to a new instance (and thus a new set of globals) &mdash see
  discussion below on "instance per thread."
- `pthread_detach` can be implemented by using the flags already present in the
  `pthread_t` structure.
- `pthread_mutex_*`, `pthread_rwlock_*`, `pthread_cond_*`, `sem_*` can all be
  implemented using existing operations in the WebAssembly [threads proposal].
- thread-specific data (TSD), i.e., functions using `pthread_key_t`, can be
  implemented using the memory region allocated for the thread in WebAssembly
  shared memory.

##### What can be skipped
- `pthread_yield` is a [deprecated] `pthreads` function; `sched_yield` is the
  right one to use. Since it is unclear how WASI's scheduling should interact
  with the host's, this can be deferred until someone has a use case for it.
- `pthread_cancel` allows a parent thread to cancel a child thread; in
  particular, asynchronous cancellation is difficult (impossible?) to implement
  without a WebAssembly mechanism to interrupt the child thread and it
  complicates the entire implementation. It can be left for later.

[deprecated]: https://man7.org/linux/man-pages/man3/pthread_yield.3.html

##### What _has_ been implemented

`wasi-libc` contains an implementation of `pthreads` using `wasi-threads`. The
implementation is currently in progress: see the [list of threads-related
PRs](https://github.com/WebAssembly/wasi-libc/pulls?q=is%3Apr+threads).

#### Design choice: instance-per-thread

A thread spawning mechanism for WebAssembly could be implemented in various
ways: the way chosen here, a cloned "instance-per-thread," is one option. The
other major option is to share the instance among many threads, as described in
the [Weakening WebAssembly] paper. Sharing an instance among many threads, as
described there, would require:
 - WebAssembly objects (memories, tables, globals, functions) to allow a
   `shared` attribute
 - the WebAssembly specification to grow a `fork` instruction

[Weakening WebAssembly]: https://www.researchgate.net/publication/336447205_Weakening_WebAssembly

The "instance-per-thread" approach was chosen here because a) it matches the
thread instantiation model of the browser (also "instance-per-thread") and b)
the WebAssembly specification changes required for the other approach may take
some time to materialize. In the meantime, this proposal allows threaded
WebAssembly to progress. If in the future the WebAssembly specification were to
add a "many-threads-per-instance" mechanism, the hope is that the API here
should not need to change significantly, though it is unclear how much the
changes might be.

The "instance-per-thread" approach chosen here does have its disadvantages:
* higher memory consumption (each instance is cloned)
* breaking behavior on non-standard functions such as `dlopen()` that require to
  modify the function table
* potential breaking behaviour of existing binaries once a new instruction gets
  added. This is a low risk because `shared` attributes do not yet exist on
  globals/tables/etc. having the `shared` attribute in a future WebAssembly spec
  version is not a likely approach. Most likely, no attributes would be
  interpreted as `local`/`private` as that would keep the existing behavior for
  binaries.



### Considered alternatives

#### Alternative: WebAssembly threads

Instead of exposing threads at the WASI level, thread spawning could be
specified in the WebAssembly specification. This is the approach described in
the [Weakening WebAssembly] paper. See the [Design choice:
instance-per-thread](#design-choice-instance-per-thread) discussion above for
more details.

#### Alternative: wasi-parallel

[wasi-parallel] is another WASI proposal which provides a parallel "for"
construct, similar to what, e.g., [OpenMP](https://www.openmp.org/) provides.
[wasi-parallel] spawns `N` threads at a time (though they may not all run
concurrently); this API spawns a single thread at a time.

[wasi-parallel]: https://github.com/WebAssembly/wasi-parallel/blob/main/docs/Explainer.md



### Stakeholder Interest & Feedback

TODO before entering Phase 3.

<!-- [This should include a list of implementers who have expressed interest in
implementing the proposal] -->


### References & acknowledgements

Many thanks for valuable feedback and advice from (alphabetical order):
* [Amanieu d'Antras](https://github.com/Amanieu)
* [Andrew Brown](https://github.com/abrown)
* [Conrad Watt](https://github.com/conrad-watt)
* [George Kulakowski](https://github.com/kulakowski-wasm)
* [Nathaniel McCallum](https://github.com/npmccallum)
* [Petr Penzin](https://github.com/penzn)
* [Sam Clegg](https://github.com/sbc100)
* [Wang Xin](https://github.com/xwang98)
* [Wenyong Huang](https://github.com/wenyongh)
* Xu Jun
