# Trie API

## Overview

Generic immutable sequence-key prefix trees with sorted parallel child
arrays. Keys are []token and payloads any caller-selected type. The comparator
is a pure failable strict weak token order; equivalence means neither direction
succeeds. No package dependency. See the [README](README.md).

Public signatures below omit implementation bodies and retain exact effects,
optional defaults and constructor visibility. Failable calls use [];
other calls use ().

```verse
Trie<public> := module:
```

## Types and constructors

Both classes have internal constructors. `MakeTrie` creates an empty
container and retains its comparator. Entry fields/arrays are immutable
snapshots; class token/payload references remain shallow.

```verse
trie_entry<public>(token:type, value:type) := class<internal><final>:
    Key<public>:[]token
    Value<public>:value
```

```verse
trie<public>(token:type, value:type) := class<internal><final>:
    Count<public>()<computes>:int
    GetEntry<public>(Key:[]token)<transacts><decides>:trie_entry(token, value)
    Find<public>(Key:[]token)<transacts><decides>:value
    Contains<public>(Key:[]token)<transacts><decides>:void
    With<public>(Key:[]token, Value:value)<transacts>:trie(token, value)
    Insert<public>(Key:[]token, Value:value)<transacts><decides>:trie(token, value)
    Replace<public>(Key:[]token, Value:value)<transacts><decides>:tuple(trie(token, value), value)
    Remove<public>(Key:[]token)<transacts><decides>:tuple(trie(token, value), trie_entry(token, value))
    Clear<public>()<transacts>:trie(token, value)
    PrefixCount<public>(Prefix:[]token)<transacts>:int
    Enumerate<public>(Prefix:[]token, MaxResults:int)<transacts><decides>:[]trie_entry(token, value)
```

Module factories and functions:

```verse
MakeTrie<public>(token:type, value:type, Less:type {_(:token, :token)<computes><decides>:void})<transacts>:trie(token, value)
```

## Operations

| Operations | Behavior |
| --- | --- |
| `Count`, `Clear` | Number of complete keys; new empty trie retaining comparator. |
| `GetEntry`, `Find`, `Contains` | Exact complete-key lookup; missing/nonterminal prefixes fail. Stored Boolean false remains a successful payload. |
| `With` | Insert/overwrite; replacement retains the original complete representative key. |
| `Insert` | Fail on an equivalent complete key; an unoccupied nonterminal prefix is available. |
| `Replace` | Require a complete key; return `(new_trie, old_value)`. |
| `Remove` | Require a complete key; return `(new_trie, removed_entry)` and prune newly empty branches. |
| `PrefixCount` | Complete keys under prefix; missing0, empty prefix equals total. |
| `Enumerate` | First up to MaxResults entries under prefix, lexicographic order, terminal before extensions. |

Empty keys are valid. Complete-key equivalence requires equal length and
tokenwise equivalence. Negative caps fail; cap0/missing prefixes return empty.
Compare PrefixCount(Prefix) with output length for explicit truncation detection.
Result caps bound output, not total traversal work.

## Examples

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Before := Trie.MakeTrie(int, string, IntLess)
After := Before.With(array{1}, "prefix").With(array{1, 2}, "extension")
if (Entries := After.Enumerate[array{1}, 1]):
    if (Entry := Entries[0]):
        Print(Entry.Value)
    if (After.PrefixCount(array{1}) > Entries.Length):
        Print("More matches")
```

## Failure and cost notes

Updates preserve prior values; caller assignment follows transaction rollback.
Keep comparator-relevant class state stable while stored. There is no implicit
text token meaning, Unicode normalization or case folding. UTF-8 bytes and
Unicode scalars are distinct key choices; explicit Encoding conversion can
adapt text to scalar-token keys.

For key length L and child degrees d_i, lookup comparisons take
O(L + sum(log(d_i+1))). Updates also copy O(sum d_i) child-array entries along
the path, including replacement below wide branches. Untouched child nodes are
shared. Traversal, update reconstruction and enumeration use iterative frames.
Long nonterminal chains still take work before the first result. Native array
assembly, allocations/GC and frame costs are unmeasured. Callers must bound
external key counts/lengths; no extra arbitrary length cap or persistence
guarantee is provided.

The thirteen modules compiled together and passed the source-bound
13-group public-consumer smoke check in UEFN 42.40 CL59247843. Historical full
suites in the README remain bound to their original bytes and were not rerun.
This short integration check supplies no performance measurements.
