# WASI threads API

WASI threads is an API for thread creation.

Its goal is to provide functions that allow implementation of a subset of `pthreads` API, but it doesn't aim to be 100% compatible with POSIX threads standard.


## thread-id

```wit
/// Unique thread identifier.
type thread-id = u32
```

## start-arg

```wit
/// A reference to data passed to the start function (`wasi_thread_start()`) called by the newly spawned thread.
type start-arg = u32
```

## errno

```wit
/// Error codes returned by the `thread-spawn` function.
enum errno {
    /// TBD
    eagain,
}
```

## thread_spawn

```wit
/// Creates a new thread.
thread-spawn: func(
    /// A value being passed to a start function (`wasi_thread_start()`).
    start-arg: start-arg,
) -> result<thread-id, errno>
```
