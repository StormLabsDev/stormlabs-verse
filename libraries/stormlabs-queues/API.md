# Queues public API

## Overview

Arbitrary-type immutable persistent stacks, comparator-driven heap priority queues, and ring deques. Updates return replacement containers and retain earlier snapshots. No library dependencies.

```verse
Queues<public> := module:
```

Import the module from your own project's Verse folder path. Use the [numbered installation layout](../../README.md#installation), keeping canonical repository filenames unchanged. Signature blocks below reproduce public declarations without function bodies; class construction marked `<internal>` is restricted to its module.

All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. Historical native evidence for the larger suites predates the namespace rename; those suites were not rerun. Performance is unmeasured. See the [library README](README.md) for the historical scope.

## Types and constructors

`stack(t:type)`, `priority_queue(t:type)` and `deque(t:type)` are final classes with module-only construction and no public state fields. There is no `comparable` constraint or required default element. Exact type declarations/methods appear in Operations. Factories and all overloads are:

```verse
MakeStack<public>(t:type, ?MaxCount:int = 2147483647)<transacts><decides>:stack(t)
MakePriorityQueue<public>(t:type, Before:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:priority_queue(t)
MakePriorityQueue<public>(t:type, Before:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:priority_queue(t)
Heapify<public>(t:type, Data:[]t, Before:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:priority_queue(t)
Heapify<public>(t:type, Data:[]t, Before:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:priority_queue(t)
MakeDeque<public>(t:type, ?InitialCapacity:int = 0, ?MaxCount:int = 2147483647)<transacts><decides>:deque(t)
DequeFromArray<public>(t:type, Data:[]t, ?InitialCapacity:int = 0, ?MaxCount:int = 2147483647)<transacts><decides>:deque(t)
```
All count/capacity limits are 0..2147483647, logical arithmetic bounds without an allocation promise. Default heap limit is 2147483647; explicit heap capacity is positional. Stack/deque factories retain named optional parameters. `Heapify` accepts an unsorted array, checks the limit and constructs a heap without sorting it. `DequeFromArray` preserves input order and takes capacity `max(Data.Length, InitialCapacity)`, within its limit.

## Operations

### stack(t)

```verse
stack<public>(t:type) := class<internal><final>:
    Count<public>()<transacts>:int
    MaxCount<public>()<transacts>:int
    Peek<public>()<transacts><decides>:t
    Push<public>(Value:t)<transacts><decides>:stack(t)
    Pop<public>()<transacts><decides>:tuple(stack(t), t)
    Clear<public>()<transacts>:stack(t)
    ToArray<public>()<transacts><decides>:[]t
```
`Push` adds the top and `Pop` removes it. `Peek`/`Pop` fail on empty. `ToArray` returns top-to-bottom order. `Clear` keeps the count limit. Nodes share immutable tails; old stacks remain valid.

### priority_queue(t)

```verse
priority_queue<public>(t:type) := class<internal><final>:
    Count<public>()<transacts>:int
    MaxCount<public>()<transacts>:int
    Peek<public>()<transacts><decides>:t
    HeapSnapshot<public>()<transacts>:[]t
    Clear<public>()<transacts>:priority_queue(t)
    Push<public>(Value:t)<transacts><decides>:priority_queue(t)
    Pop<public>()<transacts><decides>:tuple(priority_queue(t), t)
```
`Before` is a pure failable strict weak order: success means the left element has higher priority. Reverse it to select min/max ordering. Failure means the left does not precede the right, not a comparator error. Comparator laws/stable ordering-relevant fields are caller obligations. Equivalent priorities are explicitly unstable. `Peek`/`Pop` access highest priority and fail on empty. `HeapSnapshot` exports unsorted heap layout; `Clear` preserves comparator/limit.

### deque(t)

```verse
deque<public>(t:type) := class<internal><final>:
    Count<public>()<transacts>:int
    Capacity<public>()<transacts>:int
    MaxCount<public>()<transacts>:int
    Clear<public>()<transacts>:deque(t)
    Get<public>(Index:int)<transacts><decides>:t
    Front<public>()<transacts><decides>:t
    Back<public>()<transacts><decides>:t
    ToArray<public>()<transacts><decides>:[]t
    Reserve<public>(RequestedCapacity:int)<transacts><decides>:deque(t)
    PushBack<public>(Value:t)<transacts><decides>:deque(t)
    PushFront<public>(Value:t)<transacts><decides>:deque(t)
    PopFront<public>()<transacts><decides>:tuple(deque(t), t)
    PopBack<public>()<transacts><decides>:tuple(deque(t), t)
```
Logical order is front to back; indices are checked and zero-based. End accesses/removals fail on empty. A full ring grows to `min(MaxCount, max(4, 2 * old capacity))`; push at the limit fails without overwriting elements. Pops retain capacity. `Reserve` validates 0..MaxCount and only grows; `Clear` preserves capacity/limit. `ToArray` exports logical order.

## Examples

```verse
QueueBefore(A:int, B:int)<computes><decides>:void = A < B

CheckQueuesExample()<transacts><decides>:void =
    Heap := Queues.Heapify[int, array{9, 2, 5}, QueueBefore, 8]
    Removed := Heap.Pop[]
    Removed(1) = 2
    Heap.Count() = 3
    Removed(0).Count() = 2
    Empty := Queues.MakeStack[logic]
    One := Empty.Push[false]
    Value := One.Pop[]
    not Value(1)?
    Empty.Count() = 0
    Value(0).Count() = 0
    Ring := Queues.MakeDeque[string, ?InitialCapacity := 2]
    Tail := Ring.PushBack["tail"]
    Both := Tail.PushFront["head"]
    Both.ToArray[] = array{"head", "tail"}
```

## Failure and cost notes

Every operation has `<transacts>`; declarations with `<decides>` use square brackets in a failure context. Factory/capacity errors, full push, empty access/removal, invalid deque index/reserve, and input arrays above limits fail with no replacement value. Failures preserve original snapshots. A false or empty optional payload remains a valid element; it is not an empty-container signal. `Pop` returns `(updated container, removed value)`, in that order.

Retain every returned replacement you intend to use. Element references are shallow; exported class elements still refer to the same objects. There is no deep clone or automatic element disposal. Stack export is iterative.

Stack push/pop use a constant abstract number of linked-node/wrapper operations and share tails, without an array copy; allocation/GC timing is unmeasured. Heap sifts make O(log n) comparisons and bottom-up heapify makes O(n) comparisons. Heap push/pop explicitly copy growing/shrinking arrays; draining an n-element heap copies n(n-1)/2 prefix elements before accounting for further sift/backing-store costs. Overall push/pop is not advertised as O(log n). Ring end operations use a constant number of index/slot calculations, but Verse array updates may copy capacity-sized storage. Growth/reserve/clear allocate or traverse storage. No native O(1)/amortized O(1), timing, memory, or frame-budget promise is made. Methods never yield.
