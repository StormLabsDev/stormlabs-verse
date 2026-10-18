# Binary public API

## Overview

Checked byte storage and sequential binary I/O, explicit endian conversion, and exact bounded 32/64-bit word operations. No library dependencies.

```verse
Binary<public> := module:
```

Import the module from your own project's Verse folder path. Use the [numbered installation layout](../../README.md#installation), keeping canonical repository filenames unchanged. Signature blocks below reproduce public declarations without function bodies; class construction marked `<internal>` is restricted to its module.

All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. Historical native evidence for the larger suites predates the namespace rename; those suites were not rerun. Performance is unmeasured. See the [library README](README.md) for the historical scope.

## Types and constructors

```verse
byte_order<public> := enum:
    BigEndian
    LittleEndian
uint64<public> := struct<computes>:
    High<public>:int
    Low<public>:int
```
`byte_order.BigEndian` and `.LittleEndian` select byte order. `uint64.High` and `.Low` are public immutable integers, each checked in 0..4294967295 when used; the struct archetype is public. Bytes are `[]int` in 0..255, UInt16 is 0..65535, and UInt32 is 0..4294967295. Invalid public values fail rather than being silently masked.

`byte_buffer`, `binary_reader`, and `binary_writer` have module-only construction and private/internal state; create them through:

```verse
MakeByteBuffer<public>(Data:[]int)<transacts><decides>:byte_buffer
MakeBinaryReader<public>(Data:[]int)<transacts><decides>:binary_reader
MakeBinaryWriter<public>(?ByteLimit:int = 2147483647)<transacts><decides>:binary_writer
```
`MakeByteBuffer` and `MakeBinaryReader` validate every input byte. A reader owns a byte snapshot. A writer starts empty and has a checked logical byte limit 0..2147483647.

## Operations

### Word arithmetic and bit operations

```verse
AddUInt32<public>(A:int, B:int)<transacts><decides>:int
SubtractUInt32<public>(A:int, B:int)<transacts><decides>:int
AndUInt32<public>(A:int, B:int)<transacts><decides>:int
OrUInt32<public>(A:int, B:int)<transacts><decides>:int
XorUInt32<public>(A:int, B:int)<transacts><decides>:int
(Value:int).NotUInt32<public>()<transacts><decides>:int
ShiftLeftUInt32<public>(Value:int, Count:int)<transacts><decides>:int
ShiftRightUInt32<public>(Value:int, Count:int)<transacts><decides>:int
RotateLeftUInt32<public>(Value:int, Count:int)<transacts><decides>:int
RotateRightUInt32<public>(Value:int, Count:int)<transacts><decides>:int
AddUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64
SubtractUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64
AndUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64
OrUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64
XorUInt64<public>(A:uint64, B:uint64)<transacts><decides>:uint64
(Value:uint64).NotUInt64<public>()<transacts><decides>:uint64
ShiftLeftUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64
ShiftRightUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64
RotateLeftUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64
RotateRightUInt64<public>(Value:uint64, Count:int)<transacts><decides>:uint64
```
Add/subtract wrap modulo the named width after validating operands. Bitwise operations and complements retain that width. Shifts reject negative counts; zero preserves the input and counts at or above 32/64 return zero. Rotations reject negative counts and reduce nonnegative counts modulo the width. Right shifts are logical. Import `Binary` to make the two complement extensions available. No word operation uses floating point or a packed unsigned 64-bit intermediate.

### Endian encoding

```verse
EncodeUInt16<public>(Value:int, Order:byte_order)<transacts><decides>:[]int
EncodeUInt32<public>(Value:int, Order:byte_order)<transacts><decides>:[]int
EncodeUInt64<public>(Value:uint64, Order:byte_order)<transacts><decides>:[]int
```
Outputs contain exactly 2/4/8 bytes. Big-endian UInt64 emits the high half first; little-endian emits the low half first.

### byte_buffer

```verse
byte_buffer<public> := class<internal><final>:
    Count<public>()<transacts>:int
    CopyBytes<public>()<transacts>:[]int
    CopyRange<public>(Start:int, Stop:int)<transacts><decides>:[]int
    Append<public>(Data:[]int)<transacts><decides>:void
    Get<public>(Index:int)<transacts><decides>:int
    Set<public>(Index:int, Value:int)<transacts><decides>:void
    Resize<public>(Length:int, ?FillByte:int = 0)<transacts><decides>:void
    WriteBytes<public>(Offset:int, Data:[]int)<transacts><decides>:void
    ReadUInt16<public>(Offset:int, Order:byte_order)<transacts><decides>:int
    ReadUInt32<public>(Offset:int, Order:byte_order)<transacts><decides>:int
    ReadUInt64<public>(Offset:int, Order:byte_order)<transacts><decides>:uint64
    WriteUInt16<public>(Offset:int, Value:int, Order:byte_order)<transacts><decides>:void
    WriteUInt32<public>(Offset:int, Value:int, Order:byte_order)<transacts><decides>:void
    WriteUInt64<public>(Offset:int, Value:uint64, Order:byte_order)<transacts><decides>:void
    ReadUInt32BE<public>(Offset:int)<transacts><decides>:int
    ReadUInt32LE<public>(Offset:int)<transacts><decides>:int
    WriteUInt32BE<public>(Offset:int, Value:int)<transacts><decides>:void
    WriteUInt32LE<public>(Offset:int, Value:int)<transacts><decides>:void
```
`Count` reports bytes. `Get`/`Set` use checked zero-based indices. `CopyRange` uses a half-open `[Start, Stop)` range, including an empty range at the end. `Append` validates the complete input. `Resize` preserves the retained prefix, validates the fill byte even when no growth is needed, and fills growth with that byte. `WriteBytes` and all word writes replace existing storage without growing it. Word offsets are byte offsets and require the full 2/4/8-byte extent. `BE`/`LE` convenience methods fix the order.

### binary_reader

```verse
binary_reader<public> := class<internal><final>:
    Position<public>()<transacts>:int
    Remaining<public>()<transacts>:int
    Seek<public>(NewPosition:int)<transacts><decides>:void
    ReadBytes<public>(Length:int)<transacts><decides>:[]int
    ReadByte<public>()<transacts><decides>:int
    ReadUInt16<public>(Order:byte_order)<transacts><decides>:int
    ReadUInt32<public>(Order:byte_order)<transacts><decides>:int
    ReadUInt64<public>(Order:byte_order)<transacts><decides>:uint64
```
`Seek` permits 0..input length. Reads advance `Position` only after complete success; `Remaining` reports unread bytes. Empty `ReadBytes[0]` is valid. A failed read or seek preserves the cursor.

### binary_writer

```verse
binary_writer<public> := class<internal><final>:
    Count<public>()<transacts>:int
    CopyBytes<public>()<transacts>:[]int
    WriteBytes<public>(Data:[]int)<transacts><decides>:void
    WriteByte<public>(Value:int)<transacts><decides>:void
    WriteUInt16<public>(Value:int, Order:byte_order)<transacts><decides>:void
    WriteUInt32<public>(Value:int, Order:byte_order)<transacts><decides>:void
    WriteUInt64<public>(Value:uint64, Order:byte_order)<transacts><decides>:void
```
Writes append whole values; there is no seek or partial write. A failed write preserves content and count. `CopyBytes` returns a Verse array value independent of later buffer/writer mutations.

## Examples

```verse
using { Binary }

CheckBinaryExample()<transacts><decides>:void =
    Writer := Binary.MakeBinaryWriter[?ByteLimit := 8]
    Word := Binary.uint64{High := 0x01234567, Low := 0x89abcdef}
    Writer.WriteUInt64[Word, Binary.byte_order.BigEndian]
    Reader := Binary.MakeBinaryReader[Writer.CopyBytes()]
    Read := Reader.ReadUInt64[Binary.byte_order.BigEndian]
    Read.High = Word.High
    Read.Low = Word.Low
    Reader.Remaining() = 0
    Wrapped := Binary.AddUInt32[4294967295, 1]
    Wrapped = 0
    Inverted := Wrapped.NotUInt32[]
    Inverted = 4294967295
```

## Failure and cost notes

Every operation has `<transacts>`; declarations with `<decides>` use square brackets inside a failure context, such as the example's failable function or a positive `if`. Nonfailable methods use parentheses. Failures roll back mutations, including when a surrounding transaction fails. Negating a successful mutating operation rolls it back; retain intended changes through a successful positive branch.

Buffers/readers/writers are mutable class references: aliases share state and need one logical owner. Returned arrays and UInt64 values expose no mutable context state. Readers retain snapshots, not caller buffer aliases. There is no deep-copy or zero-copy allocation guarantee.

Buffers/readers accept at most 2147483647 bytes, an arithmetic API bound without an allocation or execution-budget promise. Word operations inspect a bounded number of halves/bytes; buffer copying, appending and resizing can allocate/copy arrays, and repeated small appends can incur additional backing-store costs. No operation yields, and no native timing/frame guarantee is made.
