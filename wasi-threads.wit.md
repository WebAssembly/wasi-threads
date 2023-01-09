# WASI threads API

WASI threads is an API for thread creation.

Its goal is to provide functions that allow implementation of a subset of `pthreads` API, but it doesn't aim to be 100% compatible with POSIX threads standard.


## thread-id

```wit
/// The result of the `thread-spawn()` function.
/// If spawning the thread was successful, the value is positive
/// and represents a unique thread identifier. Otherwise, the
/// value is negative and it represents error code.
type thread-spawn-result = s32
```

## start-arg

```wit
/// A reference to data passed to the start function (`wasi_thread_start()`) called by the newly spawned thread.
type start-arg = u32
```

## thread_spawn

```wit
/// Creates a new thread.
thread-spawn: func(
    /// A value being passed to a start function (`wasi_thread_start()`).
    start-arg: start-arg,
) -> thread-spawn-result
```
