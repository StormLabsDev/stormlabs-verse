# stormlabs-encoding

Strict UTF-8, Base64, Base64URL, Hex, and byte/text adapters for Verse, licensed under the repository-wide [MIT License](../../LICENSE).

## Public API

Strict UTF-8/scalar conversion, Base64/Base64URL, Hex and raw code-unit adapters live in `Encoding`. See [API.md](API.md) for every function, exact effects, padding policy and failure behavior.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

**Historical status: The earlier implementation compiled with zero diagnostics and passed 119 named checks in UEFN. Performance remains unmeasured; no performance guarantee is implied.**

Follow the [root installation convention](../../README.md#installation): copy `../stormlabs-stl/src/stormlabs_stl.verse` as `00_stormlabs_stl.verse` and `src/stormlabs_encoding.verse` as `10_stormlabs_encoding.verse` into the same Verse source folder. Keep application consumers later, for example `90_game.verse`. Canonical repository filenames remain unchanged. The public modules are `Encoding` and its sole dependency `STL`; a containing project folder contributes to their import path. Production code has no device or test dependency.

## UTF-8 contract: encoding-v1

Bytes cross package boundaries as `[]int`, with every value restricted to `0..255`. Invalid inputs fail completely; callers receive no decoded prefix. Functions do not mutate input arrays or keep mutable global state. Returned values are independent values. All operations are synchronous and allocate output in memory; callers must bound work for their runtime budget.

| Public call | Result | Effects |
| --- | --- | --- |
| `CharToByte[Character:char]` | Raw UTF-8 code-unit value `0..255` | `<computes><decides>` |
| `ByteToChar[Value:int]` | One raw UTF-8 code unit; rejects values outside `0..255` | `<computes><decides>` |
| `UTF8ScalarAt[Source:STL.int_buffer, Offset:int]` | Tuple `(Unicode scalar value, byte width)` | `<transacts><decides>` |
| `ValidateUTF8[Data:[]int]` | `void` on valid complete UTF-8 | `<transacts><decides>` |
| `UTF8Encode[Text:string]` | Strictly validated UTF-8 bytes of the Verse string | `<transacts><decides>` |
| `UTF8Decode[Data:[]int]` | Verse string containing the validated UTF-8 code units | `<transacts><decides>` |
| `CodePointsToUTF8[Values:[]int]` | Encoded bytes for Unicode scalar values | `<transacts><decides>` |
| `UTF8ToCodePoints[Data:[]int]` | Decoded Unicode scalar values | `<transacts><decides>` |

Verse strings contain UTF-8 code units. `CharToByte` and `ByteToChar` bridge exactly one code unit, including raw `0x80` and `0xff`; they do not validate a whole string. Use `UTF8Encode` and `UTF8Decode` at whole-text boundaries. Neither conversion performs normalization, replacement decoding, newline translation, NUL termination, or BOM removal. Embedded U+0000, U+FEFF, noncharacters, and all other Unicode scalar values are preserved.

UTF-8 follows [RFC 3629](https://www.rfc-editor.org/rfc/rfc3629): overlong forms, invalid leading/continuation bytes, truncated sequences, surrogate values U+D800..U+DFFF, values above U+10FFFF, and integers outside the byte range fail. Empty text and arrays are valid. Code-point inputs use the Unicode scalar range `0..1114111`, excluding `55296..57343`.

`UTF8ScalarAt` reads exactly one scalar at a zero-based byte offset in the holder's immutable `Values`. The offset must select a leading byte inside the array; EOF, negative offsets, continuation-byte offsets, and malformed/truncated selected sequences fail. Bytes outside that selected sequence are not validated. The caller can advance by the returned width and retain its own byte offset for diagnostics. It is not a grapheme or UTF-16 index. Whole-input calls expose failure only; they do not provide an error category or offset.

```verse
if (Bytes := Encoding.UTF8Encode["Hello"]):
    if (Points := Encoding.UTF8ToCodePoints[Bytes]):
        Print("Decoded {Points.Length} Unicode scalar values")
```

Module-level conversion functions intentionally make the package and direction visible at call sites. This is a scoped deviation from Epic's preference for single-argument extension methods; consistent failable conversion names also match the existing `Crypto.HexEncode`/`HexDecode` surface. Public names and effects were exercised by the importing consumer described below.

## Base64 and Hex

All six functions below have `<transacts><decides>` effects. Encoders reject any integer outside `0..255`, including invalid values after a valid prefix. Decoders accept only the specified ASCII alphabet, never ignore whitespace, and fail without returning partial output. Empty input is valid for every function.

| Public call | Contract |
| --- | --- |
| `Base64Encode[Data:[]int]` | [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648) standard `+/` alphabet, with `=` padding exactly when needed |
| `Base64Decode[Text:string]` | Requires complete four-character groups and canonical terminal padding when needed |
| `Base64URLEncode[Data:[]int, ?Padding:logic = false]` | URL-safe `-_` alphabet, unpadded by default; `?Padding := true` emits canonical padding |
| `Base64URLDecode[Text:string]` | Accepts canonical padded or unpadded URL-safe input |
| `HexEncode[Data:[]int]` | Two lowercase digits per byte, including zero bytes |
| `HexDecode[Text:string]` | Even length, either letter case; no separators, whitespace, or `0x` prefix |

Base64 decoders reject mixed/wrong alphabets, embedded/excess/incorrect padding, lengths congruent to one modulo four, and nonzero unused bits in the final symbol. Standard Base64 also rejects missing required padding. For example, `Zg==` is valid standard input; `Zg` is accepted only by the URL decoder; `Zh==` is rejected by both because its unused low four bits are nonzero. Base64URL accepts both `Zg` and `Zg==`; it provides a predictable interoperable decoder rather than requiring a unique textual representation across those two permitted policies. To produce a specific form, select the encoder's padding option.

These are binary adapters: decoded bytes need not be valid UTF-8. Use the UTF-8 functions separately when text is required. Encoding does not strip or add a text BOM. The separate `Crypto.HexEncode` and `Crypto.HexDecode` APIs retain their existing implementation and compatibility; this module does not depend on crypto, and crypto does not depend on encoding.

## Provenance and verification

This is original StormLabs Verse code informed by RFC 3629 and RFC 4648, carrying the repository MIT license. No third-party implementation was translated. The complete octet tables provide a code-unit bridge without assuming unavailable native casts. The private text holder keeps the dependency on the existing `STL.int_buffer` API and requires no new STL type.

On 2026-10-17, the implementation compiled with the canonical `STL` dependency and zero diagnostics. The paced importing consumer then passed all 119 named checks with complete ordered BEGIN/END records and no failures. This covered all 256 raw code units, Unicode scalar boundaries, embedded NUL, malformed UTF-8 rejection, RFC Base64 answers, padding/alphabet/tail-bit policies, and Hex adapters. Those results apply to that earlier implementation.

Python reference checks supplement the native run. Performance probes are prepared but unrun; no timing or allocation result is claimed.
