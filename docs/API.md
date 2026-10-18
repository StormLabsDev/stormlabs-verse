# Public API catalog

All thirteen modules use the root [MIT license](../LICENSE). Bare public
namespaces have no old-name aliases; branded folders/files remain unchanged.
Install each selected package and its dependency closure using the
[numbered source layout](../README.md#installation). Project folders contribute
to import paths; no account-specific Verse path is embedded.

| Complete API reference | Purpose | Dependencies |
| --- | --- | --- |
| [STL](../libraries/stormlabs-stl/API.md) | Immutable integer-array holder; checked copying | None |
| [Crypto](../libraries/stormlabs-crypto/API.md) | SHA-2, HMAC, HKDF, streaming/yielding operations | STL |
| [Binary](../libraries/stormlabs-binary/API.md) | Words, shifts, endian conversion, byte buffers | None |
| [Bits](../libraries/stormlabs-bits/API.md) | Packed mutable bitsets and set algebra | None |
| [Encoding](../libraries/stormlabs-encoding/API.md) | Strict UTF-8, Hex, Base64/Base64URL | STL |
| [JSON](../libraries/stormlabs-json/API.md) | Immutable JSON values, parser, editors, writer | Encoding, STL |
| [Ordered](../libraries/stormlabs-ordered/API.md) | Generic immutable red-black maps/sets | None |
| [Bloom](../libraries/stormlabs-bloom/API.md) | Generic mutable Bloom filters | Bits |
| [Search](../libraries/stormlabs-search/API.md) | Generic binary search and array bounds | None |
| [Queues](../libraries/stormlabs-queues/API.md) | Generic immutable heap, deque, stack | None |
| [Cache](../libraries/stormlabs-cache/API.md) | Generic immutable indexed LRU cache | Ordered |
| [DisjointSet](../libraries/stormlabs-disjoint-set/API.md) | Generic immutable union-find | Ordered |
| [Trie](../libraries/stormlabs-trie/API.md) | Generic immutable sequence-token prefix tree | None |

## Calls and ownership

References include exact public signatures/effects/defaults, constructors,
methods, fields, enum variants and examples. Failable functions have `<decides>`
and use square brackets in a failure context. A successful Boolean false is
distinct from a missing value. Transactional updates follow rollback rules;
negating a successful mutation rolls it back.

Ordered, Queues, Cache, DisjointSet and Trie return new generic container values;
retain/assign returned values deliberately. Class payloads/keys remain shallow
references. Keep comparator/hash-relevant fields stable while stored. Bits,
Bloom, byte readers/writers and cryptographic contexts instead have mutable
ownership rules in their own API references.

UTF-8 bytes, Verse char code units and Unicode scalars are different interfaces.
Use Encoding conversions explicitly; no text normalization or case folding is
implied by JSON or Trie.

## Validation scope

The thirteen modules compiled together without diagnostics and passed
all 13 source-bound public-consumer smoke groups in UEFN 42.40 CL59247843. This
short integration check is not a benchmark or a rerun of historical full suites,
which remain bound to their earlier exact source and harness bytes. New-library
timing remains unmeasured. See package READMEs and the
[architecture notes](architecture.md) for bounded evidence and limitations.
