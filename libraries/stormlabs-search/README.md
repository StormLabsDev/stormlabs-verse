# stormlabs-search

Generic native Verse binary search, under the repository-wide [MIT License](../../LICENSE).

## Public API

`Search.ordered_buffer(t)` provides exact-first search, lower/upper bounds, equal ranges and optional order validation. See [API.md](API.md) for constructor fields, exact effects and half-open index contracts.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

**Historical status: The earlier implementation compiled with zero diagnostics and passed five native test groups in UEFN. Performance remains unmeasured; no performance guarantee is implied.**

Follow the [root installation convention](../../README.md#installation): copy `src/stormlabs_search.verse` as `10_stormlabs_search.verse` into a Verse source folder, with application consumers later, for example `90_game.verse`. The canonical repository filename remains unchanged. It defines public module `Search` with no library dependencies. Outside consumers import the containing folder/module through their own project path.

## Generic contract: search-v1

`Search.ordered_buffer(t)` stores a caller-ordered immutable `Values:[]t` snapshot and `Less:type{_(:t, :t)<computes><decides>:void}`. This callback shape matches installed native `SortBy`: `Less[A, B]` succeeds exactly when A precedes B. `t` is unrestricted; the library never uses native equality or assumes integer/string keys. It can hold user classes and records.

The caller must supply values sorted by a consistent strict weak ordering. Comparator equivalence means neither value precedes the other; it need not be native equality. Class-valued elements remain shared references: do not change ordering-relevant fields while the holder is in use. The library does not sort or validate the ordering on construction.

| Method | Contract |
| --- | --- |
| `Count()` | Input length, with `<transacts>` effect |
| `Get[Index]` | Zero-based checked access, `<transacts><decides>` |
| `LowerBound[Value]` | First index whose element does not precede Value; `Count()` when all precede it, `<transacts><decides>` |
| `UpperBound[Value]` | First index whose element follows Value; `Count()` when none follow it, `<transacts><decides>` |
| `BinarySearch[Value]` | First comparator-equivalent match; ordinary failure if absent, `<transacts><decides>` |
| `EqualRange[Value]` | Tuple `(LowerBound, UpperBound)` for the half-open matching range; missing values produce `(insertion, insertion)`, `<transacts><decides>` |
| `ValidateOrder[]` | Optional linear scan that rejects any adjacent inversion, `<transacts><decides>` |

Search covers the half-open input range `[0, Count())` and returns insertion indices in `[0, Count()]`. Empty inputs yield zero. The implementation probes the holder's array directly, with logarithmic comparator calls and no per-probe whole-array argument, slicing or copy operation. Creating the holder retains an array value; no allocation-strategy or frame-time guarantee is made.

For duplicates, `BinarySearch` always returns the lower bound, including when distinct class objects are equivalent by the comparator. An empty input gives `(0, 0)` from `EqualRange` and failure from `BinarySearch`; a missing value between elements has the same insertion index for both range endpoints. All search methods are read-only and synchronous. Their failable effects support checked indexing and ordinary missing-match failure, not automatic enforcement of sorted-input preconditions.

`ValidateOrder` checks adjacent inversions only. Under the required strict weak order, that establishes sorted order; it cannot prove transitivity, irreflexivity, equivalence consistency, determinism or continued immutability of a caller's comparator/keys. Searches do not invoke this scan, because that would make every search linear. Invalid ordering violates the precondition and has no defined search-result guarantee.

```verse
BeforeInt(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Input := Search.ordered_buffer(int){Values := array{1, 3, 3, 7}, Less := BeforeInt}
if (Index := Input.LowerBound[3]):
    Print("First insertion index: {Index}")
```

The midpoint is computed as `Low + Quotient[High - Low, 2]`, keeping it inside the current half-open range without adding two potentially large endpoints. This package does not replace native stable `SortBy`; callers may use it to prepare the input with the same comparator.

This original StormLabs implementation is informed by the standard binary-search/lower-bound algorithms, without translated third-party implementation source.

On 2026-10-18 (UTC), local UEFN checks compiled unchanged implementation with zero diagnostics. The importing consumer passed five named groups with complete ordered BEGIN/END records: integer/string/user-class ordering, empty/duplicate boundaries, and descending-order/ownership behavior. Results were also compared with independent bisect fixtures.

Prepared geometric performance probes, including comparator-work replay and explicit order-validation scans, remain unrun. No timing, allocation or value-copy result is claimed.
