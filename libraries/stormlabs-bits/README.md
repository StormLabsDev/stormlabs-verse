# stormlabs-bits

## Public API overview

Mutable fixed/growable packed bitsets, range/search/set operations, and checked byte serialization with out-of-band length. See the [complete public API](API.md) for exact signatures, effects, overloads, and examples.

**Validation status:** All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. The larger native suites reported below are historical results from before the namespace rename; they were not rerun for this revision. Performance remains unmeasured.

Packed native Verse fixed and growable bitsets.

The earlier implementation compiled without diagnostics and passed the combined Binary/Bits suite's 107 named groups in UEFN 42.40, CL 59247843. The complete log matched the exact source and run identities. Separate compile controls rejected all ten intended constructor/state accesses across both modules; positive compilation succeeded before and after those controls. The Verse VM variant was not identified. Performance remains unmeasured; these bounded results do not establish correctness for every input or a frame-budget guarantee.

## Installation and storage

Follow the [root numbered installation layout](../../README.md#installation): copy `src/stormlabs_bits.verse` into your project's Verse source folder as `00_stormlabs_bits.verse`, with consuming application files after the installed libraries, for example `90_game.verse`. Keep the repository's canonical source filename unchanged. It defines `Bits`, with no specialized-library dependency or test imports. Outside consumers import it from their own project's Verse path. Encoding adapters belong above its byte API.

`MakeFixedBitset[Length]` and `MakeGrowableBitset[Length]` create all-zero sets. Logical length is 0..2147483647 bits, subject to available memory and execution budget. The cap is an API arithmetic bound, not an allocation or frame-time promise. Private storage packs 32 bits per bounded unsigned word: bit `i` uses bit `i % 32` in word `floor(i/32)`. Unused high bits in the final storage word are always zero.

`fixed_bitset` has no resize operation. `growable_bitset.Resize[Length]` preserves the retained prefix and fills newly exposed bits with zero. Shrinking discards the removed bits permanently; regrowing cannot recover them. `AppendBit[Value]` grows by one and accepts only 0 or 1. Setting a bit beyond the current length always fails; growth is explicit.

## Shared operations

Both types provide the following methods:

| Operation | Contract |
| --- | --- |
| `Count()` | Logical bit length, not population count or capacity |
| `Get[Index]` | Integer 0 or 1; failure means invalid index |
| `Set[Index, Value]` | Zero-based checked index; value must be 0 or 1 |
| `SetRange[Start, Stop, Value]` | Set the **zero-based half-open range `[Start, Stop)`**; empty ranges including at the end are valid |
| `FlipRange[Start, Stop]` | Flip that half-open range without touching trailing storage bits |
| `Clear()` | Clear all bits without changing logical length |
| `PopulationCount()` | Number of set logical bits |
| `FindFirstSet[Start]`, `FindFirstClear[Start]` | First matching index at or after inclusive `Start`; `Start` may equal `Count()`; absence or invalid start fails |
| `Clone()` | Independent mutable copy with the same type and length |
| `Complement[]` | Independent inverted copy; unused trailing bits stay zero |
| `Union[Other]`, `Intersect[Other]`, `Xor[Other]`, `Difference[Other]` | New set of the same type; **unequal lengths fail**; neither input is mutated; difference means this set minus `Other` |
| `ToBytes[]` | Exact serialization described below |

Binary operations require the same public type. `fixed_bitset.ToGrowable()` and `growable_bitset.ToFixed()` return independent copies for cross-type use. Copies are independent owners, while assigning a class reference to another variable creates an alias that shares mutations. No operation promises a particular allocation strategy.

## Byte serialization

**The logical bit length is out-of-band.** An enclosing format must retain it. `ToBytes[]` emits exactly `ceil(Count()/8)` integer bytes in 0..255, with byte zero containing bits 0..7 and bit zero at that byte's least significant position. Successive bytes represent increasing bit indices. Unused high bits in the final byte are zero. The empty set emits an empty array.

For example, a 33-bit set with bits 0, 31, and 32 set emits `[1, 0, 0, 128, 1]`. This is a bit order contract, not a text encoding. It is equivalent to serializing each packed word little-endian and omitting bytes outside the logical length.

`FixedBitsetFromBytes[Length, Data]` and `GrowableBitsetFromBytes[Length, Data]` require exactly `ceil(Length/8)` bytes, validate **every** byte, and reject nonzero unused high bits in the last byte. They reject extra bytes, truncated input, and invalid byte values without masking. Returned sets own independent mutable state. There is no implicit wire header or version field.

## Effects and execution

All public functions and methods have `<transacts>`. Checked operations, searches, set algebra, serialization, complement, factories, and deserializers additionally have `<decides>`. `Count`, `PopulationCount`, `Clear`, `Clone`, and conversions are nonfailable. Failure rolls back mutations, including failures in an enclosing transaction. Errors are ordinary Verse failure; `Get` returns 0 for an unset valid bit rather than confusing that case with invalid input.

Each mutable set needs a single logical owner. Methods are synchronous and never yield; no locks, concurrent-mutation guarantee, or execution-budget guarantee is provided. Set/range operations use packed words, population count removes one set bit per iteration, and searches skip words with no matching bits. Resizing copies word storage; appending repeatedly is intended for bounded workloads until profiling justifies another allocation strategy.

```verse
if (Bitset := Bits.MakeGrowableBitset[33]):
    if (Bitset.Set[0, 1], Bitset.Set[32, 1], Bytes := Bitset.ToBytes[]):
        if (Copy := Bits.FixedBitsetFromBytes[33, Bytes]):
            Print("Set bits: {Copy.PopulationCount()}")
```

Licensed under the repository [MIT License](../../LICENSE), copyright 2026 StormLabs. This is original implementation code; no external implementation was copied.
