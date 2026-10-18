# stormlabs-crypto

The native Verse cryptography library in StormLabs Verse. Licensed under the repository-wide MIT License.

## Public API

`Crypto` exposes SHA-2 one-shot/incremental/yielding hashing, HMAC, HKDF and strict Hex. See [API.md](API.md) for every context, enum variant, exact signature/effect and failure contract; `SHA256Async` remains the compatibility wrapper.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

**Historical status: all six SHA-2 variants, HMAC-SHA-2, HKDF, and Hex implemented; earlier native bounded coverage checks passed. Experimental and unaudited.**

The algorithms are written in Verse, using standard Verse runtime APIs without an external cryptography service or custom C++ bindings. Development tools and reference implementations may use other languages for verification; the shipped library does not require them.

## First release scope

1. Strict byte validation, endian conversion, and exact fixed-width arithmetic for crypto. General text encodings belong in the `stormlabs-encoding` library; existing Hex APIs remain compatible here.
2. The complete SHA-2 family: SHA-224, SHA-256, SHA-384, SHA-512, SHA-512/224, and SHA-512/256, including incremental hashing.
3. HMAC over the supported SHA-2 hashes, plus HKDF-SHA-256 and HKDF-SHA-512.
4. Locally maintained known-answer vectors, invalid-input and boundary tests, UEFN examples, and measured runtime benchmarks. Test harnesses and vectors stay outside Git.

SHA-1 and SHA-3 are excluded. SHA-512/224 and SHA-512/256 require their specified initial states; they are not simple truncations of ordinary SHA-512.

## Possible future work

- ChaCha20-Poly1305 authenticated encryption, followed by AES-128/256-GCM.
- PBKDF2-HMAC-SHA-256/512 for interoperability, subject to practical work-factor benchmarks.
- Ed25519 verification, then signing and X25519 key agreement.
- Random bytes, salts, tokens, and nonce-management utilities using the platform entropy source.

These are possibilities, not available features or performance commitments.

## HMAC and HKDF

Select a hash with `sha2_algorithm.Sha224`, `.Sha256`, `.Sha384`, `.Sha512`, `.Sha512_224`, or `.Sha512_256`. `SHA2DigestSize(Algorithm)` and `SHA2BlockSize(Algorithm)` report byte sizes.

| Operation | Synchronous | Yielding |
| --- | --- | --- |
| HMAC tag | `HMAC[Algorithm, Key, Data]` | `AuthenticateHMAC(Algorithm, Key, Data)` |
| HMAC context | `MakeHMAC[Algorithm, Key]` | `CreateHMAC(Algorithm, Key)` |
| HKDF extract | `HKDFExtract[Algorithm, Salt, InputKeyMaterial]` | `ExtractHKDF(Algorithm, Salt, InputKeyMaterial)` |
| HKDF expand | `HKDFExpand[Algorithm, PRK, Info, Length]` | `ExpandHKDF(Algorithm, PRK, Info, Length)` |
| HKDF derive | `HKDF[Algorithm, InputKeyMaterial, Salt, Info, Length]` | `DeriveHKDF(Algorithm, InputKeyMaterial, Salt, Info, Length)` |

All yielding operations accept `?BytesPerUpdate := 128`, within 1..4,096, and return an option. The batch size controls scheduling. Synchronous operations have `<transacts><decides>` effects and require application-appropriate input/work limits.

Named full-tag helpers are available for each hash, such as `HMACSHA256[Key, Data]` and `HMACSHA512_256[Key, Data]`. `HKDFSHA256[...]` and `HKDFSHA512[...]` have the same arguments as generic `HKDF`, without the algorithm selector.

Create an `hmac_context` through its factory. It precomputes private inner/outer key states and exposes `Update[Chunk]`, `Finalize[]`, `Reset()`, `DigestSize()`, and `BlockSize()`. Finalization is repeatable; subsequent updates fail until reset. Reset retains the key for another message. Returned arrays and caller inputs have value semantics. Keep a mutable context owned by one task while a message is in progress.

`VerifyHMAC[Algorithm, Key, Data, Tag]` succeeds only for a matching full-length tag. It rejects truncated tags, invalid byte values, and wrong lengths. Equal-length tags are compared across every byte; this does not establish a constant-time runtime guarantee. Key-derived state remains private; the runtime does not promise secure erasure.

HKDF follows [RFC 5869](https://www.rfc-editor.org/rfc/rfc5869.html). `Length` must be within 0..255 times the selected digest size. Raw expand requires a PRK of at least one digest length. Empty salt is supported. Empty output still validates every supplied byte sequence. HKDF derives keys from keying material; it is not a password stretching function. Use protocol-specific `Info` values to separate uses of derived keys.

The historical keyed-crypto coverage includes long-key HMAC, reset/finalize/reuse/rollback, input/output ownership, full-tag verification and every modified tag byte. All six hash routes retain the full SHA-2 regression evidence and 1,301 HMAC pairs each. HKDF SHA-224/SHA-256 retain 1,053 cases per route; SHA-384/SHA-512/SHA-512/224/SHA-512/256 each passed 117 reduced-sampling cases: all 53 named/boundary inputs and 64 representative frozen random inputs. The reduced random-sampling coverage target preserves every non-random fixture, dedicated check and API route; its 48 fewer checks are repeated random zero-output confirmations. This reduces random sampling volume, while the exhaustive profile remains available. Published RFC 4231 HMAC tags cover SHA-224/256/384/512 (case 5 checks its published truncated prefix against the full reference); SHA-512/t HMAC answers use independent references. The three published RFC 5869 HKDF answers apply to SHA-256; corresponding inputs on the other five routes use independently derived answers. HKDF covers all six generic hash routes and the two named convenience wrappers, separate extract/expand/derive, raw PRK sizes, zero output with full input validation, partial/multiblock/maximum outputs, all 23 explicit batch sizes, defaults, concurrency, cancellation, and 1 MiB IKM/salt/info/raw PRK inputs. Larger outputs and maximum expansions were validated through yielding APIs using exact length and independent SHA-256 fingerprints; synchronous output validation above 257 bytes is not claimed.

## Available API

Follow the [root installation convention](../../README.md#installation): copy `../stormlabs-stl/src/stormlabs_stl.verse` as `00_stormlabs_stl.verse` and `src/stormlabs_crypto.verse` as `10_stormlabs_crypto.verse` into the same Verse source folder, before `90_` application consumers. They define `Crypto` and its dependency `STL`; canonical repository filenames remain unchanged.

| Algorithm | One-shot function | Incremental context | Yielding function | Digest bytes |
| --- | --- | --- | --- | --- |
| SHA-224 | `SHA224[Data]` | `sha224_context{}` | `HashSHA224(Data)` | 28 |
| SHA-256 | `SHA256[Data]` | `sha256_context{}` | `HashSHA256(Data)` | 32 |
| SHA-384 | `SHA384[Data]` | `sha384_context{}` | `HashSHA384(Data)` | 48 |
| SHA-512 | `SHA512[Data]` | `sha512_context{}` | `HashSHA512(Data)` | 64 |
| SHA-512/224 | `SHA512_224[Data]` | `sha512_224_context{}` | `HashSHA512_224(Data)` | 28 |
| SHA-512/256 | `SHA512_256[Data]` | `sha512_256_context{}` | `HashSHA512_256(Data)` | 32 |

Each algorithm also has a one-shot hexadecimal function, such as `SHA512_256Hex[Data]`. Contexts provide `Update[Chunk]`, `Finalize[]`, and `Reset()`. All yielding functions accept `?BytesPerUpdate := 128`. `SHA256Async` remains a compatibility wrapper for `HashSHA256` with the same parameters.

`HexEncode[Data:[]int]` returns lowercase hexadecimal. `HexDecode[Text:string]` accepts either letter case and returns bytes. Decoding rejects odd lengths, invalid digits, whitespace, and `0x` prefixes.

Synchronous functions, `Update`, and `Finalize` are failable with `<transacts><decides>` effects. Inputs are raw integer bytes; values outside 0..255 fail. Empty input is supported. Yielding functions return `?[]int`, with `false` on invalid input or batch size.

```verse
if (Digest := Crypto.SHA256Hex[array{97, 98, 99}]):
    Print(Digest)
```

Every variant uses its specified initial state and output size. SHA-224 and SHA-512/224 or SHA-512/256 are not ordinary SHA-256/SHA-512 digests truncated afterward. Text conversion is available through `Encoding`; keyed APIs are described above.

## Large messages and ownership

All one-shot functions and `Update` are synchronous. Keep calls bounded to fit your game's execution budget. Incremental hashing retains less than one compression block of uncompressed input, a byte counter, and the hash state; only the final one or two blocks are padded. It does not create a padded copy of the whole message.

An incremental context belongs to one logical caller. `Update` validates its entire chunk before modifying state and rolls back on failure. Empty updates are accepted before finalization. `Finalize` is idempotent; updates after finalization fail, including empty updates. `Reset` permits reuse. SHA-224/256 process 64-byte blocks and permit at most 2^61 - 1 message bytes. The other four variants process 128-byte blocks and permit at most 2^125 - 1 message bytes, using a four-limb counter and a 128-bit encoded bit length. These are format limits, not memory or performance guarantees.

Each yielding function uses a private context and yields between batches. All accept batch sizes from 1 through 4096 bytes and default to 128. Invalid bytes or batch sizes return `false`, with no partial digest exposed. Canceling the task abandons its private context. The caller still supplies the whole input array; use incremental updates for a stream that should not be held entirely in memory.

Batch size controls scheduling, not the hash format. Messages may have any supported byte length. Each variant retains its fixed compression block and digest sizes listed above. Different batch sizes produce the same digest for the same message. The 128-byte default favors responsiveness; an explicit `?BytesPerUpdate := 1024` retains the previous batching behavior.

```verse
MaybeDigest := Crypto.HashSHA256(Data)
if (Digest := MaybeDigest?):
    if (Hex := Crypto.HexEncode[Digest]):
        Print(Hex)
```

Batch size bounds work per invocation, not the total cost of all callers in an update. Choose scheduling and concurrency appropriate to your island.

Local UEFN 42.40 `profile` measurements put an aligned 1,024-byte SHA-256 update at a median 27.18 ms, versus 80.44 ms before optimization. SHA-512 measured 38.19 ms. Fixed sigma functions avoid generic rotation dispatch and powers-of-two lookups; the STL holder avoids the measured large-array `Slice` bottleneck.

Each historical probe used seven samples per batch/pending-byte combination and checked all 196 resulting digests against independent answers. The SHA-256 probe used 0, 1, 55, or 63 pending bytes; SHA-512 used 0, 1, 111, or 127. Largest observed CPU samples follow.

SHA-256:

| Batch bytes | Update only (ms) | Copy + update + finalize (ms) |
| --- | --- | --- |
| 64 | 2.02 | 6.21 |
| 128 | 3.78 | 7.94 |
| 256 | 7.26 | 11.68 |
| 512 | 14.17 | 18.76 |
| 1,024 | 27.73 | 32.83 |
| 2,048 | 55.44 | 61.74 |
| 4,096 | 110.70 | 119.11 |

SHA-512:

| Batch bytes | Update only (ms) | Copy + update + finalize (ms) |
| --- | --- | --- |
| 64 | 5.14 | 10.95 |
| 128 | 5.24 | 15.88 |
| 256 | 10.24 | 20.82 |
| 512 | 19.56 | 30.68 |
| 1,024 | 38.60 | 50.07 |
| 2,048 | 76.68 | 89.35 |
| 4,096 | 153.07 | 168.08 |

The combined column includes finalization and nested profiling overhead. These samples describe one editor/session configuration; they are not percentile estimates or upper bounds. Finalization can require two compression blocks. Yielding spreads work but does not reduce CPU cost within a batch, and initialization, output allocation, and concurrent callers add work. The 128-byte default is not a frame-time guarantee; profile your island and target platform. Measurements of SHA-512's shared core are not separate benchmarks of every truncated variant.

## HMAC key reuse measurements

All six HMAC variants were measured with seven samples for each fresh/reused-key combination, key lengths 32/129/1,024, and message lengths 0/1,024. All 504 tags matched independent references. Fresh timings include the complete HMAC call. Reused timings measure only `Update` + `Finalize`; both factory/key preparation and `Reset` are outside the timed block. A context can retain its key across messages via `Reset()`. Representative medians for 1,024-byte messages follow.

| Hash | Key bytes | Fresh call (ms) | Reused Update + Finalize (ms) |
| --- | --- | --- | --- |
| SHA256 | 32 | 37.11 | 32.88 |
| SHA256 | 129 | 42.98 | 32.99 |
| SHA256 | 1,024 | 67.86 | 32.86 |
| SHA512 | 32 | 61.03 | 50.36 |
| SHA512 | 129 | 71.24 | 50.25 |
| SHA512 | 1,024 | 105.27 | 50.08 |

These synchronous CPU samples describe one configuration; they are not frame bounds, percentiles, or constant-time evidence.

The module-level `SHA2DigestSize`/`SHA2BlockSize` metadata helpers accept the public algorithm enum so generic HMAC/HKDF paths share one mapping. Context getters forward to it. Snapshot constructors group dependent state fields to make the cloned-state invariant visible; these are deliberate readability exceptions to extension-method and one-field-per-line preferences.

## Layout

- `src/`: shipped Verse source.
- [Design and VerseBoy research](../../docs/architecture.md): arithmetic strategy and implementation rationale.

Verification devices, vectors and benchmark tools are not bundled. See the [contribution guide](../../CONTRIBUTING.md#verification) to reproduce bounded local checks.

## Validation status

The earlier two-library layout has source-bound native evidence for 54,138 result comparisons and 2,451 behavior checks: seven complete full-suite partitions (51,805/1,983) plus two reduced-sampling HKDF partitions (2,333/468). Together these satisfy the reduced random-sampling coverage target of 22,042 comparisons and 2,435 checks. All nine reduced-sampling harnesses compiled without diagnostics; seven use the verified full-part coverage and were not independently runtime-executed as reduced-sampling harnesses. The original 72,826/2,483 exhaustive run remains incomplete. All six hash routes retain the full SHA-2 regression evidence and 1,301 HMAC pairs each. HKDF SHA-224/SHA-256 retain 1,053 cases per route; SHA-384/SHA-512/SHA-512/224/SHA-512/256 each passed 117 reduced-sampling cases: all 53 named/boundary inputs and 64 representative frozen random inputs. The reduced random-sampling coverage target preserves every non-random fixture, dedicated check and API route; its 48 fewer checks are repeated random zero-output confirmations. This reduces random sampling volume, while the exhaustive profile remains available.

The saved complete SHA-2 parts cover 1,119 SHA-256 messages, 1,183 SHA-224 messages and 1,375 messages for each wide variant, including all published NIST short/long answers. They include one-shot/incremental parity, every two-way split at selected padding boundaries, state lifecycle/rollback/ownership, invalid input, concurrency, cancellation and defaults; arithmetic covers 324 32-bit words and 388 wide word pairs, endian/counter limits and direct STL contracts. Large incremental/yielding inputs reach 1 MiB and million-a; the 16 KiB cases also ran synchronously.

HKDF covers all six generic hash routes and the two named convenience wrappers, separate extract/expand/derive, raw PRK sizes, zero output with full input validation, partial/multiblock/maximum outputs, all 23 explicit batch sizes, defaults, concurrency, cancellation, and 1 MiB IKM/salt/info/raw PRK inputs. Larger outputs and maximum expansions were validated through yielding APIs using exact length and independent SHA-256 fingerprints; synchronous output validation above 257 bytes is not claimed. Published RFC 4231 HMAC tags cover SHA-224/256/384/512 (case 5 checks its published truncated prefix against the full reference); SHA-512/t HMAC answers use independent references. The three published RFC 5869 HKDF answers apply to SHA-256; corresponding inputs on the other five routes use independently derived answers.

Six native compiler controls and 16 corrupt/incomplete/duplicate/failure log controls passed. Separate earlier-source CPU probes matched 196 SHA-256 digests, 196 SHA-512 digests and 504 HMAC tags. Python references cover all frozen cases; an additional Node/OpenSSL HKDF check matched 6,318 extracts and 6,270 nonempty outputs. Its 48 zero-output operations were unavailable in that backend, not passes. Native/Python zero-output coverage remains.

Both shipped source files and exact harness/deployment/log hashes are bound to the evidence. The observed editor build is UEFN 42.40 CL59247843; the historical logs do not independently establish their build identity. VM mode and cross-VM compatibility remain unverified. All tests and evidence remain local and Git-ignored; these results do not establish an audit or formal cryptographic validation.

## Security and licensing

The project has no audited or production-ready cryptography yet. Constant-time execution and secure erasure are not established runtime guarantees. Plain SHA-256 is not a message authenticator or a password-hashing scheme; HMAC authenticates messages and HKDF derives keys from keying material. Password stretching remains separate work.

Licensed under the [MIT License](../../LICENSE), copyright 2026 StormLabs. People may use, modify, redistribute, and sell the software, including in closed-source products, provided they retain the required copyright and license notice. The software is provided without warranty. No VerseBoy source has been copied into this repository.

## Specifications

- [SHA-2: NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)
- [SHA-224 examples: RFC 3874](https://www.rfc-editor.org/rfc/rfc3874.html)
- [HMAC: RFC 2104](https://www.rfc-editor.org/info/rfc2104/)
- [HKDF: RFC 5869](https://www.rfc-editor.org/info/rfc5869/)
- [Verse random integers: Epic API documentation](https://dev.epicgames.com/documentation/fortnite/verse-api/versedotorg/random/getrandomint?lang=en-US)
