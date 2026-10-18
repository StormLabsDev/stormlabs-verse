# StormLabs Verse library design

Public namespaces use bare names; see the [API catalog](API.md). All thirteen
modules compiled together and passed the 13-group public
consumer smoke check in UEFN 42.40 CL59247843. Historical native checks and
measurements below bind earlier source bytes; the naming refresh does not rerun
those full suites or supply new performance measurements.

This document records the library design and its local evidence. All six SHA-2 variants, incremental and yielding hashing, HMAC-SHA-2, HKDF, Hex and shared STL range copying are implemented and covered by the native policy described in the README. The repository also includes Binary/Bits, Encoding, JSON, Ordered, Bloom, Search, Queues, Cache, Disjoint-set and Trie packages with their own bounded local native checks; their module READMEs record contracts and evidence. Performance measurements below apply to the named crypto/STL revisions only.

## VerseBoy reference

Reviewed upstream snapshot: [Ep8Script/VerseBoy at 22f63160cd958bf9b09179498440b97db3c1148c](https://github.com/Ep8Script/VerseBoy/tree/22f63160cd958bf9b09179498440b97db3c1148c).

| Observed implementation | Source | Application to stormlabs-crypto |
| --- | --- | --- |
| A 16-bit register is composed of high and low byte references; writes mask and split the value. | [register.verse](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/src/core/CPU/register.verse#L1-L11) | Represent a 64-bit unsigned word as two bounded 32-bit halves. Prefer values over mutable reference aliases unless measurements justify otherwise. |
| Powers of two, integer multiplication/division, and masks implement shifts. | [bit_math.verse](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/src/core/Utils/bit_math.verse#L1-L43) | Implement exact shifts without assuming native shift operators exist. Its finite lookup range is not sufficient for crypto words. |
| Arithmetic explicitly masks results and calculates carry from intermediate sums. | [instructions.verse](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/src/core/CPU/instructions.verse#L50-L84) | Use bounded intermediates and explicit carry for modular addition. |
| Circular rotation explicitly reinserts the bit shifted out. | [instructions.verse](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/src/core/CPU/instructions.verse#L467-L519) | Implement word rotations, including transfer between the two halves of a 64-bit word. |
| Shared emulator code and UEFN integration live in separate source directories. | [src](https://github.com/Ep8Script/VerseBoy/tree/22f63160cd958bf9b09179498440b97db3c1148c/src) | Keep the crypto core independent of devices, presentation, and scheduling adapters. |
| Long hex conversion yields periodically and returns an optional byte array. | [UEFN bytes.verse](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/src/uefn/bytes.verse#L1-L22) | Offer bounded updates and optional scheduling wrappers; reject malformed input completely rather than accepting a decoded prefix. |

These are design observations, not independent confirmation of the emulator's correctness or speed. Its release workflow packages source; that alone does not establish a reusable compiler or test workflow.

VerseBoy's [license at the reviewed snapshot](https://github.com/Ep8Script/VerseBoy/blob/22f63160cd958bf9b09179498440b97db3c1148c/LICENSE) is MIT, copyright 2026 Ep8Script. No implementation source has been copied. Any future copying or substantial adaptation must retain the upstream copyright and permission notice and document provenance.

## Word representation

Use integer bytes restricted to 0 through 255 and unsigned 32-bit words restricted to 0 through 2^32 - 1. Do not use floating point for word arithmetic, powers, counters, or byte conversion.

Represent unsigned 64-bit words as high and low 32-bit halves. SHA-384 and the SHA-512 variants can then operate without storing an unsigned 64-bit value in one signed integer. Do not depend on arbitrary-precision behavior or signed overflow until verified against supported runtimes.

For 32-bit addition, bounded intermediate sums fit comfortably within signed 64-bit arithmetic. For 64-bit addition, add the low halves, extract their carry, then add the high halves with that carry; retain only each half's low 32 bits. Repeated additions must remain bounded at every step.

For a 32-bit left shift by 1 through 31, mask out the bits that would be discarded *before* multiplying by the relevant power of two. The multiplication result then remains below 2^32. This keeps the operation within the word width instead of relying on wider host intermediates. Logical right shift uses exact integer division of a normalized nonnegative word.

Define shift counts explicitly: zero preserves the input, counts at or above the word width produce zero, and negative counts are rejected. Normalize nonnegative rotation counts modulo the width, with a separate zero case. A paired 64-bit implementation needs explicit paths at 32 and 64 bits and must handle carry between halves without a 64-bit packed intermediate.

The current SHA-256 core specializes its four sigma functions with the specification's fixed rotation counts and constant integer factors. This avoids generic function dispatch and powers-of-two table lookups in the compression loop. Every rotation still masks before multiplication, keeping its intermediates below 2^32. The old generic helpers have no remaining consumer and are not shipped as an unused STL API. Generic fixed-width words, endian conversion, shifts and rotations now have their independently tested public contract in Binary; crypto retains its algorithm-specific arithmetic.

## Bytes and hash states

- Reject invalid public byte values; reserve masking for internal modular arithmetic.
- Make endian conversion explicit. SHA-2 message words and digest encoding use big-endian order; other algorithms may require little-endian helpers.
- Make byte arrays the primary hash input. Text helpers must specify and test UTF-8, including non-ASCII text and embedded zero bytes.
- Reject malformed Hex/Base64/Base64URL input without silently truncating or returning partial output.
- Share one compression implementation between SHA-224/256 and one between SHA-384/512/512-224/512-256, with distinct specified initialization and output rules.
- Define ownership of incremental state, behavior after finalization, reset/clone semantics, and maximum input length before exposing the API.
- Count message lengths with bounded multiword counters. Specify limits rather than assuming one signed integer can represent every standard-permitted bit length.
- Keep scheduling outside compression functions. Large inputs should be processed through bounded updates; any suspending wrapper must preserve state ownership across yields.

SHA-224 and SHA-256 now share one internal lifecycle class as well as compression. Its immutable configuration selects the specified initial state and seven or eight output words. Public final context classes own a private core and expose only update, finalization, and reset; custom initial states and output lengths are not public contracts. An unset internal state selects the configured initial value, which also makes reset independent of the variant. Each update operates on a local working state and commits it after successful processing; Verse transactions preserve rollback on failure.

The suspending entry points are `HashSHA224` and `HashSHA256`, following Epic's recommendation against Async suffixes. `SHA256Async` delegates to the latter for compatibility. Every call creates its own private core. The combined runtime suite rechecks both algorithms, their padding splits and lifecycle contracts, mixed-algorithm concurrency, and independent reference answers. SHA-224's different initial value is essential; truncating an ordinary SHA-256 result is incorrect.

The SHA-512 family shares an internal core with sixteen bounded 32-bit limbs: each 64-bit word is a high/low pair. Fixed sigma functions transfer bits between halves with constant factors and mask before multiplication. Low-word sums produce explicit carries for the corresponding high-word sums; no packed unsigned 64-bit intermediate is required. The four variants select distinct specified initial states and retain 12, 16, 7, or 8 output limbs for SHA-384, SHA-512, SHA-512/224, and SHA-512/256 respectively.

Its byte count uses four 32-bit limbs and permits at most 125 meaningful bits. The checked increment accepts a native array length, propagates carries, and rejects an overflow before state changes. Encoding shifts that count left by three into the specified 128-bit bit-length field. The local native suite checks these helpers at each limb carry, the maximum format length, invalid limb/count inputs, and negative increments without claiming to allocate an exabyte-scale message. Padding retains at most 127 bytes and constructs only the final one or two blocks.

## Shared holders and range copying

Incremental hash contexts are class instances with private mutable state. Passing a context allows callers to use the same object; it does not expose raw pointers, address arithmetic, or manual memory management. Each context still needs a single logical owner.

The public `STL.int_buffer` class in `stormlabs-stl` stores an immutable integer array and provides checked, indexed range copying. The yielding hasher creates one holder and reuses it across batches. Each call allocates only the requested output range. This avoids repeatedly passing the full input to the native `Slice` operation. It does not promise zero-copy input storage or a particular runtime allocation strategy.

In one UEFN 42.40 session, three samples extracting 1,024 bytes from a 1 MiB array had median `profile` times of 1,703.27 ms for `Slice` and 1.18 ms for the class-backed indexed reader. Across source sizes from 4 KiB through 1 MiB, the indexed reader's median stayed between 1.14 and 1.19 ms. The indexed reader outputs were verified against independent SHA-256 answers. These measurements describe this session, not all supported platforms or VM configurations.

## SHA-256 performance lessons

The original implementation spent most compression time in schedule expansion and the 64 rounds. Replacing generic rotations with the four fixed sigma functions removed repeated dispatch and powers-of-two table indexing. Equivalent choice and majority expressions reduce the Boolean operations per round, and digest encoding uses constant divisors. An earlier optimized implementation reduced an aligned 1 KiB update from a median 80.44 ms to 28.20 ms in local UEFN 42.40 CPU profiles. The crypto README records later measurements after shared-context extraction.

Eight-round unrolling improved an intermediate prototype by only about 6% while making register transitions harder to review, so the shipped implementation retains the simple 64-round loop. A fused rotation experiment using wider intermediates did not improve on that prototype and was discarded. Caching the round constants locally had little effect in the microbenchmark. These results favor specializing fixed arithmetic before adding a more complicated state representation.

The arithmetic suite checks all four sigmas against independent rotate/shift references across 324 distinct words, including zero, all ones, each one-hot and one-cold word, alternating bits, and frozen random values. It checks the actual word encoder over the same patterns. Historical generic-helper tests remain local with the baseline; they are replaced in the active suite by tests of the shipped arithmetic.

The default yielding batch is 128 bytes. A separate final-source probe measured seven samples per batch/pending-byte combination and checked all 196 resulting digests. After the shared-context extraction, its worst observed 128-byte update was 3.75 ms; copying, updating, and finalizing together reached 7.92 ms. The crypto README records the complete size table and measurement limits. SHA-256's 64-byte compression block and 32-byte digest stay fixed; message length and scheduling batch size are separate choices. More concurrent hashers still add work within an update.

These are single-configuration measurements. The sigma functions are algorithm-specific and stay in crypto; shared buffers and future general arithmetic should move into STL only with independently useful contracts and measured consumers.

## Repository and dependency boundaries

The repository is `stormlabs-verse`. Implemented libraries live under `libraries/stormlabs-*`, each with a README and `src/`. The root README lists available modules and dependencies. Install a selected package and its dependencies into the same Verse source folder; the repository's hyphenated library-directory names are not intended as installed Verse module identifiers.

`stormlabs-crypto` depends on `stormlabs-stl` for range copying. STL has no specialized-library dependencies. Crypto's public functions and context API remain unchanged by extraction. The holder accepts arbitrary integers; crypto remains responsible for rejecting values outside 0..255.

`stormlabs-encoding` owns strict UTF-8, Hex, Base64 and Base64URL and depends on STL's byte holder. `stormlabs-json` owns an immutable value model, parser, builders/editors and compact/pretty writers, using Encoding and STL. Existing crypto Hex functions remain for compatibility. Binary and Bits have no package dependencies; Bloom depends on Bits. Ordered, Search and Queues work independently of the other packages. Their ordered operations accept caller-supplied comparators. Queues also supplies immutable ring deques and persistent stacks; heap construction accepts an input array and custom comparator, with default-capacity and positional-capacity overloads.

Cache and Disjoint-set depend on Ordered. Cache maintains immutable key and recency indexes, with logarithmic abstract map work for ordinary operations and explicit counter rebasing. Disjoint-set uses ordered indexes for arbitrary caller-ordered elements and integer-indexed node tuples; union by size and full path compression apply to the returned snapshot. These representations preserve earlier container values but retain shallow references to caller objects. Their README complexity bounds include ordered-map costs; neither an O(1) LRU operation nor inverse-Ackermann whole-operation union-find performance is claimed.

Trie stores sorted token/child arrays, uses binary search at each node, and copies arrays along updated paths while sharing untouched subtrees. Its core accepts arbitrary token and payload types and has no other package dependency. Prefix enumeration follows the caller's token order and has an explicit result cap; updates preserve earlier snapshots. Wide nodes increase array-copy work, which is included in the performance plan. Optional text adapters must define their token representation explicitly.

The tested UEFN 42.40 compiler requires a provider-before-dependent-before-consumer layout for these generic compositions. Install numbered copies following the root README: independent providers at `00_`, their consumers at `10_`, JSON at `20_`, and application files at `90_`. Keep canonical repository filenames unchanged and use current bare public module names. All thirteen providers and the full Trie harness compiled in that layout; the full Cache and Union-find consumers passed separate numbered-layout compilation checks. Runtime evidence for those two packages used earlier diagnostic filenames with the same ordering and source bytes. This remains an installation workaround for the observed compiler, not a language guarantee; explicit imports and a library-only bundle did not remove the observed consumer-order sensitivity. No bundler is shipped.

Use one repository-wide MIT license and release version initially. Promote reusable helpers when contracts, validation, and real consumers justify them; avoid specialized dependencies in STL. No separate standard-library repository, package manager, or placeholder implementations are introduced.

Local evidence fingerprints tested source paths and bytes, including dependencies and importing consumers. Each new package must pass its own native correctness checks and applicable access controls, followed by compilation of the assembled source set. Unchanged crypto/STL evidence remains bound to its earlier verified implementation; adding an independent library does not rerun or redefine those results. Changes to crypto/STL behavior or their dependency boundary require the affected integration checks. Previous single-file runtime results remain historical evidence and do not verify changed source bytes.

## Verification before release

1. Compile small probes for bitwise intrinsics, exact division, effects, constrained integers, and module visibility using the installed UEFN toolchain. Establish the actual build command and digest versions first.
2. Check normalization, carries, logical shifts, and rotations at 0, 1, 31, 32, 33, 63, 64, and out-of-range counts. Cover all-zero, all-one, top-bit, and alternating-bit inputs. Check algebraic identities and compare against an independent reference.
3. Validate all six SHA-2 algorithms with published vectors. Include empty input, multi-block input, binary data, and padding boundaries at 55/56/63/64 bytes and 111/112/127/128 bytes. Check every relevant incremental split against one-shot output.
4. Test HMAC keys below, at, and above the compression block size; verify invalid tag handling. Test HKDF extract/expand, empty salt/info, and its output-length limit against published vectors and an independent reference.
5. Run the same observable-contract tests in every claimed supported VM mode. Record failures and unavailable modes without calling them passes.
6. Measure throughput, allocation behavior, update-size limits, and frame impact in UEFN. Benchmark before committing to a scheduling budget or adding a faster alternate representation.

Constant-time execution, secure erasure, audited security, and FIPS validation are separate claims and are not implied by passing known-answer tests. Future encryption APIs must enforce key/nonce/tag sizes, authenticate before releasing plaintext, and document how nonce uniqueness survives restarts and concurrent callers.

## Earlier SHA-2 verification

In earlier all-SHA-2 verification, the final-source UEFN run passed 25,244 digest comparisons and 1,297 behavior checks across all six variants. The four wide variants each matched all 129 NIST byte-oriented short-message and 128 long-message answers plus independent frozen messages, split boundaries, state/ownership/rollback cases, concurrent yielding calls, cancellation, and incremental/yielding inputs through 1 MiB. Arithmetic checks cover all four wide sigmas over 388 word pairs. Source manifests include both crypto and STL, and eight corrupt/incomplete/duplicate log controls were rejected.

Separate final-source CPU probes each checked 196 digests with seven samples per batch/pending-prefix combination. SHA-256's aligned 1 KiB update median was 27.90 ms; SHA-512's was 38.13 ms. Their worst observed 128-byte update samples were 3.83 ms and 5.27 ms. SHA-512 finalization can require two 128-byte blocks; the combined copy/update/finalize probe reached 15.83 ms at that batch size. The crypto README records complete size tables and limitations. These are observed samples from one configuration, not percentile bounds, cross-VM evidence, or a frame guarantee.

## Keyed SHA-2 design and verification

HMAC uses immutable, module-private precomputed inner and outer key states. Internal core snapshots clone state, pending bytes, counters and cache; each message owns mutable context state. Reset retains the key material. Validated factories create the public context through its internal constructor; six native compiler controls reject state access and direct construction.

HKDF reuses an HMAC context across expansion blocks and limits output to 255 digest lengths. Empty output still validates inputs. Yielding helpers bound long-key/IKM/info updates and return no partial output on failure or cancellation. A retained failed native probe exposed a transactional-update bug: negating a successful update rolls it back. The corrected implementation checks update success positively. Multiblock reference cases guard that behavior.

Earlier crypto/STL verification includes native evidence for 54,138 result comparisons and 2,451 behavior checks: seven complete full-suite partitions (51,805/1,983) plus two reduced-sampling HKDF partitions (2,333/468). Together these satisfy the reduced random-sampling coverage target of 22,042 comparisons and 2,435 checks. All nine reduced-sampling harnesses compiled without diagnostics; seven use the verified full-part coverage and were not independently runtime-executed as reduced-sampling harnesses. The original 72,826/2,483 exhaustive run remains incomplete. All six hash routes retain the full SHA-2 regression evidence and 1,301 HMAC pairs each. HKDF SHA-224/SHA-256 retain 1,053 cases per route; SHA-384/SHA-512/SHA-512/224/SHA-512/256 each passed 117 reduced-sampling cases: all 53 named/boundary inputs and 64 representative frozen random inputs. The reduced random-sampling coverage target preserves every non-random fixture, dedicated check and API route; its 48 fewer checks are repeated random zero-output confirmations. This reduces random sampling volume, while the exhaustive profile remains available. HKDF covers all six generic hash routes and the two named convenience wrappers, separate extract/expand/derive, raw PRK sizes, zero output with full input validation, partial/multiblock/maximum outputs, all 23 explicit batch sizes, defaults, concurrency, cancellation, and 1 MiB IKM/salt/info/raw PRK inputs. Larger outputs and maximum expansions were validated through yielding APIs using exact length and independent SHA-256 fingerprints; synchronous output validation above 257 bytes is not claimed. Published RFC 4231 HMAC tags cover SHA-224/256/384/512 (case 5 checks its published truncated prefix against the full reference); SHA-512/t HMAC answers use independent references. The three published RFC 5869 HKDF answers apply to SHA-256; corresponding inputs on the other five routes use independently derived answers. Six native compiler controls and 16 corrupt/incomplete/duplicate/failure log controls passed. Separate current-source CPU probes matched 196/196/504 results. Reused HMAC timing includes only Update + Finalize; factory/key preparation and Reset are excluded. Timing and editor-build provenance limits are recorded in the crypto README.
