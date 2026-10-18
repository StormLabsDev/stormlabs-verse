# stormlabs-verse

Thirteen native Verse source libraries for UEFN, by StormLabs. Copy the modules
you need into your project; no package manager, runtime download, external
cryptography service or custom C++ bindings are required.

**Experimental.** All thirteen modules compiled together and passed a bounded
13-group native smoke check in UEFN 42.40 CL59247843 on 2026-10-18 UTC.
Earlier implementation-level suites provide broader coverage, but were not
rerun after the public namespace change. Cryptography is unaudited and the
collection/encoding libraries have no measured native performance guarantees.

Browse the [API catalog](docs/API.md), read the [design notes](docs/architecture.md),
or see [CONTRIBUTING.md](CONTRIBUTING.md) to build and verify a change.

## Choose a library

| Library | Verse module | Available functionality | Dependencies |
| --- | --- | --- | --- |
| [stormlabs-stl](libraries/stormlabs-stl/README.md) | `STL` | Immutable integer-array holders and checked range copying | None |
| [stormlabs-crypto](libraries/stormlabs-crypto/README.md) | `Crypto` | All six SHA-2 variants, HMAC, HKDF, incremental and yielding APIs, Hex | stormlabs-stl |
| [stormlabs-binary](libraries/stormlabs-binary/README.md) | `Binary` | Fixed-width words, shifts/rotations, endian conversion, checked byte buffers/readers/writers | None |
| [stormlabs-bits](libraries/stormlabs-bits/README.md) | `Bits` | Fixed and growable packed bitsets, ranges, searches, set algebra, byte serialization | None |
| [stormlabs-encoding](libraries/stormlabs-encoding/README.md) | `Encoding` | Strict UTF-8, Hex, Base64 and Base64URL | stormlabs-stl |
| [stormlabs-json](libraries/stormlabs-json/README.md) | `JSON` | Immutable values, parsing, builders/editors, compact/pretty output, limits and diagnostics | stormlabs-encoding, stormlabs-stl |
| [stormlabs-ordered](libraries/stormlabs-ordered/README.md) | `Ordered` | Generic red-black ordered maps/sets, bounds, neighbors and range traversal | None |
| [stormlabs-bloom](libraries/stormlabs-bloom/README.md) | `Bloom` | Generic Bloom filters with caller-supplied hashing, cloning and rollback | stormlabs-bits |
| [stormlabs-search](libraries/stormlabs-search/README.md) | `Search` | Generic binary search, lower/upper bounds and equal ranges over ordered arrays | None |
| [stormlabs-queues](libraries/stormlabs-queues/README.md) | `Queues` | Generic heap priority queues, ring deques and persistent stacks | None |
| [stormlabs-cache](libraries/stormlabs-cache/README.md) | `Cache` | Generic immutable bounded LRU cache with recency, eviction and snapshots | stormlabs-ordered |
| [stormlabs-disjoint-set](libraries/stormlabs-disjoint-set/README.md) | `DisjointSet` | Generic immutable union-find with union by size and full path compression | stormlabs-ordered |
| [stormlabs-trie](libraries/stormlabs-trie/README.md) | `Trie` | Generic immutable sequence-key trie, exact/prefix lookup and bounded ordered enumeration | None |

For structured settings or interchange, start with JSON and Encoding. For
gameplay collections, choose Ordered, Queues or Cache; use DisjointSet for
connected components and Trie for sequence-key prefix/autocomplete lookup.
Binary/Bits handle byte formats and packed flags. Search operates on already
ordered arrays; Bloom provides approximate membership. Crypto supplies hashing,
message authentication and key derivation.

Copy only your chosen modules and their transitive dependencies. JSON needs
Encoding and STL; Cache/DisjointSet need Ordered; Bloom needs Bits.
Hex is available independently in Encoding and through Crypto's existing
helpers. Trie accepts arbitrary tokens; text adapters must explicitly choose
UTF-8 bytes or Unicode scalars and add Encoding when needed.

## Repository layout

```text
README.md
CONTRIBUTING.md
LICENSE
docs/
  API.md
  architecture.md
libraries/
  stormlabs-binary/
  stormlabs-bits/
  stormlabs-bloom/
  stormlabs-cache/
  stormlabs-crypto/
  stormlabs-disjoint-set/
  stormlabs-encoding/
  stormlabs-json/
  stormlabs-ordered/
  stormlabs-queues/
  stormlabs-search/
  stormlabs-stl/
  stormlabs-trie/
```

Each library contains a README for setup/contracts, a complete API reference,
and one canonical Verse source. For example:

```text
libraries/stormlabs-json/
  README.md
  API.md
  src/
    stormlabs_json.verse
```

Folders and filenames retain the `stormlabs-` branding. Public Verse namespaces
are the bare names in the table, such as `JSON`, `Ordered` and `Crypto`.

## Installation

Copy each selected source and its dependencies into the **same Verse source
folder** in your UEFN project, for example `Libraries`. Apply these prefixes to
the installed copies; keep the repository's canonical filenames unchanged.

| Installed source filenames | Purpose |
| --- | --- |
| `00_stormlabs_binary.verse`, `00_stormlabs_bits.verse`, `00_stormlabs_ordered.verse`, `00_stormlabs_stl.verse` | Independent providers |
| `10_stormlabs_bloom.verse`, `10_stormlabs_cache.verse`, `10_stormlabs_crypto.verse`, `10_stormlabs_disjoint_set.verse`, `10_stormlabs_encoding.verse`, `10_stormlabs_queues.verse`, `10_stormlabs_search.verse`, `10_stormlabs_trie.verse` | Other libraries, after their required providers |
| `20_stormlabs_json.verse` | JSON, after Encoding and STL |
| `90_game.verse` or similarly ordered application filenames | Your consumers, after the installed libraries |

For JSON, install `00_stormlabs_stl.verse`, `10_stormlabs_encoding.verse`, and
`20_stormlabs_json.verse`. For hashing, install
[STL](libraries/stormlabs-stl/src/stormlabs_stl.verse) as `00_stormlabs_stl.verse`
and [Crypto](libraries/stormlabs-crypto/src/stormlabs_crypto.verse) as
`10_stormlabs_crypto.verse`.

UEFN 42.40 exposed processing-order failures for generic providers and their
consumers under other filenames. All thirteen modules and representative
consumers compiled with this numbered layout. It is a tested compiler-version
workaround, **not a Verse language guarantee of file order**; recheck after
toolchain or consumer changes. Imports alone did not resolve the observed
failures.

Keep each library in a separate source file. Your containing project folder
contributes to the import path. Consumers outside it must import the module
using their own project's Verse path; no account-specific path is embedded.
Build using **Verse > Build Verse Code** in UEFN.

## Usage and ownership

These calls belong inside a caller function with the modules visible.
Failable functions use square brackets in a failure context:

```verse
if (Digest := Crypto.SHA256Hex[array{97, 98, 99}]):
    Print(Digest)

Parsed := JSON.Parse("[null,true,1.2300e+004]")
if (Value := Parsed.Value[]):
    Written := JSON.Write(Value, ?Pretty := true)
    if (Text := Written.Text[]):
        Print(Text)
```

Ordered operations accept caller-provided comparators. Comparison succeeds when
the left key precedes the right key; it must be a stable strict weak order.
Equivalence means neither direction succeeds, so custom class keys do not need
hashing or native equality.

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Before := Ordered.MakeMap(int, string, IntLess)
After := Before.With(2, "two").With(1, "one")
# Before remains empty; After contains both entries.
```

Ordered, Queues, Cache, DisjointSet and Trie return new immutable generic
containers. Retain the returned value to keep an update; earlier values remain
snapshots. JSON edits also return new immutable values. Class keys/payloads are
shallow references, so keep comparator/hash-relevant fields stable while stored.

Binary buffers/readers/writers, Bits, Bloom and cryptographic contexts instead
have mutable state and explicit ownership rules. Aliasing shares state; use
documented cloning or separate instances for independent owners. A transactional
mutation is rolled back when it is negated or its failure context fails. A
successfully returned Boolean `false` is distinct from a missing value.
See each API for exact effects, failure behavior and scheduling requirements.

## Validation and performance

The 2026-10-18 UTC assembled check passed 13 named module groups, covering
representative generic types, comparator equivalence, snapshots, selected
invalid inputs and short SHA-256/SHA-512/HMAC/HKDF known answers. It is a bounded
integration smoke check, not exhaustive validation or a benchmark.

Earlier local suites, before the namespace change, passed Binary/Bits:
107 groups; Encoding: 119 checks; JSON: 163 checks; Ordered: 410 checks; Bloom:
6 groups; Search: 5 groups; Queues: 20 groups; Cache: 6 groups; DisjointSet:
17 groups; Trie: 206 checks. Groups and individual checks are different units
and are not combined into a total. Constructor/internal-state compiler controls
also passed. Module READMEs describe their coverage and remaining limits.

Earlier crypto/STL verification includes 54,138 result comparisons and
2,451 behavior checks. Its larger exhaustive sampling run remains incomplete;
the completed coverage retains published vectors, boundary cases and every API
route with reduced random repetition for four HKDF variants.
The [Crypto README](libraries/stormlabs-crypto/README.md) gives the exact scope.

Historical local CPU samples measured an aligned 1,024-byte SHA-256 update at
a median 27.18 ms, compared with 80.44 ms before optimization; SHA-512 measured
38.19 ms. These samples describe one UEFN configuration, predate the namespace
change and are not frame budgets or cross-platform guarantees. Yielding crypto
entry points default to 128-byte batches and accept 1..4,096. Collection and
encoding packages have no native timing or allocation results.

No public automated suite is bundled. Test devices, vectors, reference tools,
benchmarks and machine-specific evidence remain local. Contributors can create
focused reproductions using the [manual verification guide](CONTRIBUTING.md#verification).
Passing checks does not establish audited cryptography, constant-time execution,
secure erasure, FIPS validation, cross-VM compatibility or a frame-time guarantee.
The tested Verse VM variant was not independently identified.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style, API compatibility,
focused correctness checks, performance evidence and useful bug reports.
Additional algorithms are future work, not promised features or release dates.

## License

[MIT](LICENSE), copyright 2026 StormLabs. Use, modification, redistribution and
commercial use are permitted with the required copyright and permission notice.
The software is provided **AS IS**, without warranty.
