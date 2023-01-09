# Types

## <a href="#thread_spawn_result" name="thread_spawn_result"></a> `thread-spawn-result`: `s32`

  The result of the `thread-spawn()` function.
  If spawning the thread was successful, the value is positive
  and represents a unique thread identifier. Otherwise, the
  value is negative and it represents error code.

Size: 4, Alignment: 4

## <a href="#start_arg" name="start_arg"></a> `start-arg`: `u32`

  A reference to data passed to the start function (`wasi_thread_start()`) called by the newly spawned thread.

Size: 4, Alignment: 4

# Functions

----

#### <a href="#thread_spawn" name="thread_spawn"></a> `thread-spawn` 

  Creates a new thread.
##### Params

- <a href="#thread_spawn.start_arg" name="thread_spawn.start_arg"></a> `start-arg`: [`start-arg`](#start_arg)
##### Results

- [`thread-spawn-result`](#thread_spawn_result)

