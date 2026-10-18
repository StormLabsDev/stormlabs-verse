# STL public API

## Overview

An immutable holder for unrestricted integer arrays and checked half-open range copies. There are no library dependencies. Install as `00_stormlabs_stl.verse` using the [root convention](../../README.md#installation).

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_stl.verse); declaration order is preserved in the implementation.

## Types and constructors

`STL.int_buffer` is a public final class with a public constructor. Construct it as `STL.int_buffer{Values := Input}`. Its only public field, `Values:[]int`, is immutable after construction; integers are not restricted to bytes. The holder can be shared between readers. There are no enums or module-level factories.

## Operations

`CopyRange[Start, Stop]` copies `[Start, Stop)` into a returned array. Bounds must satisfy `0 <= Start <= Stop <= Values.Length`. Empty ranges, including at EOF, succeed. The declaration below is the complete public surface.

```verse
STL<public> := module:
    int_buffer<public> := class<final>:
        Values<public>:[]int
        CopyRange<public>(Start:int, Stop:int)<transacts><decides>:[]int
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
Buffer := STL.int_buffer{Values := array{-1, 20, 300}}
if (Middle := Buffer.CopyRange[1, 2]):
    Print("Copied {Middle.Length} integer")
```

## Failure and cost notes

Invalid bounds fail without returning a partial range. The holder does not mutate its input or enforce byte validation. Each successful copy constructs the requested range; it is not a zero-copy view or a streaming source. Work and output size scale with the requested range, while the caller still retains the complete input. Historical reader measurements do not establish timing for renamed source.
