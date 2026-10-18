# Encoding public API

## Overview

Strict UTF-8, Base64, Base64URL, Hex and raw code-unit adapters. The sole library dependency is `STL`; no crypto dependency is introduced. Install `00_stormlabs_stl.verse` before `10_stormlabs_encoding.verse` and application consumers such as `90_game.verse`.

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_encoding.verse); declaration order is preserved in the implementation.

## Types and constructors

There are no package-defined public types, enums, fields or constructors. Bytes are `[]int` values restricted to `0..255`. `UTF8ScalarAt` accepts an immutable `STL.int_buffer`, retaining caller byte offsets for diagnostics.

## Operations

`CharToByte`/`ByteToChar` bridge one raw UTF-8 code unit, including 128 and 255, without validating a whole string. `UTF8Encode` converts and validates a complete Verse string; `UTF8Decode` validates all input bytes before constructing a string. `ValidateUTF8` checks a complete sequence. `UTF8ToCodePoints` and `CodePointsToUTF8` convert Unicode scalar values. `UTF8ScalarAt` validates only the selected scalar and returns `(scalar, byteWidth)`; bytes elsewhere are not checked.

`Base64Encode` emits the standard `+/` alphabet with canonical required padding. `Base64Decode` requires complete groups and that padding. `Base64URLEncode` uses `-_`, unpadded by default; `?Padding := true` selects canonical padded output. `Base64URLDecode` accepts canonical padded or unpadded input. Both decoders reject whitespace, mixed/wrong alphabets and nonzero unused trailing bits. `HexEncode` emits lowercase pairs; `HexDecode` accepts either case, even length only, without separators or prefixes. Empty input succeeds in all whole-input codecs.

The following source-exact inventory includes every public function and its effects/default argument. Call `<decides>` operations with `[]` in a failure context.

```verse
Encoding<public> := module:
    Base64Encode<public>(Data:[]int)<transacts><decides>:string
    Base64URLEncode<public>(Data:[]int, ?Padding:logic = false)<transacts><decides>:string
    Base64Decode<public>(Text:string)<transacts><decides>:[]int
    Base64URLDecode<public>(Text:string)<transacts><decides>:[]int
    HexEncode<public>(Data:[]int)<transacts><decides>:string
    HexDecode<public>(Text:string)<transacts><decides>:[]int
    UTF8ScalarAt<public>(Source:STL.int_buffer, Offset:int)<transacts><decides>:tuple(int, int)
    ValidateUTF8<public>(Data:[]int)<transacts><decides>:void
    UTF8Encode<public>(Text:string)<transacts><decides>:[]int
    UTF8Decode<public>(Data:[]int)<transacts><decides>:string
    CodePointsToUTF8<public>(Values:[]int)<transacts><decides>:[]int
    UTF8ToCodePoints<public>(Data:[]int)<transacts><decides>:[]int
    CharToByte<public>(Character:char)<computes><decides>:int
    ByteToChar<public>(Value:int)<computes><decides>:char
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
if (Bytes := Encoding.UTF8Encode["AÃƒÆ’Ã‚Â©"]):
    if (Encoded := Encoding.Base64URLEncode[Bytes]):
        Print(Encoded)
if (Decoded := Encoding.HexDecode["007fff"]):
    if (EncodedHex := Encoding.HexEncode[Decoded]):
        Print(EncodedHex)
```

## Failure and cost notes

Invalid inputs fail completely, including an invalid byte after a valid prefix. UTF-8 rejects overlong encodings, invalid continuations, truncation, surrogate code points and values above U+10FFFF. Scalar inputs exclude U+D800..U+DFFF. Embedded NUL, BOM U+FEFF and noncharacters are preserved; there is no normalization, replacement decoding or implicit BOM removal. `UTF8ScalarAt` fails for EOF, negative offsets, continuation offsets or malformed selected scalars; its tuple width is bytes, not graphemes or UTF-16 units. Whole-input failure carries no category/offset. Binary Base64/Hex decoding does not require UTF-8. Arrays/strings are returned as values, no input mutation or mutable global state occurs, and all work is synchronous. Input/output traversal and repeated immutable appends can dominate allocation and copying; native renamed-source performance is unmeasured. `Crypto.HexEncode`/`HexDecode` remain independent functions.
