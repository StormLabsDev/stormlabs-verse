# stormlabs-disjoint-set

## Public API overview

Generic immutable union-find with caller ordering, union by size, full path compression, and component queries. See the [complete public API](API.md) for exact signatures, effects, overloads, and examples.

**Validation status:** All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. The larger native suites reported below are historical results from before the namespace rename; they were not rerun for this revision. Performance remains unmeasured.

Generic immutable native Verse union-find with union by size and full path compression.

The earlier implementation compiled without diagnostics and passed 17 named native check groups in the local UEFN host, covering generic types, independent partition traces, deterministic representatives, component sizes, full path compression, bounds, and retained snapshots. The complete log matched the exact source, dependency, and run identities; deployed provider/wrapper hashes matched the selected files before and after runtime. Separate compile controls rejected all six intended constructor/state/private-method accesses, with clean positive compilation before and after the controls. The numbered installation below compiled in a combined twelve-library layout and with the full UF consumer; runtime checks used the earlier provider-before-consumer diagnostic filenames. The Verse VM variant was not recorded. Performance remains unmeasured, and these bounded checks do not establish correctness for every type/input or a frame-budget guarantee.

Copy `src/stormlabs_disjoint_set.verse` and the required `stormlabs_ordered.verse` into the same Verse source folder, using dependency-before-application names for the installed copies:

1. `00_stormlabs_ordered.verse`
2. `10_stormlabs_disjoint_set.verse`
3. Consuming application files after every installed library, for example `90_game.verse`.

Keep the repository's canonical source filenames unchanged. The module remains `DisjointSet`; outside consumers import it through their own project's folder path. No bundler or renamed public module is required. Required dependency: the matching `Ordered` source from this repository revision. No dependency source is copied into this library.

Native compilation has exposed sensitivity to the processing order of provider, dependent, and generic consumer source files. The tested numbered copies are a current-compiler compatibility convention, not a language guarantee of inter-file processing order. Arbitrary filenames or import statements are not established substitutes. Recheck the layout after compiler upgrades or changes to consuming files.

`MakeDisjointSet[t, Less]` and `MakeDisjointSet[t, Less, MaxCount]` support arbitrary element types through a pure failable strict weak order, `type{_(:t, :t)<computes><decides>:void}`. Two values are equivalent when neither precedes the other. Ordering-relevant fields must stay stable after insertion. No `comparable` constraint, hash function, linear equality scan, or per-type implementation is required. The two constructor forms are overloads: omitted capacity uses 2147483647; an explicit capacity is positional, not `?MaxCount := ...`.

Containers are immutable values: retain the replacement returned by an update or query to retain its new structure and compression. Existing aliases preserve their structure. Element copies are shallow; class elements remain references to the same objects. Stable ordering does not make unrelated mutable payload fields independent. There is no deep clone, serialization, removal, split, concurrent mutation, or iterator framework.

| Operation | Contract |
| --- | --- |
| `MakeDisjointSet[t, Less]` | New empty set with logical element limit 2147483647 |
| `MakeDisjointSet[t, Less, MaxCount]` | New empty set with checked positional element limit |
| `Count()`, `ComponentCount()`, `MaxCount()` | Element count, component count, and logical limit |
| `Contains[Value]` | Succeeds exactly when an equivalent element is present |
| `Add[Value]` | New singleton for a new element; idempotent for an existing equivalent element |
| `Find[Value]` | `(updated set, representative value)`; requires a present element |
| `Union[A, B]` | Updated set joining two existing components; missing elements fail |
| `Connected[A, B]` | `(updated set, logic)`; false is a successful result for separate existing components |
| `ComponentSize[Value]` | `(updated set, size)`; missing elements fail |
| `Clear()` | Empty snapshot retaining comparator and limit |
| `Elements()` | Shallow array snapshot in first-insertion order |

An equivalent duplicate add retains the first inserted value/object and succeeds even at the count limit. A new element at the limit fails. Limits are 0..2147483647, an API arithmetic bound without a maximum-allocation or frame-budget promise. No method inserts an element implicitly during a query or union.

`Find`, `ComponentSize`, and both searches in `Connected` and `Union` follow parent links, then perform **full path compression** in the returned set: every node traversed on each search points directly to that search's root. Searches are threaded through successive returned values. A union may subsequently attach one of those roots to the winner; a path compressed before the join can therefore become two links long. This is ordinary union followed by future compression, not a promise that every node is always directly attached to the latest root. Discarding the returned value discards compression.

Union attaches the smaller component's root to the larger component's root. Equal sizes retain the root with the lower first-insertion index, independent of argument order. The winner's original value/object remains the representative; a later unequal-size union can change a component's representative. A self union or repeated union succeeds, preserves counts and membership, and can return compressed paths. Root nodes store the component size; non-root size metadata is zero.

Two persistent ordered maps provide the element-to-insertion-index lookup and index-to-node storage. Each node entry is a tuple `(canonical value, parent insertion index, root size)`; payloads retain their arbitrary generic type, while parent indices and sizes use exact integers. There is no primary linear element search or whole parent-array copy. Add uses a constant number of ordered-map operations, each with O(log n) abstract tree work and path-copy node construction. For path height `h`, a search performs O((h + 1) log n) abstract ordered-map lookup/update work and can construct O(h log n) replacement map nodes. Union performs two such searches and a constant number of further map operations. Union by size bounds the uncompressed parent height by O(log n); path compression reduces future parent traversals when returned values are retained.

These are algorithmic bounds under the ordered-map invariant, **not** measured Verse timings, native allocation bounds, or an inverse-Ackermann whole-operation claim. Comparisons of caller values have their own cost. A warm direct-root search still needs ordered lookups and a replacement set wrapper. Keeping prior snapshots retains shared map nodes, payloads, and uncompressed old paths; garbage collection is runtime dependent. `Elements` traverses the insertion-index map and builds an array; the provider's array assembly can copy additional storage. No method yields internally.

Public immutable count getters have `<computes>`. `Clear` and `Elements` have `<transacts>`. The factory, membership check, add, find, union, connectivity, and size queries have `<transacts><decides>`. Failure provides no replacement value and preserves original snapshots, including if one argument exists and the other is missing. A successful false connectivity payload must not be mistaken for operation failure.

```verse
IntLess(A:int, B:int)<computes><decides>:void = A < B

if (Empty := DisjointSet.MakeDisjointSet[int, IntLess]):
    if (One := Empty.Add[10], Two := One.Add[20], Joined := Two.Union[10, 20]):
        if (Located := Joined.Find[20]):
            Compressed := Located(0)
            Representative := Located(1)
```

Licensed under the repository [MIT License](../../LICENSE), copyright 2026 StormLabs. Original implementation; no external implementation source was copied.
