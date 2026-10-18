# stormlabs-binary

## Public API overview

Checked byte buffers, snapshot readers, append-only writers, endian conversion, and bounded 32/64-bit arithmetic. See the [complete public API](API.md) for exact signatures, effects, overloads, and examples.

**Validation status:** All 13 libraries compiled together without diagnostics and passed the 13-group public API smoke test. The larger native suites reported below are historical results from before the namespace rename; they were not rerun for this revision. Performance remains unmeasured.

Checked native Verse bytes, words, buffers, readers, and writers.

The earlier implementation compiled without diagnostics and passed the combined Binary/Bits suite's 107 named groups in UEFN 42.40, CL 59247843. The complete log matched the exact source and run identities. Separate compile controls rejected all ten intended constructor/state accesses across both modules; positive compilation succeeded before and after those controls. The Verse VM variant was not identified. Performance remains unmeasured; these bounded results do not establish correctness for every input or a frame-budget guarantee.

## Installation

Follow the [root numbered installation layout](../../README.md#installation): copy `src/stormlabs_binary.verse` into your project's Verse source folder as `00_stormlabs_binary.verse`, with consuming application files after the installed libraries, for example `90_game.verse`. Keep the repository's canonical source filename unchanged. The file defines `Binary`; outside consumers import it from their own project's Verse path. There are no specialized-library dependencies, package-manager requirements, native bindings, or test imports. This library does not modify existing `STL` or `Crypto` APIs.

## Representation and arithmetic

Bytes cross library boundaries as `[]int`; every public byte input must contain only 0..255. Invalid values fail, including a bad byte after a valid prefix. Bytes are never silently masked. Public UInt16 values are integers in 0..65535; UInt32 values are integers in 0..4294967295. `uint64` is an immutable value with public `High:int` and `Low:int` halves, each in the UInt32 range. Its archetype is public, so every operation checks both halves rather than trusting construction.

`AddUInt32[A, B]` / `SubtractUInt32[A, B]` and `AddUInt64[A, B]` / `SubtractUInt64[A, B]` wrap modulo their named width. `AndUInt32`, `OrUInt32`, `XorUInt32` and their UInt64 counterparts operate on validated words. Import `Binary` to call the complement extensions `Value.NotUInt32[]` and `Value.NotUInt64[]`.

`ShiftLeftUInt32`, `ShiftRightUInt32`, `RotateLeftUInt32`, and `RotateRightUInt32` take `(Value, Count)`; corresponding UInt64 functions take `uint64`. Negative counts fail. A shift by zero preserves the value; a shift at or above the width produces zero. Rotations reduce nonnegative counts modulo the width, including zero. Right shifts are logical, not sign extending. Left shifts mask the discarded bits before multiplication. UInt64 operations keep separate bounded halves, handle carries/borrows explicitly, and never pack an unsigned 64-bit value into one signed integer. No word operation uses floating point.

`byte_order` has `BigEndian` and `LittleEndian`. `EncodeUInt16[Value, Order]`, `EncodeUInt32[Value, Order]`, and `EncodeUInt64[Value, Order]` return exactly 2, 4, or 8 bytes. UInt64 big-endian output puts the high half first; little-endian puts the low half first.

## Byte buffers

`MakeByteBuffer[Data]` validates and returns a `byte_buffer`. Construction is module-only. Storage is private and mutable; aliases share mutations. `CopyBytes()` and `CopyRange[Start, Stop]` return Verse array values, so changing a returned variable does not mutate the buffer. This is a value-ownership contract, with no zero-copy or allocation promise.

| Operation | Contract |
| --- | --- |
| `Count()` | Current length in bytes |
| `Get[Index]`, `Set[Index, Value]` | Checked byte index; `Set` validates 0..255 |
| `CopyRange[Start, Stop]` | Zero-based half-open range; empty ranges including at the end are valid |
| `Append[Data]` | Validate the whole input, then append all bytes |
| `Resize[Length, ?FillByte := 0]` | Preserve the retained prefix; new bytes use validated fill; shrinking discards the suffix |
| `WriteBytes[Offset, Data]` | Replace existing bytes; no implicit growth; empty write at the end is valid |
| `ReadUInt16/32/64[Offset, Order]` | Read exactly 2/4/8 existing bytes at a byte offset |
| `WriteUInt16/32/64[Offset, Value, Order]` | Replace exactly 2/4/8 bytes; validate value and bounds |
| `ReadUInt32BE/LE[Offset]`, `WriteUInt32BE/LE[Offset, Value]` | Convenience forms with explicit byte order |

Buffers and reader snapshots accept at most 2147483647 bytes. This is a logical API limit, not an allocation, throughput, or frame-time promise. Bounds checks use subtraction before adding offsets.

## Readers and writers

`MakeBinaryReader[Data]` validates bytes and creates a `binary_reader` owning its own byte snapshot. Later changes to the caller's array or a buffer from which it was copied do not affect the reader. `Position()` and `Remaining()` report byte counts. `Seek[Position]` permits 0..input length. `ReadBytes[Length]`, `ReadByte[]`, and `ReadUInt16/32/64[Order]` advance the cursor only after a complete successful read. Empty reads are valid. A failed read or seek leaves the cursor unchanged.

`MakeBinaryWriter[?ByteLimit := 2147483647]` creates an empty append-only `binary_writer`, with a checked limit in 0..2147483647. `Count()` reports written bytes and `CopyBytes()` returns an independent array value. `WriteBytes[Data]`, `WriteByte[Value]`, and `WriteUInt16/32/64[Value, Order]` append complete validated values. A failed write leaves content and count unchanged. There is no seek or automatic partial write.

## Effects, ownership, and errors

Every public function and method has `<transacts>`. Checked operations and factories additionally have `<decides>` and use square-bracket calls in a failure context. `Count`, `CopyBytes`, `Position`, and `Remaining` are nonfailable. Failure gives no partial output and rolls back mutations; failure in a surrounding transaction also rolls back earlier successful operations. Public errors are ordinary Verse failure, without a separate diagnostic object.

Each mutable buffer, reader, or writer needs a single logical owner. No operation suspends; there are no locks, yielding wrappers, or implied concurrency guarantees. Callers must bound work to their UEFN execution budget. Returned UInt64 values and byte arrays do not expose mutable context state.

```verse
if (Writer := Binary.MakeBinaryWriter[]):
    if (Writer.WriteUInt32[0x12345678, Binary.byte_order.BigEndian]):
        if (Reader := Binary.MakeBinaryReader[Writer.CopyBytes()]):
            if (Value := Reader.ReadUInt32[Binary.byte_order.BigEndian]):
                Print("Read {Value}")
```

Licensed under the repository [MIT License](../../LICENSE), copyright 2026 StormLabs. This is original implementation code; no external implementation was copied.
