# Cache public API

## Overview

Generic immutable bounded LRU caching with strict weak ordering for arbitrary keys and independent value types. `Ordered` supplies both indexes. Install `00_stormlabs_ordered.verse` before `10_stormlabs_cache.verse` and application consumers such as `90_game.verse`.

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_cache.verse); declaration order is preserved in the implementation.

## Types and constructors

`Cache.lru_cache(key, value)` and `Cache.entry(key, value)` are public final parametric classes with internal constructors. Use `MakeLRUCache[key, value, Capacity, Less]`; entries are returned by eviction/snapshot and expose immutable public `Key:key` and `Value:value` fields. The cache exposes no public state fields. The pure failable comparator `Less:type{_(:key, :key)<computes><decides>:void}` must be a stable strict weak order; no native `comparable` constraint is required. There are no enums.

## Operations

The factory accepts capacity `0..2147483647` without eager allocation. Count/Capacity report metadata. `Peek[Key]` reads without changing recency; `Get[Key]` returns `(newCache, value)` with the hit most recent. `Put[Key, Value]` returns `(newCache, ?evictedEntry)`: replacement preserves the representative key, touches recency and evicts nothing; a new full-capacity insertion evicts exactly the previous LRU. Capacity zero is disabled and returns the supplied entry as immediately evicted. `Remove[Key]` returns `(newCache, oldValue)` without changing other recency. `Clear()` returns an empty cache with the same capacity/comparator. `Snapshot()` returns immutable entries MRU first. Exact public declarations follow.

```verse
Cache<public> := module:
    entry<public>(key:type, value:type) := class<internal><final>:
        Key<public>:key
        Value<public>:value
    lru_cache<public>(key:type, value:type) := class<internal><final>:
        Count<public>()<transacts>:int
        Capacity<public>()<transacts>:int
        Peek<public>(Key:key)<transacts><decides>:value
        Get<public>(Key:key)<transacts><decides>:tuple(lru_cache(key, value), value)
        Put<public>(Key:key, Value:value)<transacts><decides>:tuple(lru_cache(key, value), ?entry(key, value))
        Remove<public>(Key:key)<transacts><decides>:tuple(lru_cache(key, value), value)
        Clear<public>()<transacts>:lru_cache(key, value)
        Snapshot<public>()<transacts>:[]entry(key, value)
    MakeLRUCache<public>(key:type, value:type, Capacity:int, Less:type{_(:key, :key)<computes><decides>:void})<transacts><decides>:lru_cache(key, value)
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
ExampleLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

if (Empty := Cache.MakeLRUCache[int, string, 1, ExampleLess]):
    if (First := Empty.Put[1, "one"], Next := First(0).Put[2, "two"]):
        if (Evicted := Next(1)?):
            Print("Evicted {Evicted.Key}")
```

## Failure and cost notes

Missing Peek/Get/Remove and invalid factory capacities fail. Updates are immutable and failure-atomic; retain returned caches to change later recency/eviction. Old snapshots retain their structure. Keys/values, including class references inside snapshots and both indexes, are shallow; ordering-relevant fields and comparator behavior must remain stable. There is no implicit shared mutable cache, expiry or deep clone. Each resident has one live record in each ordered index, without stale recency accumulation. Ordinary lookup/update uses theoretical O(log n) tree work with path-copy allocation, not textbook O(1) LRU. Snapshot traverses O(n) entries without a lookup per result; actual array/copy/allocation costs are unmeasured. A reserved signed-max stamp triggers rare O(n log n) exact-order reindexing before increment, preserving representatives and old snapshots. Holding old caches retains shared structure according to runtime ownership. No frame-time promise is made.
