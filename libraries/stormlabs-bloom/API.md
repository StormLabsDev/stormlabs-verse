# Bloom public API

## Overview

Generic insertion-only Bloom membership filters with caller-supplied hashing. The backing bitset belongs to `Bits`. Install `00_stormlabs_bits.verse` before `10_stormlabs_bloom.verse` and later application consumers such as `90_game.verse`.

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_bloom.verse); declaration order is preserved in the implementation.

## Types and constructors

`Bloom.bloom_filter(t)` is public and final, but its constructor is internal and it has no public fields. Create it only with `MakeBloomFilter[t, BitCount, HashCount, Hash]`. `t` is unrestricted. `Hash:type{_(:t, :int)<computes>:int}` receives `(Value, ProbeIndex)` for indices `0..HashCount-1`. No enums are exposed.

## Operations

The factory validates `1..2147483647` bits and `1..32` probes before allocation. `BitCount`/`HashCount` report the configured parameters. `Insert[Value]` sets all positions atomically. `MightContain[Value]` succeeds for possibly present and fails for definitely absent. `Clear()` clears all bits without changing parameters/hash. `Clone()` returns independent mutable bit storage with the same immutable hash function. Exact declarations follow.

```verse
Bloom<public> := module:
    bloom_filter<public>(t:type) := class<internal><final>:
        BitCount<public>()<transacts>:int
        HashCount<public>()<transacts>:int
        Insert<public>(Value:t)<transacts><decides>:void
        MightContain<public>(Value:t)<transacts><decides>:void
        Clear<public>()<transacts>:void
        Clone<public>()<transacts>:bloom_filter(t)
    MakeBloomFilter<public>(t:type, BitCount:int, HashCount:int, Hash:type{_(:t, :int)<computes>:int})<transacts><decides>:bloom_filter(t)
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
ExampleHash(Value:int, Probe:int)<computes>:int =
    BitXor(Value, Probe)

if (Filter := Bloom.MakeBloomFilter[int, 128, 3, ExampleHash]):
    if (Filter.Insert[42]):
        if (Filter.MightContain[42]):
            Print("42 may be present")
```

## Failure and cost notes

All signed hash results, including the minimum integer, are normalized with positive-denominator Mod, without Abs. Hashing must be deterministic and consistent for the same logical value and probe. Do not mutate hash-relevant key fields after insertion. Consistent hashing guarantees no false negatives for successfully inserted values until Clear; positive queries can be false positives. This is not an exact set or security mechanism. No distinct-item count, insertion cap or automatic sizing API exists. Standard false-positive estimates assume independent uniformly distributed positions, which arbitrary callbacks need not satisfy. Instances require one logical owner: assigning the filter reference aliases mutable storage. Clone isolates bits but shares immutable configuration. Failed transactional inserts roll back; negating a successful insert also rolls it back, so use a positive branch. Insert/query cost is bounded by probe count; clone/clear scale with bit storage. Capacity bounds do not promise feasible allocation, frame time or native performance. The example demonstrates callback wiring, not hash-quality guidance.
