# DisjointSet public API

## Overview

Generic immutable union-find with union by size and actual full path compression. Requires the matching `Ordered` module from this repository revision.

```verse
DisjointSet<public> := module:
```

Import the module from your own project's Verse folder path. Use the [numbered installation layout](../../README.md#installation), keeping canonical repository filenames unchanged. Signature blocks below reproduce public declarations without function bodies; class construction marked `<internal>` is restricted to its module.

All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. Historical native evidence for the larger suites predates the namespace rename; those suites were not rerun. Performance is unmeasured. See the [library README](README.md) for the historical scope.

## Types and constructors

`disjoint_set(t:type)` is a final class with module-only construction and no public state fields. It accepts arbitrary values through a pure failable strict weak ordering, without a `comparable` or hash requirement. Its exact type/method declarations appear below.

```verse
MakeDisjointSet<public>(t:type, Less:type{_(:t, :t)<computes><decides>:void})<transacts><decides>:disjoint_set(t)
MakeDisjointSet<public>(t:type, Less:type{_(:t, :t)<computes><decides>:void}, MaxCount:int)<transacts><decides>:disjoint_set(t)
```
These are default-arity and positional-capacity overloads. The default limit is 2147483647; explicit limits are checked in 0..2147483647. Two values are equivalent when neither precedes the other. Ordering-relevant fields must remain stable for the container's lifetime. An equivalent duplicate preserves the first inserted canonical value/object, even at the count limit. A new value at the limit fails.

## Operations

```verse
disjoint_set<public>(t:type) := class<internal><final>:
    Count<public>()<computes>:int
    ComponentCount<public>()<computes>:int
    MaxCount<public>()<computes>:int
    Contains<public>(Value:t)<transacts><decides>:void
    Clear<public>()<transacts>:disjoint_set(t)
    Elements<public>()<transacts>:[]t
    Add<public>(Value:t)<transacts><decides>:disjoint_set(t)
    Find<public>(Value:t)<transacts><decides>:tuple(disjoint_set(t), t)
    ComponentSize<public>(Value:t)<transacts><decides>:tuple(disjoint_set(t), int)
    Connected<public>(A:t, B:t)<transacts><decides>:tuple(disjoint_set(t), logic)
    Union<public>(A:t, B:t)<transacts><decides>:disjoint_set(t)
```
| Operation | Contract |
| --- | --- |
| `Count`, `ComponentCount`, `MaxCount` | Element count, component count, configured logical limit |
| `Contains` | Succeed exactly when an equivalent value is present |
| `Add` | New singleton for a new value; equivalent duplicate is idempotent |
| `Find` | `(updated set, representative)`; require existing element |
| `ComponentSize` | `(updated set, size)`; require existing element |
| `Connected` | `(updated set, logic)`; false is successful for separate existing components |
| `Union` | Return updated set joining two existing components |
| `Clear` | Empty snapshot preserving comparator/limit |
| `Elements` | Shallow array in first-insertion order |

No operation inserts values implicitly. Union attaches the smaller component to the larger; equal sizes retain the root with the lower first-insertion index, independent of argument order. Representatives are the winning root's original value/object and can change after a later larger-component union. Self/repeated unions succeed without changing membership or counts.

Search follows the parent chain and redirects every traversed non-root directly to that search's root in the returned set. Connected/Union thread successive returned sets through their two searches. Union can subsequently attach a searched root to another root, leaving an ordinary two-link path until future compression. Discarding a returned set discards its compression.

## Examples

```verse
SetBefore(A:int, B:int)<computes><decides>:void = A < B

CheckDisjointSetExample()<transacts><decides>:void =
    Empty := DisjointSet.MakeDisjointSet[int, SetBefore, 4]
    One := Empty.Add[10]
    Two := One.Add[20]
    Joined := Two.Union[10, 20]
    Located := Joined.Find[20]
    Located(1) = 10
    Compressed := Located(0)
    Sized := Compressed.ComponentSize[10]
    Sized(1) = 2
    Two.ComponentCount() = 2
    Joined.ComponentCount() = 1
```

## Failure and cost notes

The three immutable count getters have `<computes>` and use parentheses. Clear/Elements have `<transacts>` and also use parentheses. All other public operations and constructors have `<transacts><decides>`; use square brackets in a failure context. Missing Find/size/union/connectivity arguments, invalid limits, or new insertion at the limit fail without changing any earlier snapshot. False connectivity is a successful payload, not failure.

Retain replacement values from updates and compressing queries. Element references and Elements exports are shallow; old versions preserve structure but do not deep-clone payload objects. No removal, split, serialization or concurrent-mutation API exists.

The element index and parent metadata are two persistent ordered maps; primary lookup does not linearly scan elements or clone a parent array. Add performs a constant number of O(log n) abstract ordered-tree operations with path copying. A path of h links uses O((h + 1) log n) abstract map work and can construct O(h log n) replacement tree nodes. Union performs two such searches plus a constant number of map operations. Union by size bounds uncompressed parent height by O(log n); retained compressed versions shorten later traversals. This is not an inverse-Ackermann whole-operation or native allocation/time claim. Comparator cost, repeated ordered lookups, snapshot retention, array export assembly, and runtime GC add costs. No operation yields and the logical limit does not promise maximum-sized allocations.
