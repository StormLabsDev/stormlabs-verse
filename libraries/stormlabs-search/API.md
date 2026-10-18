# Search public API

## Overview

Generic binary search over a caller-ordered immutable holder. The module has no library dependency. Install `10_stormlabs_search.verse` before application consumers such as `90_game.verse`.

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_search.verse); declaration order is preserved in the implementation.

## Types and constructors

`Search.ordered_buffer(t)` is a public final parametric class with a public constructor and immutable public fields `Values:[]t` and `Less:type{_(:t, :t)<computes><decides>:void}`. Construct the holder directly; there is no validating factory. `t` is unrestricted, with no `comparable` requirement. `Less[A, B]` succeeds exactly when A precedes B. There are no enums.

## Operations

`Count()` returns length; `Get[Index]` performs checked zero-based access. `LowerBound[Value]` returns the first element not preceding Value, and `UpperBound[Value]` the first element following Value. Bounds are insertion indices in `0..Count()`, including EOF. `BinarySearch[Value]` returns the first comparator-equivalent match and fails when absent. `EqualRange[Value]` returns `(lower, upper)` for a half-open match range; a miss yields `(insertion, insertion)`. Empty inputs give bounds/range zero and exact-search failure. Equivalence means neither comparison succeeds. `ValidateOrder[]` explicitly scans for adjacent inversions; lookups do not call it. The following inventory lists all declarations exactly, with function bodies omitted.

```verse
Search<public> := module:
    ordered_buffer<public>(t:type) := class<final>:
        Values<public>:[]t
        Less<public>:type{_(:t, :t)<computes><decides>:void}
        Count<public>()<transacts>:int
        Get<public>(Index:int)<transacts><decides>:t
        LowerBound<public>(Value:t)<transacts><decides>:int
        UpperBound<public>(Value:t)<transacts><decides>:int
        BinarySearch<public>(Value:t)<transacts><decides>:int
        EqualRange<public>(Value:t)<transacts><decides>:tuple(int, int)
        ValidateOrder<public>()<transacts><decides>:void
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
ExampleLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Input := Search.ordered_buffer(int){Values := array{1, 3, 3, 7}, Less := ExampleLess}
if (Range := Input.EqualRange[3]):
    Print("Range [{Range(0)}, {Range(1)})")
```

## Failure and cost notes

The caller must maintain sorted input and a consistent strict weak ordering. Mutating ordering-relevant fields of class-valued elements breaks the precondition; references are shallow. Invalid ordering has no defined search-result guarantee. `ValidateOrder` cannot prove comparator transitivity or stability. Checked indexing/quotient failures propagate; failed exact search is an ordinary miss. Lookups use logarithmic probes/comparator calls without an explicit whole-array copy per probe. `Count` and `Get` use constant work; `ValidateOrder` is a separate linear scan. Holder construction/runtime value-copy cost is unmeasured. This library does not replace native stable `SortBy`.
