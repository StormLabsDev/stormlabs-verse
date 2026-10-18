# Bits public API

## Overview

Mutable packed fixed/growable bitsets with checked ranges, searches, set algebra, independent copies, and byte serialization. No library dependencies.

```verse
Bits<public> := module:
```

Import the module from your own project's Verse folder path. Use the [numbered installation layout](../../README.md#installation), keeping canonical repository filenames unchanged. Signature blocks below reproduce public declarations without function bodies; class construction marked `<internal>` is restricted to its module.

All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. Historical native evidence for the larger suites predates the namespace rename; those suites were not rerun. Performance is unmeasured. See the [library README](README.md) for the historical scope.

## Types and constructors

`fixed_bitset` keeps its original logical length; `growable_bitset` supports explicit resizing and appending. Both are final mutable classes with module-only construction and no public state fields. Their exact declarations/methods appear below.

```verse
MakeFixedBitset<public>(Length:int)<transacts><decides>:fixed_bitset
MakeGrowableBitset<public>(Length:int)<transacts><decides>:growable_bitset
FixedBitsetFromBytes<public>(Length:int, Data:[]int)<transacts><decides>:fixed_bitset
GrowableBitsetFromBytes<public>(Length:int, Data:[]int)<transacts><decides>:growable_bitset
```
Make factories produce all-zero sets. Length is checked in 0..2147483647 bits, a logical bound rather than a maximum-allocation promise. Byte factories require exactly `ceil(Length/8)` bytes, each0..255, and reject nonzero unused high bits in the final byte. The logical bit length is out-of-band; no header or version field is inserted.

## Operations

### fixed_bitset

```verse
fixed_bitset<public> := class<internal><final>:
    Count<public>()<transacts>:int
    Get<public>(Index:int)<transacts><decides>:int
    Set<public>(Index:int, Value:int)<transacts><decides>:void
    SetRange<public>(Start:int, Stop:int, Value:int)<transacts><decides>:void
    FlipRange<public>(Start:int, Stop:int)<transacts><decides>:void
    PopulationCount<public>()<transacts>:int
    Clear<public>()<transacts>:void
    FindFirstSet<public>(Start:int)<transacts><decides>:int
    FindFirstClear<public>(Start:int)<transacts><decides>:int
    Clone<public>()<transacts>:fixed_bitset
    Complement<public>()<transacts><decides>:fixed_bitset
    ToGrowable<public>()<transacts>:growable_bitset
    Union<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset
    Intersect<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset
    Xor<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset
    Difference<public>(Other:fixed_bitset)<transacts><decides>:fixed_bitset
    ToBytes<public>()<transacts><decides>:[]int
```
### growable_bitset

```verse
growable_bitset<public> := class<internal><final>:
    Count<public>()<transacts>:int
    Get<public>(Index:int)<transacts><decides>:int
    Set<public>(Index:int, Value:int)<transacts><decides>:void
    SetRange<public>(Start:int, Stop:int, Value:int)<transacts><decides>:void
    FlipRange<public>(Start:int, Stop:int)<transacts><decides>:void
    Resize<public>(Length:int)<transacts><decides>:void
    AppendBit<public>(Value:int)<transacts><decides>:void
    PopulationCount<public>()<transacts>:int
    Clear<public>()<transacts>:void
    FindFirstSet<public>(Start:int)<transacts><decides>:int
    FindFirstClear<public>(Start:int)<transacts><decides>:int
    Clone<public>()<transacts>:growable_bitset
    Complement<public>()<transacts><decides>:growable_bitset
    ToFixed<public>()<transacts>:fixed_bitset
    Union<public>(Other:growable_bitset)<transacts><decides>:growable_bitset
    Intersect<public>(Other:growable_bitset)<transacts><decides>:growable_bitset
    Xor<public>(Other:growable_bitset)<transacts><decides>:growable_bitset
    Difference<public>(Other:growable_bitset)<transacts><decides>:growable_bitset
    ToBytes<public>()<transacts><decides>:[]int
```
| Operation | Behavior |
| --- | --- |
| `Count`, `PopulationCount` | Logical length and number of set bits, respectively |
| `Get`, `Set` | Checked zero-based index; bit values are exactly 0 or 1 |
| `SetRange`, `FlipRange` | Half-open `[Start, Stop)`; empty end range is valid |
| `FindFirstSet`, `FindFirstClear` | Inclusive `Start`, allowed through `Count()`; fail if absent |
| `Clear` | Set every bit to zero while retaining length |
| `Clone`, `Complement` | Independent mutable copy, identical/inverted bits |
| `ToGrowable`, `ToFixed` | Independent copy with the other public type |
| `Union`, `Intersect`, `Xor`, `Difference` | New owner of the same type; equal lengths required; difference is this set minus other |
| `Resize` | Preserve prefix, discard shrink suffix permanently, fill growth with zero |
| `AppendBit` | Grow by one checked 0/1 bit; fail at the count limit |
| `ToBytes` | Exactly `ceil(Count()/8)` bytes, increasing bit indices, LSB first; empty emits empty array |

Storage packs 32 bits per word and keeps all trailing storage bits zero. A 33-bit set with bits 0, 31, and 32 set serializes as `[1, 0, 0, 128, 1]`. Set algebra requires the same public type; convert explicitly for cross-type use.

## Examples

```verse
CheckBitsExample()<transacts><decides>:void =
    Bitset := Bits.MakeGrowableBitset[33]
    Bitset.Set[0, 1]
    Bitset.Set[32, 1]
    Data := Bitset.ToBytes[]
    Data = array{1, 0, 0, 0, 1}
    Fixed := Bits.FixedBitsetFromBytes[33, Data]
    Fixed.PopulationCount() = 2
    Copy := Fixed.Clone()
    Copy.Set[0, 0]
    Fixed.Get[0] = 1
```

## Failure and cost notes

All public methods/factories have `<transacts>`. Use square-bracket calls for `<decides>` declarations inside a failure context; nonfailable methods use parentheses. Invalid lengths/indices/ranges/bit values, unequal-length algebra, malformed bytes/padding, and absent searches fail. A valid unset bit returns 0 rather than failure. Mutations roll back on failure, including surrounding-transaction failure.

Aliases share a mutable bitset. Clone, conversion, complement and algebra produce independent owners. Neither algebra input is changed. There is no concurrent-mutation guarantee; methods are synchronous and never yield.

Range/algebra/serialization work depends on word/byte length. Population count visits words and removes one set bit per inner iteration. Current searches iterate the word array even after finding a result; early hits do not establish constant whole-search time. Resize reconstructs word storage, including on append, so repeated appending can incur growing copies. Array-value writes may add native copying costs. Performance is unmeasured; no frame-time or amortized-append claim is made.
