# stormlabs-cache

Generic immutable bounded LRU caches for Verse, under the repository-wide [MIT License](../../LICENSE).

## Public API

`Cache.MakeLRUCache` creates immutable generic LRU values with Peek/Get, Put/eviction, Remove, Clear and MRU snapshots. See [API.md](API.md) for complete types, exact effects, capacity-zero and ownership behavior.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

**Historical status: native correctness checks passed for the earlier Cache source and Ordered provider described below. Experimental; native performance is unmeasured.**

Copy the canonical source files into the same Verse source folder using these installed names:

| Canonical source | Installed filename |
| --- | --- |
| `../stormlabs-ordered/src/stormlabs_ordered.verse` | `00_stormlabs_ordered.verse` |
| `src/stormlabs_cache.verse` | `10_stormlabs_cache.verse` |

Keep application files that instantiate these generic APIs after the library files in filename order, for example `90_game.verse`. Preserve the numeric prefixes when copying; install each public module once. Repository source filenames remain canonical. The modules and calls remain `Ordered` and `Cache`, independent of the installed filenames.

This convention addresses observed cross-file definition-order sensitivity in UEFN 42.40, CL 59247843. Earlier application filenames caused compiler errors with identical source bytes; an explicit dependency import did not resolve them, and a library-only bundle still failed when its importing consumer sorted first. Filename ordering is a limitation observed in this tested toolchain, not a Verse language guarantee. Recheck compilation after changing the layout or toolchain.

Use matching Ordered source from the same repository snapshot. No crypto, hashing, bitset, encoding, device or test dependency is introduced.

## Generic contract: cache-v1

`MakeLRUCache[key, value, Capacity, Less]` creates `lru_cache(key, value)` for arbitrary key and value types, with no `comparable` restriction. `Less:type{_(:key, :key)<computes><decides>:void}` must be a consistent strict weak order. Keys are equivalent when neither direction precedes the other. Keep ordering-relevant key fields and comparator behavior stable while any snapshot using them remains live.

Capacity is fixed, validated in `0..2147483647`, and does not cause eager preallocation. This arithmetic bound is not an allocation or execution-budget promise. Zero capacity is a valid disabled cache: every put returns an empty cache and the supplied entry as immediately evicted.

| Method | Contract | Effects |
| --- | --- | --- |
| `Count()` | Number of resident equivalent-key classes | `<transacts>` |
| `Capacity()` | Fixed maximum resident count | `<transacts>` |
| `Peek[Key]` | Return value without touching recency; fail on miss | `<transacts><decides>` |
| `Get[Key]` | Touch the hit as most recently used and return `(newCache, value)`; fail on miss | `<transacts><decides>` |
| `Put[Key, Value]` | Return `(newCache, ?evictedEntry)` | `<transacts><decides>` |
| `Remove[Key]` | Return `(newCache, removedValue)`; fail on miss, without touching other residents | `<transacts><decides>` |
| `Clear()` | Return an empty cache with the same capacity and ordering | `<transacts>` |
| `Snapshot()` | Return immutable entries ordered most recently used to least recently used | `<transacts>` |

Every successful update returns a new cache value and leaves old cache structures unchanged. Replacing an equivalent key updates its value, retains the original stored representative key and makes it most recently used, without eviction. A new insertion at full capacity evicts exactly the least recently used entry. Eviction entries expose immutable public `Key` and `Value` fields. Keys and values are shallow: class instances may remain shared references; no deep copy is promised.

`Get` changes recency only in the returned cache. `Peek`, `Snapshot`, misses and old snapshots retain their recency. Keep the returned cache from `Get` or `Put` when that operation should affect subsequent eviction. A replacement does not return the old value through its eviction option; use `Peek` before replacing if that value is needed. Removal returns the prior value but is not an eviction. Clearing resets the internal recency counter.

The implementation uses two immutable ordered maps: key to `(value, recency stamp)`, and stamp to `(representative key, value)`. Each resident has exactly one record in each index. Built-in tuples avoid passing a locally defined generic record type as the provider's mapped value; the tuple composition passed separate importing-consumer compiler probes. No stale recency records accumulate, and the package does not implement another tree or hash table. Normal lookup/update work is theoretically `O(log n)` ordered-map operations, with path-copy allocation inherited from the provider; native Verse costs are unmeasured. This is not a textbook `O(1)` linked-list/hash-table implementation.

Metadata reads use constant work. Snapshot traversal visits all resident order nodes and materializes an array of immutable entry wrappers; it does not perform a key-map lookup per result. Public keys and values remain shallow, including when copied into both tuples. The provider's array-allocation/copying cost and caller comparator cost remain relevant, so this is not a measured linear-time or execution-budget claim. Holding many old cache values or snapshots keeps their structurally shared data and referenced objects alive according to runtime ownership.

Stamps increase from zero. `9223372036854775807` is reserved as a rebase trigger, never incremented. At exhaustion, both indexes are rebuilt in exact least-to-most-recent order using dense `0..Count()-1` stamps before the next recency-changing operation. The resident-count cap leaves headroom after rebasing. Rebase work is `O(n log n)` map insertion work and preserves all old snapshots and representative keys. Nothing silently wraps or drops entries.

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

if (Empty := Cache.MakeLRUCache[int, string, 2, IntLess]):
    if (First := Empty.Put[7, "seven"], Second := First(0).Put[9, "nine"]):
        if (Touched := Second(0).Get[7], Next := Touched(0).Put[11, "eleven"]):
            if (Evicted := Next(1)?):
                Print("Evicted {Evicted.Key}") # 9; Get made 7 most recent.
```

All operations are synchronous. Failure returns no new cache, and immutable inputs remain unchanged. There is no implicit shared mutable cache instance, persistence, expiry policy, thread-safety promise, deep clone, or native performance result.

This original StormLabs implementation uses the standard LRU policy and the existing Ordered provider, without copied third-party implementation source.

On 2026-10-18 UTC, Cache and its Ordered dependency compiled and passed all six native test groups. These cover differing integer/string key-value types, user classes and equivalent-key representatives, recency/eviction, removal/disabled capacity/misses, immutable snapshots, and forced counter rebasing. Two targeted constructor/internal-state access controls produced the intended access diagnostics, and restoring the positive consumer compiled cleanly. The runtime checks used provider-before-consumer filenames.

The same library bytes also compiled in a combined twelve-library snapshot under the numbered names above, with an application consumer after the libraries. The full Cache consumer and its unchanged test-only bridge separately compiled in that numbered layout, followed by a clean restored compile. This additional numbered-layout compilation did not rerun that six-group suite. Host reference traces supplement native checks. Performance probes are prepared but unrun; the correctness results provide no timing, allocation, cross-VM compatibility or execution-budget guarantee.
