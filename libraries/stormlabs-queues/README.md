# stormlabs-queues

## Public API overview

Generic immutable stacks, priority queues with caller ordering, and ring deques; updates return replacement values. See the [complete public API](API.md) for exact signatures, effects, overloads, and examples.

**Validation status:** All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. The larger native suites reported below are historical results from before the namespace rename; they were not rerun for this revision. Performance remains unmeasured.

Generic native Verse stacks, heap priority queues, and ring deques.

The earlier implementation compiled without diagnostics and passed 20 named native check groups covering generic payloads, stack/heap/ring behavior, bounds, and snapshots in the local UEFN host. The complete log matched the exact source and run identities, and the captured deployed provider/wrapper hashes matched the selected files. Separate compile controls rejected all seven intended constructor/type/state accesses; positive compilation succeeded before and after those controls. The Verse VM variant was not recorded. Performance remains unmeasured; these bounded results do not establish correctness for every type/input or a frame-budget guarantee.

## Installation and generic types

Copy `src/stormlabs_queues.verse` into your project's Verse source folder. For generic consumers, use the dependency-before-application naming convention: name the installed library copy `10_stormlabs_queues.verse` and place application files after every installed library, for example `90_game.verse`. Keep the repository's canonical filename unchanged. The copy still defines `Queues`; outside consumers import it from their own project's Verse path. There are no other StormLabs dependencies, native bindings, or production test imports.

This convention addresses observed current-compiler sensitivity to generic provider/consumer source processing order. The copied queue provider compiled without diagnostics in the combined twelve-library numbered installation; the earlier 20-group runtime result is a separate check. This does not establish a language guarantee of alphabetical compilation. Recheck the installed layout after compiler upgrades or changes to consuming files.

`stack(t:type)`, `priority_queue(t:type)`, and `deque(t:type)` accept arbitrary element types, including integers, strings, records, option values, and class references. None requires `comparable`, a default element, type erasure, nor an implementation copied for each element type. Factories take an explicit type argument, for example `MakeStack[int]`, `MakePriorityQueue[int, IntBefore]`, and `MakeDeque[string]`.

## Value semantics and ownership

Containers are immutable generic values. Every update returns a new container; callers must retain the returned value. Existing containers and aliases preserve their structure. A successful operation that returns a replacement does not update the caller's variable automatically. `Pop` returns `(new container, removed element)`, in that order.

Element copies are **shallow**. A class element remains a reference to the same object, including when exported or removed. There is no deep clone, automatic disposal, persistence support, manual allocator, or native-pointer promise. The comparator must be pure and deterministic, and ordering-relevant element state must remain consistent for the lifetime of the heap. Independent container snapshots do not make referenced mutable objects independent.

## Persistent stacks

`MakeStack[t, ?MaxCount := 2147483647]` creates an empty generic `stack(t)`. `Push[Value]` returns a new stack with that value on top, failing at the count limit. `Peek[]` returns the top and fails on empty; `Pop[]` returns `(new stack, removed top)` and also fails on empty. `Count()` and `MaxCount()` report logical count and limit. `Clear()` returns a new empty stack retaining the limit, and `ToArray[]` exports values **top to bottom**. No element comparison or default value is needed. Zero capacity is valid and permits no push; count limits follow the same 0..2147483647 contract as the other containers.

Stack snapshots share immutable generic linked nodes. Push creates one node pointing to the previous head and a new stack wrapper. Pop creates a wrapper pointing to the existing next node. Neither operation traverses the tail or constructs an array; clear constructs an empty wrapper. These have a constant abstract number of node/wrapper operations, without a measured native allocation/time guarantee or a promise about garbage collection. Snapshot export traverses the linked nodes iteratively and builds an array; it does not use recursive call depth. Keeping older stack values retains their reachable nodes and shallow element references.

## Priority queues

`Before` has type `type{_(:t, :t)<computes><decides>:void}`. Success means the left element has higher priority than the right. Supply a deterministic strict weak order; reverse it to switch min/max behavior. Comparator failure means that the left does not precede the right, not an error report. Comparator laws are a caller obligation and are not exhaustively checked. Equivalent priorities are **unstable**, without an insertion-order guarantee.

| Operation | Contract |
| --- | --- |
| `MakePriorityQueue[t, Before]` | New empty heap with logical limit 2147483647 |
| `MakePriorityQueue[t, Before, MaxCount]` | New empty heap with a checked positional element limit |
| `Heapify[t, Data, Before]` | Bottom-up heap from an array with logical limit 2147483647; no sorting |
| `Heapify[t, Data, Before, MaxCount]` | Bottom-up heap from an array; rejects input above the checked positional limit |
| `Count()`, `MaxCount()` | Element count and logical limit |
| `Peek[]` | Highest-priority element; fails on empty |
| `Push[Value]` | New heap containing the extra element; fails at the limit |
| `Pop[]` | Tuple `(new heap, highest-priority element)`; fails on empty |
| `Clear()` | New empty heap retaining comparator and limit |
| `HeapSnapshot()` | Array snapshot in **unsorted heap layout**, with shallow elements |

The heap invariant is that no child precedes its parent. Neither heap construction nor removal sorts all elements. There is no arbitrary removal, update-key, FIFO tie counter, or iterator framework.

The default and explicit-limit forms are separate overloads. For example, `Heapify[int, Values, IntBefore, 100]` retains the same array/comparator behavior with a limit of 100. The limit is positional; these two comparator-taking factories do not accept `?MaxCount := ...`. This spelling avoids an observed compiler specialization limitation while keeping the pure failable order, generic element types, and checked failure contract. Stack and deque factories retain their documented named optional parameters.

## Ring deques

A deque's logical order is front to back. Physical storage is a ring of optional slots, so no default `t` value is required. Only occupied slots hold elements; newly returned snapshots clear removed slots.

| Operation | Contract |
| --- | --- |
| `MakeDeque[t, ?InitialCapacity := 0, ?MaxCount := 2147483647]` | Empty deque; checked capacity not above the limit |
| `DequeFromArray[t, Data, ?InitialCapacity := 0, ?MaxCount := 2147483647]` | Preserve input order; capacity is `max(Data.Length, InitialCapacity)` |
| `Count()`, `Capacity()`, `MaxCount()` | Logical length, slot count, and logical limit |
| `Get[Index]`, `Front[]`, `Back[]` | Checked zero-based access; empty access fails |
| `PushFront[Value]`, `PushBack[Value]` | Return a new deque with the value at that end |
| `PopFront[]`, `PopBack[]` | Return `(new deque, removed element)`; fail on empty |
| `Reserve[Capacity]` | Return a snapshot with at least the requested capacity; never shrink or discard elements |
| `Clear()` | New empty deque retaining capacity and limit |
| `ToArray[]` | Snapshot in front-to-back logical order, with shallow elements |

A full ring grows to `min(MaxCount, max(4, 2 * old capacity))`, retaining all elements and their order. Push fails at the logical limit instead of overwriting an element. Pops retain capacity; no automatic shrink occurs. `Reserve` validates 0..MaxCount even when the request would not grow storage. Growth, reserve, clear, and input-array construction may allocate capacity-sized arrays.

Both element limits and capacities are bounded by 2147483647. This is an API arithmetic bound, not a promise that an allocation or operation of that size will succeed within a UEFN budget. Index arithmetic uses exact integers and no floating point.

## Effects, failures, and actual costs

Every public operation has `<transacts>`. Checked access, push/pop, heapify, deque reserve/export, and factories additionally have `<decides>`. Nonfailable methods are `Count`, `MaxCount`, `Capacity`, `Clear`, and `HeapSnapshot`, where available. Invalid bounds/limits and empty access fail without modifying existing values. Errors are ordinary Verse failure; no partial replacement container escapes. Methods are synchronous and never yield.

Abstract heap sift-up/down makes O(log n) comparator calls, and bottom-up heapify uses O(n) comparator calls. **These are not claims about overall Verse operation time.** Heap push explicitly constructs an n+1-element array; pop constructs an n-1-element prefix. Immutable snapshots and local array writes may copy additional backing storage, including during each sift or helper call. Therefore overall push/pop is not advertised as O(log n), and heapify has no measured linear-time claim.

Ring end operations use a constant number of index calculations and slot changes when no growth occurs. Updating a Verse array value may still copy its capacity-sized backing storage, so end operations have no measured O(1) or amortized O(1) guarantee. Snapshot export traverses the logical contents; reserve/growth traverses the new capacity. Profile actual workloads before choosing large capacities or per-frame operation counts.

```verse
IntBefore(A:int, B:int)<computes><decides>:void = A < B

# Keep the new value explicitly. Earlier snapshots stay unchanged.
if (Empty := Queues.MakePriorityQueue[int, IntBefore]):
    if (One := Empty.Push[9], Two := One.Push[2], Removed := Two.Pop[]):
        Remaining := Removed(0)
        Value := Removed(1)
        Print("Removed {Value}; {Remaining.Count()} left")
```

Licensed under the repository [MIT License](../../LICENSE), copyright 2026 StormLabs. Original implementation; no third-party source was copied. The immutable generic API follows the public Verse value-container pattern; no unsafe casting or unsupported mutability workaround is used.
