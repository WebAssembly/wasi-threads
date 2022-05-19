# Native Threads API

A proposed [WebAssembly System Interface](https://github.com/WebAssembly/WASI) API to add native thread support.

### Current Phase

Phase 1

### Champions

- [Alexandru Ene](https://github.com/AlexEne)
- 

### Phase 4 Advancement Criteria

_TODO before entering Phase 2._

## Table of Contents [if the explainer is longer than one printed page]

- [Introduction](#introduction)
- [Goals [or Motivating Use Cases, or Scenarios]](#goals-or-motivating-use-cases-or-scenarios)
- [Non-goals](#non-goals)
- [API walk-through](#api-walk-through)
  - [Use case 1](#use-case-1)
- [Detailed design discussion](#detailed-design-discussion)
  - [[Tricky design choice 1]](#tricky-design-choice-1)
  - [[Tricky design choice 2 - Adding join, detatch, cancel]](#tricky-design-choice-2)
- [Considered alternatives](#considered-alternatives)
  - [[Alternative 1]](#alternative-1)
- [Stakeholder Interest & Feedback](#stakeholder-interest--feedback)
- [References & acknowledgements](#references--acknowledgements)

### Introduction
This proposal looks to provide a standard API that can be used for thread creation / join and the rest of the operations that are neccessary to run native threads (such as handling threadlocals, taking locks, spawning a thread).

### Goals
The goal of this proposal is to add the missing functions that are required for implementing a subset of `pthread` API. It doesn't aim to be identical to the pthreads API, but must be able to create threads that operate on the same Wasm memory, while using the atomic instrutions to synchronize on memory access.

Standardizing on this would allow re-use of existing libraries and code and remove friction from porting projects from native execution contexts to WebAssembly & WASI environments (outside the browsers).

A possible future direction for WebAssembly is towards supporting multiple-threads per instance. This isn't possible with the current memory model and instruction set. We aim to expose an API that would be compatible with this future direction.

For browsers, we aim to provide a way to polyfill these APIs, leaveraging web-workers, in a similar to how it works today.

### Non-goals

The goal of this API is not to be 100% compatible with all functions and options described by POSIX threads standard.  

The current proposal is limited to the WASI APIs signatures and behavior and doesn't propose changes to the Wasm instruction set.

### API walk-through

The API requires the addition of a single function.  
The mutex/signaling/TLS could be implemented using existing instructions available in WASM:  
```
status thread_spawn(thread_id* thread_id, const thread_attributes* attrs, thread_start_func* function, thread_args* arg);
```

#### [Use case 1]
Implementing standard libraries on top of this API (e.g. Rust stdlib, pthreads).

#### [Use case 2]
Support for thread-local storage.

### Detailed design discussion
**TODO**: 
* Define attributes supported.
* Clarify data types to match how other WASI methods are specified
* Does it need a stack_size parameter?
* Does it need instructions on how to set up the stack size?

#### How threads start
When a thread is started by `thread_spawn` the following happens:  
1) The module instance is is cloned.  
2) A native thread is created.  
3) On that thread we call into a `_start_thread` function from the Wasm module created above and forwards the `arg` parameter (a pointer to the shared memory.  
4) `_start_thread` Function then launches the target `function` with the `arg` parameter.  

`pthread_create` can be implemented by forwarding a call to the new `thread_spawn` API.  
```
int pthread_create(pthread_t* thread_id, const pthread_attr_t* attr, void* *(*start_routine)(void*), void* arg);
```

The following functions can potentially be implemented either by introducing new WASI APIs similar to, or by using WASM atomics (e.g. in the case of `pthread_join`):
```
int pthread_join(pthread_t thread, void **retval);

// Can this work without a new WASI API?
int pthread_detach(pthread_t thread);

// How would this work?
int pthread_cancel(pthread_t thread);

pthread_t pthread_self(void);
```
This is currently highlighted in [[Design choice 2]](#tricky-design-choice-2)

All synchronization functions below can be implemented WASI libc with existing constructs available in the language (atomics) and don't require a new WASI function:  

Mutexes:  
```
int pthread_mutex_init(pthread_mutex_t *mutex, const void *attr);

int pthread_mutex_lock(pthread_mutex_t *mutex);

int pthread_mutex_unlock(pthread_mutex_t *mutex);

int pthread_mutex_destroy(pthread_mutex_t *mutex);

```

RW Locks:  
```
int pthread_rwlock_init(pthread_rwlock_t *rwlock, const pthread_rwlockattr_t *attr);

int pthread_rwlock_rdlock(pthread_rwlock_t *rwlock);

int pthread_rwlock_tryrdlock(pthread_rwlock_t *rwlock);

int pthread_rwlock_trywrlock(pthread_rwlock_t *rwlock);

int pthread_rwlock_wrlock(pthread_rwlock_t *rwlock);

int pthread_rwlock_unlock();

int pthread_rwlock_destroy(pthread_rwlock_t *rwlock);
```

Conditionals:  
```
int pthread_cond_init(pthread_cond_t *cond, const void *attr);

int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);

int pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, unsigned int useconds);

int pthread_cond_signal(pthread_cond_t *cond);

int pthread_cond_broadcast(pthread_cond_t *cond);

int pthread_cond_destroy(pthread_cond_t *cond);
```

Thread-specific data:  
```
int pthread_key_create(pthread_key_t *key, void (*destructor)(void *));

int pthread_setspecific(pthread_key_t key, const void *value);

void *pthread_getspecific(pthread_key_t key);

int pthread_key_delete(pthread_key_t key);
```

Extra ones:
```
pthread_yield
```

#### [Tricky design choice #1]

This could be implemented either by cloning the current Wasm instance and executing it on another thread, or by having the instance shared amonst threads. Cloning the instance means that all the WASM constructs such as: Wasm globals (not C++ globals, these live in the Wasm linear memory, not the instance data), function tables will be thread local. 

We consider this a good approach for the first implementation phase and aim to switch to a multiple threads per Wasm Instance once the `shared` attributes are added to the Wasm spec. Sharing the same instance right now is blocked on that attribute. More data on it can be found in this paper: [Weakening WebAssembly](https://www.researchgate.net/publication/336447205_Weakening_WebAssembly).

There are disadvantages to this approach of a thread gets its own module instance such as:
* Memory consumption (as each instance is cloned)
* Breaking behavior on non-standard functions such as `dlopen()` that require to modify the function table.  
* Potential breaking behaviour of existing binaries once a new instruction gets added. This is low risk because no attributes on globals/tables/etc. having the meaning of `shared` in a future wasm spec iteration isn't a likely approach. Most likely, no attributes would be interpreted as `local`/`private` as that would keep the existing behavior for binaries.

The API here shouldn't need to change the signature if new annotations and instructions get added to the standard (e.g. `shared` and `local` flags on `globals`, `tables`, etc.). Regardless of those, the function exposed in this proposal will still take the same arguments and have the same return types in all of the potential execution modes. The function signature and observed behavior should stay the same (except dlopen behavior that is more restricted above).

#### [Tricky design choice #2]
While the following functions can potentially be implemented in wasm bytecode (is this true for `pthread_detatch`?), leaveraging the atomic operations available, it may be benefficial to have these functions included in the WASI proposal as this would aleviate bytecode size concerns for WASM binaries, performance concerns and can also potentially simplify some implementation details.
 
```
int pthread_join(pthread_t thread, void **retval);

int pthread_detach(pthread_t thread);

int pthread_cancel(pthread_t thread);

pthread_t pthread_self(void);
```

### Considered alternatives

#### [Alternative 1]

[WASI-parallel](https://github.com/WebAssembly/wasi-parallel/blob/main/docs/Explainer.md).

*TODO(alexene) check that this understanding is correct*   
The wasi-parallel proposal could be used in similar ways to [OpenMP](https://www.openmp.org/). That mode of parallelism solves a category of problems (map-reduce type algorithms are suited to such an approach), but can't be applied to other workloads that are covered in this proposal that require more fine-grained control over how threads are created/destroyed and their lifetimes.

### Stakeholder Interest & Feedback

TODO before entering Phase 3.

[This should include a list of implementers who have expressed interest in implementing the proposal]

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
