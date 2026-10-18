# stormlabs-stl

Shared native Verse utilities for StormLabs Verse. Licensed under the repository-wide [MIT License](../../LICENSE).

## Public API

`STL.int_buffer` exposes immutable `Values` and checked `CopyRange[Start, Stop]`. See [API.md](API.md) for complete declarations, effects and examples.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

## Available API

Follow the [root installation convention](../../README.md#installation): copy `src/stormlabs_stl.verse` as `00_stormlabs_stl.verse`, before dependent libraries and `90_` application consumers, into your project's Verse source folder. It defines the public `STL` module and does not depend on another StormLabs library.

`STL.int_buffer{Values := Input}` stores an immutable integer array in a class instance. `Values` is readable and cannot be reassigned after construction. Pass the holder between range reads; each `CopyRange[Start, Stop]` returns an independent array containing the half-open range `[Start, Stop)`.

The range must satisfy `0 <= Start <= Stop <= Values.Length`. Invalid bounds fail. Empty ranges are accepted, including `[Length, Length)` and `[0, 0)` on an empty buffer. Integers are unrestricted; this utility does not validate that they are bytes.

```verse
Buffer := STL.int_buffer{Values := array{10, 20, 30}}
if (Middle := Buffer.CopyRange[1, 2]):
    Print("Copied {Middle.Length} integer")
```

The method uses `<transacts><decides>` effects. Its work scales with the requested range length. The caller still holds the complete input array; this is not a streaming source or a zero-copy view. Class instances provide shared object access, without raw pointers or manual memory management.

## Dependencies and verification

Dependency direction is `stormlabs-crypto` to `stormlabs-stl`. STL must not import crypto, encoding, JSON, or device integration code.

The earlier extracted reader passed direct public-API checks and the crypto integration suite in UEFN 42.40. Checks cover arbitrary integers, valid/empty/invalid ranges, aliases, immutable input snapshots, and independently mutable output copies. Test vectors, harnesses, and result files stay in the repository's ignored local test directory. See the root README for the current validation status.

Earlier measurements of the equivalent internal reader showed substantially lower range-copy cost than `Slice` for large source arrays; [design notes](../../docs/architecture.md) record the setup and limits. These are historical measurements, not a benchmark of the newly extracted public module.
