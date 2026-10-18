# stormlabs-ordered

## Public API overview

See the complete [API reference](API.md) for public types, exact signatures,
effects, operations, examples, failure behavior and ownership.

Original MIT-licensed generic Verse ordered collections, module `Ordered`.

**Status: all thirteen libraries compile together and passed a bounded
13-group native smoke check. Earlier implementation-level results remain separate.
Experimental; performance is unmeasured.**

The library implements generic immutable ordered maps and sets with path-copy
left-leaning red-black insertion and deletion, lookups, ordered snapshots, bounds,
neighbors, and bounded ranges. Sets reuse the same map engine with `logic` values.
No library dependency, hash function, or specialized built-in key type is required.
The bounded local suite compiled and exercised multiple generic key/value types,
recursive nodes, and the documented effect signatures.

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Empty := Ordered.MakeMap(int, string, IntLess)
Map := Empty.With(7, "seven").With(2, "two")
if (Value := Map.Find[7]):
    Print(Value)

if (Removed := Map.Remove[7]):
    Remaining := Removed(0)
    OldEntry := Removed(1)
    Print("Removed {OldEntry.Value}; {Remaining.Count()} remains")
```

`ordered_map(key:type, value:type)` and `ordered_set(set_key:type)` accept
arbitrary key/value types. Caller `Less` has the same pure failable shape as
the installed native `SortBy` comparator:
`type {_(:key, :key)<computes><decides>:void}`. Success means the left key
precedes the right key. Keys are equivalent when neither direction succeeds;
Verse equality and hashability are not required. A custom class key can be
ordered by its immutable fields, including when it is not `comparable`.

The comparator must be a stable strict weak order: irreflexive, transitive,
and with transitive equivalence. Changing key fields used for ordering, or
changing ordering behavior after insertion, violates the precondition. Global
comparator correctness cannot be inferred from a few local calls.

The approved collection contract uses immutable value semantics. Updates
return new containers; originals remain valid. Snapshots and entries are shallow:
key/value class instances remain references to the caller's objects. No deep
copy, persistent storage, or frame-time guarantee is promised.

Map construction uses `MakeMap(key, value, Less)` or
`SingletonMap(key, value, Key, Value, Less)`. Set construction uses
`MakeSet(element, Less)` or `SingletonSet(element, Element, Less)`.
These explicit type arguments support independent instantiations such as
`ordered_map(int, string)` and `ordered_map(custom_key, custom_value)`.

| Operation | Map behavior | Set behavior |
| --- | --- | --- |
| `With` | Return a new map with key/value inserted or its equivalent value replaced | Return a new set containing the element |
| `Insert` | Return a new map; fail if an equivalent key exists | Return a new set; fail if an equivalent element exists |
| `Replace` | Return `(new_map, old_value)`; fail if missing | Not applicable |
| `Remove` | Return `(new_map, removed_entry)`; fail if missing | Return `(new_set, stored_element)`; fail if missing |
| `Find` | Return the value; fail if missing | Return the stored representative element; fail if missing |
| `GetEntry` | Return an immutable `ordered_entry(key, value)` with `Key`/`Value`; fail if missing | Not applicable |
| `Count` / `Clear` | Count entries / return an empty map with the same comparator | Count elements / return an empty set with the same comparator |
| `Entries` / `Elements` | Return a fresh ascending entry-array snapshot | Return a fresh ascending element-array snapshot |

Replacement retains the original representative key, even if a different key
object compares equivalent. Set `With` also retains the original representative.
Map values can themselves be `false`, options, arrays, classes, or records;
missing lookup is failure, independent of the stored value. Bind the returned
value before testing a Boolean value when distinguishing stored `false` matters.

`First` and `Last` return the minimum/maximum entry (set element), failing for
an empty container. `LowerBound(Key)` returns the first key not preceding the
query; `UpperBound(Key)` returns the first strictly following key.
`Predecessor(Key)` and `Successor(Key)` are strict neighbors of the query in
comparator order, whether or not the query exists. Missing bounds/neighbors fail.
Set bounds/neighbors return elements directly.

`Range[Lower, Upper, MaxResults]` returns an ascending prefix from the half-open
interval `[Lower, Upper)` in comparator order. The explicit `MaxResults` cap is
required; zero returns an empty array. Equivalent endpoints produce an empty
range. Negative caps and reversed bounds fail. A cap can truncate the interval;
request a larger cap when all matches are required. There are no live iterators
or invalidation rules: returned arrays and earlier containers remain snapshots.

`Count` uses `<computes>`. Other operations and factories use `<transacts>`;
failable operations additionally use `<decides>` and square-bracket calls.
Public effects are part of the contract. No operation mutates an existing
container. Assign a returned version to the caller's variable explicitly;
assignments made in a failed Verse transaction roll back normally.

For a valid ordering, red-black properties bound the tree height by
`2 log2(n + 1)`. Abstract node visits and comparator calls for search/update/
bounds are `O(log n)`; updates allocate `O(log n)` replacement nodes and share
untouched subtrees. Count/clear use constant tree work. Ordered traversal visits
`O(n)` nodes; a range visits `O(log n + k)` nodes for `k` results. These are
algorithmic node/comparison bounds, not measured Verse execution/allocation costs.
Snapshot assembly concatenates Verse arrays; the runtime's copying and garbage
collection costs, comparator costs, and retained-version memory must be measured
in the target island before making performance claims.

The implementation is original Verse code informed by the standard
[left-leaning red-black tree algorithm](https://sedgewick.io/research/).
No implementation source was copied or translated. Both insertion and deletion
repair colors/rotations, and every returned nonempty root is black. The ignored
local verification assets include a test-only internal bridge checking black
roots, red-red edges, left leaning, equal black height, strict BST bounds, and
cached subtree counts, plus short deterministic operations against independent
sorted expected states. Host reference checks do not establish Verse correctness.

The current bare namespaces compiled together in UEFN 42.40 CL59247843. The
local public consumer passed all 13 module groups
with zero failures and complete, unique records. This bounded integration check
is not a rerun of the historical full suites or a performance benchmark.

The verification below predates the bare-namespace refresh and binds its
original source bytes. It does not verify the renamed sources.

The earlier implementation compiled without diagnostics in UEFN 42.40 CL59247843. The local run passed all 410 assertions with zero failures, including
tree invariants, insertion/deletion sequences, independent expected states,
snapshots, comparator equivalence, bounds, ranges, sets, and transaction rollback.
The strict log verifier required all expected unique checks and complete
BEGIN/END records. An earlier throttled capture was incomplete and is not used
as passing evidence.

Five separate negative compiler controls rejected external map/set/entry
construction and access to map root/set core with only the expected internal
access diagnostics. The exact positive provider and wrapper were restored and
compiled without diagnostics afterward. These results cover the tested local
environment; the VM mode was not independently established. Performance probes,
allocation costs, other environments, and exhaustive comparator/input coverage
remain unverified. Test bridges, wrappers, vectors, and logs are ignored local
artifacts and are not part of the shipped library.

The repository source remains `src/stormlabs_ordered.verse`. For installation,
copy it into your Verse source folder as `00_stormlabs_ordered.verse`. Keep each
library in its own file and import `Ordered` through that folder's
project-specific Verse module path. The prefix applies to the installed copy;
the canonical filename stays unchanged and the public module is now `Ordered`.

Use the tested library-before-application filename convention for dependencies
in the same folder:

| Prefix | Installed files |
| --- | --- |
| `00_` | Binary, Bits, Ordered, STL; for example `00_stormlabs_ordered.verse` |
| `10_` | Bloom, Cache, Crypto, Disjoint Set, Encoding, Queues, Search, Trie |
| `20_` | JSON; for example `20_stormlabs_json.verse` |
| `90_` | Application code; for example `90_game.verse` |

Copy only the libraries your application needs, preserving these dependency
tiers. This is a tested UEFN 42.40 CL59247843 workaround for source-file ordering;
it supplies no Verse language ordering guarantee. The numbered twelve-library
host and its full Cache/Disjoint Set consumers compiled without diagnostics in
that environment. Other toolchain versions and folder layouts remain unverified.
The distributed library sources remain separate canonical files.

Follow [Epic's Verse style guide](https://dev.epicgames.com/documentation/fortnite/verse-code-style-guide-in-unreal-editor-for-fortnite?lang=en-US).
