# stormlabs-trie

## Public API overview

See the complete [API reference](API.md) for public types, exact signatures,
effects, operations, examples, failure behavior and ownership.

Original MIT-licensed generic sequence-key trie, module `Trie`.

**Status: all thirteen libraries compile together and passed a bounded
13-group native smoke check. Earlier implementation-level results remain separate.
Experimental; performance is unmeasured.**

The library supplies generic `trie(token, value)` and immutable
`trie_entry(token, value)`, functional insertion/replacement/removal, exact and
prefix lookups, subtree counts, and bounded deterministic enumeration. Each node
stores sorted parallel token/child arrays. Binary search locates a child;
updates copy arrays along the changed path and share untouched child nodes.

Keys are `[]token`, payloads are any `value`, and the caller supplies
`type {_(:token, :token)<computes><decides>:void}`. Success means the left token
precedes the right token. The comparator must be a stable strict weak order.
Tokens are equivalent when neither comparison succeeds; equivalent keys have
equal length and equivalent tokens at every position. Hashing and Verse equality
are not required, including for custom class tokens.

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Empty := Trie.MakeTrie(int, string, IntLess)
Words := Empty.With(array{1, 2}, "example")
if (Value := Words.Find[array{1, 2}]):
    Print(Value)
```

`With` returns a new trie and retains the original complete key representation
when replacing an equivalent key. Earlier tries remain snapshots. An empty key
is valid and distinct from every extension. Missing keys and nonterminal prefixes
fail lookup; a stored Boolean `false` remains a successful returned value.
Entries/arrays are immutable snapshots, with shallow references for class tokens
and payloads. Do not mutate token fields used by the comparator while stored.

`Insert[Key, Value]` returns a new trie and fails if an equivalent complete key
already exists. A nonterminal prefix is available for insertion.
`Replace[Key, Value]` returns `(new_trie, old_value)` and fails for a missing
key/nonterminal. `Remove[Key]` returns `(new_trie, removed_entry)`, fails when
missing/nonterminal, and prunes every newly empty child path. Removing a terminal
prefix preserves its extensions; removing the empty key preserves other keys.
`Clear()` returns an empty trie with the same comparator. `Contains[Key]` is a
failable exact-key test, independent of the payload value.

`PrefixCount(Prefix)` returns the number of stored complete keys beginning with
the prefix, or zero for a missing prefix. Empty-prefix count equals total count.
`Enumerate[Prefix, MaxResults]` returns the first matching entries in
lexicographic token order. Terminal prefixes precede extensions; siblings follow
the caller's token ordering. The explicit cap is required and truncates the
result to at most `MaxResults` entries. `PrefixCount(Prefix) > Results.Length`
identifies truncation. Negative caps fail; zero caps and missing prefixes return
empty arrays. Enumeration returns a snapshot, without live iterators.

Updates use linked path frames and enumeration uses cursor frames rather than
recurse by key length. Cursors retain their parent node and a child index.
The result cap bounds returned entries, not all work
needed to reach them: a long nonterminal chain may precede its first result.
Keys are native arrays with no additional arbitrary token-length cap. Callers
must bound external input and choose appropriate key lengths/counts for their
island's synchronous execution budget. There is no suspending wrapper or yield
inside an operation; a caller may yield between operations.

`Count` uses `<computes>`. Other operations use `<transacts>`, additionally
`<decides>` for `Find`, `GetEntry`, `Contains`, `Insert`, `Replace`, `Remove`,
and `Enumerate`. Public effects are part of the API. Explicit caller assignment
to a returned trie follows normal Verse transaction rollback; no existing trie
is mutated.

Copy `src/stormlabs_trie.verse` into your Verse source folder as
`10_stormlabs_trie.verse`, with application files afterward, such as
`90_game.verse`. The repository source filename stays unchanged; the public
module is now `Trie`. See the root [installation guidance](../../README.md#installation).
This implementation has no other StormLabs dependency. The numbered naming
convention is a local UEFN 42.40 CL59247843 workaround, without a Verse language
ordering guarantee.

The generic core has no text/Unicode dependency. String adapters must choose a
token meaning explicitly. Unicode-scalar keys can use `trie(int, value)` with
strict `Encoding.UTF8ToCodePoints` conversion before insertion/query;
optional text adapters therefore depend on `stormlabs-encoding`. UTF-8 byte keys
and Unicode scalar keys are different representations. Verse `char` code units
must not be described as Unicode scalars. No normalization or case folding is
performed by the core.

For key length `L` and child degrees `d_i`, abstract lookup comparison work is
`O(L + sum(log(d_i + 1)))`. Updates also copy `O(sum d_i)` child-array elements
along the path, including when replacing a value beneath a wide branch. Inserting
or pruning a child copies both parallel arrays; replacing a child retains the
token array and copies its child array. Updates allocate `O(L)` trie/path nodes
and share untouched subtrees. Wide branches therefore have linear update-copy
cost in their degree.

Enumeration visits the nodes needed for its capped prefix in depth-first order
and advances through child indices. It does not collect every sibling first.
Count/clear use constant trie work. These are structural bounds, not measured
Verse timings or allocation guarantees; array assembly, key storage, class
references, and garbage collection have runtime costs. The ignored performance
plans cover geometric sizes, wide branches, common versus disjoint prefixes,
output caps, long keys, and retained versions. Performance probes are prepared;
no performance measurements have been collected.

The current bare namespaces compiled together in UEFN 42.40 CL59247843. The
local public consumer passed all 13 module groups
with zero failures and complete, unique records. This bounded integration check
is not a rerun of the historical full suites or a performance benchmark.

The verification below predates the bare-namespace refresh and binds its
original source bytes. It does not verify the renamed sources.

The earlier implementation was checked in a local Windows UEFN 42.40 CL59247843 host. Its exact source prefix
with a test-only invariant audit compiled without diagnostics. The local run passed all 206 assertions with zero failures. The strict log
verifier required every expected unique check and complete BEGIN/END records;
no missing, duplicate, unknown, or failed records were present.

The bounded suite covers deterministic insert/overwrite/remove sequences,
empty keys, missing and nonterminal prefixes, prefix caps, pruning, retained
snapshots, rollback, reverse ordering, integer/string payloads, and custom class
tokens with comparator equivalence and Boolean payloads. Structural checks
cover matching parallel-array lengths, strict child ordering, positive child
counts, cached subtree counts, and terminal paths matching whole keys.

A separate public consumer compiled against the exact bare production source.
Four negative compiler controls rejected direct trie construction, direct entry
construction, internal root access, and internal comparator access with only
the expected access diagnostics. The bare positive consumer was restored and
compiled without diagnostics afterward.

These results cover the tested environment and fixtures. The VM mode was not
independently established. Maximum-size keys/branches, exhaustive input coverage,
other environments, frame budgets, allocation costs, and performance remain
unverified. Test wrappers, audits, probes, and captures are ignored local artifacts
and are not library dependencies.

The source follows [Epic's Verse style guide](https://dev.epicgames.com/documentation/fortnite/verse-code-style-guide-in-unreal-editor-for-fortnite?lang=en-US).
No persistent-storage or measured performance guarantee is made.
