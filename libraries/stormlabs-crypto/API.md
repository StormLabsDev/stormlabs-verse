# Crypto public API

## Overview

Native Verse SHA-2, HMAC-SHA-2, HKDF and strict Hex. `STL` is the sole library dependency. Install `00_stormlabs_stl.verse` before `10_stormlabs_crypto.verse` and later applications such as `90_game.verse`. This is experimental, unaudited code; constant-time execution, secure erasure and formal validation are not established.

The thirteen renamed libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark; historical README results apply to the earlier source fingerprints, and current-source performance is unmeasured. This reference is checked against [the source](src/stormlabs_crypto.verse); declaration order is preserved in the implementation.

## Types and constructors

Six public final hash contexts have public zero-argument archetype construction: `sha224_context{}`, `sha256_context{}`, `sha384_context{}`, `sha512_context{}`, `sha512_224_context{}` and `sha512_256_context{}`, each qualified by `Crypto.` outside the module. Each exposes Reset/Update/Finalize and no public fields. `hmac_context` is public/final with an internal constructor and no public fields; use MakeHMAC or yielding CreateHMAC. `sha2_algorithm` has the six exact variants shown in the inventory. No configurable initial-state or digest-length constructor is public.

## Operations

For each SHA variant, `SHA...` returns bytes, `SHA...Hex` returns lowercase Hex, and `HashSHA...` is a yielding option-returning byte API. `SHA256Async` remains the compatibility wrapper for `HashSHA256`, with the same default batch argument. The SHA-224/SHA-512 truncated variants use their specified initial states.

All hash contexts expose Reset, failable Update and idempotent Finalize. HMAC contexts also expose computes DigestSize/BlockSize. MakeHMAC/HMAC/VerifyHMAC select a public algorithm; VerifyHMAC accepts full-length tags only. HMACSHA224/256/384/512/512_224/512_256 are full-tag convenience functions. CreateHMAC and AuthenticateHMAC yield and return options.

HKDFExtract computes the extract PRK. HKDFExpand accepts a PRK of at least the digest size and validates `0 <= Length <= 255 * digestSize`; HKDF combines both steps. HKDFSHA256/HKDFSHA512 are named synchronous conveniences. ExtractHKDF/ExpandHKDF/DeriveHKDF yield and return options. Empty salt follows HKDF's HMAC-zero-padding equivalence; zero output still validates inputs. HexDecode accepts even-length mixed-case digits without whitespace, separators or a `0x` prefix. HexEncode validates all bytes and emits lowercase.

| Algorithm | Digest bytes | Compression block bytes |
| --- | --- | --- |
| Sha224 | 28 | 64 |
| Sha256 | 32 | 64 |
| Sha384 | 48 | 128 |
| Sha512 | 64 | 128 |
| Sha512_224 | 28 | 128 |
| Sha512_256 | 32 | 128 |

The complete source-exact inventory follows. Function bodies are omitted; repeated method signatures remain under their exact declaring context. Public constructors are as described above; there are no additional public fields or overloads.

```verse
Crypto<public> := module:
    HexEncode<public>(Data:[]int)<transacts><decides>:string
    HexDecode<public>(Text:string)<transacts><decides>:[]int
    sha256_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    sha224_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    SHA256<public>(Data:[]int)<transacts><decides>:[]int
    SHA256Hex<public>(Data:[]int)<transacts><decides>:string
    SHA224<public>(Data:[]int)<transacts><decides>:[]int
    SHA224Hex<public>(Data:[]int)<transacts><decides>:string
    HashSHA256<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    HashSHA224<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    SHA256Async<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    sha384_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    SHA384<public>(Data:[]int)<transacts><decides>:[]int
    SHA384Hex<public>(Data:[]int)<transacts><decides>:string
    HashSHA384<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    sha512_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    SHA512<public>(Data:[]int)<transacts><decides>:[]int
    SHA512Hex<public>(Data:[]int)<transacts><decides>:string
    HashSHA512<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    sha512_224_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    SHA512_224<public>(Data:[]int)<transacts><decides>:[]int
    SHA512_224Hex<public>(Data:[]int)<transacts><decides>:string
    HashSHA512_224<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    sha512_256_context<public> := class<final>:
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    SHA512_256<public>(Data:[]int)<transacts><decides>:[]int
    SHA512_256Hex<public>(Data:[]int)<transacts><decides>:string
    HashSHA512_256<public>(Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    sha2_algorithm<public> := enum:
        Sha224
        Sha256
        Sha384
        Sha512
        Sha512_224
        Sha512_256
    SHA2DigestSize<public>(Algorithm:sha2_algorithm)<computes>:int
    SHA2BlockSize<public>(Algorithm:sha2_algorithm)<computes>:int
    hmac_context<public> := class<internal><final>:
        DigestSize<public>()<computes>:int
        BlockSize<public>()<computes>:int
        Reset<public>()<transacts>:void
        Update<public>(Data:[]int)<transacts><decides>:void
        Finalize<public>()<transacts><decides>:[]int
    MakeHMAC<public>(Algorithm:sha2_algorithm, Key:[]int)<transacts><decides>:hmac_context
    HMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int)<transacts><decides>:[]int
    VerifyHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int, Tag:[]int)<transacts><decides>:void
    CreateHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, ?BytesPerUpdate:int = 128)<suspends>:?hmac_context
    AuthenticateHMAC<public>(Algorithm:sha2_algorithm, Key:[]int, Data:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    HMACSHA224<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HMACSHA256<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HMACSHA384<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HMACSHA512<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HMACSHA512_224<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HMACSHA512_256<public>(Key:[]int, Data:[]int)<transacts><decides>:[]int
    HKDFExtract<public>(Algorithm:sha2_algorithm, Salt:[]int, InputKeyMaterial:[]int)<transacts><decides>:[]int
    HKDFExpand<public>(Algorithm:sha2_algorithm, PRK:[]int, Info:[]int, Length:int)<transacts><decides>:[]int
    HKDF<public>(Algorithm:sha2_algorithm, InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int
    ExtractHKDF<public>(Algorithm:sha2_algorithm, Salt:[]int, InputKeyMaterial:[]int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    ExpandHKDF<public>(Algorithm:sha2_algorithm, PRK:[]int, Info:[]int, Length:int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    DeriveHKDF<public>(Algorithm:sha2_algorithm, InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int, ?BytesPerUpdate:int = 128)<suspends>:?[]int
    HKDFSHA256<public>(InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int
    HKDFSHA512<public>(InputKeyMaterial:[]int, Salt:[]int, Info:[]int, Length:int)<transacts><decides>:[]int
```

## Examples

Examples assume the public module is visible through your project's containing folder. Helper/local names do not shadow the module.

```verse
if (DigestHex := Crypto.SHA256Hex[array{97, 98, 99}]):
    Print(DigestHex)

Hasher := Crypto.sha256_context{}
if (Hasher.Update[array{97, 98, 99}], Digest := Hasher.Finalize[]):
    if (DigestHex := Crypto.HexEncode[Digest]):
        Print(DigestHex)

# In a suspending caller:
MaybeDigest := Crypto.HashSHA256(array{97, 98, 99})
if (Digest := MaybeDigest?):
    if (DigestHex := Crypto.HexEncode[Digest]):
        Print(DigestHex)
```

## Failure and cost notes

Raw byte values outside 0..255 fail completely. `<transacts><decides>` calls use square brackets in a failure context; yielding `<suspends>` APIs use ordinary calls and return false on invalid input/batch. Batch defaults are 128 bytes, permitted 1..4096, and control scheduling rather than digest format. Inputs still reside in memory; use incremental updates for streamed chunks. Contexts have one logical owner; assignment aliases mutable state. Update validates chunks transactionally, Finalize is idempotent, Update after Finalize fails even for empty chunks, and Reset allows reuse. HMAC Reset retains prepared key material. Private yielding contexts are abandoned on cancellation. SHA-224/256 format length is at most 2^61-1 bytes; the wide family uses a four-limb count bounded by 2^125-1 bytes. These are format bounds, not allocation promises. Synchronous calls and large finalization/output work can exceed a frame budget; yielding does not reduce CPU per slice. Historical earlier CPU measurements are in the README; no current performance measurement or full-suite rerun is implied by the namespace smoke. HMAC verification checks tag length/range and all bytes but makes no runtime constant-time guarantee. HKDF is not password stretching, and plain hashing is not message authentication. No encryption, entropy or signature API is supplied by this module.
