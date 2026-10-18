# Ordered API

## Overview

Generic immutable left-leaning red-black maps and sets. Caller comparison
succeeds when the left key precedes the right key and must be a stable strict
weak order. Equivalence means neither direction succeeds; no hashing or Verse
equality is required. No package dependencies. See the [README](README.md).

Public signatures below omit implementation bodies and retain exact effects,
optional defaults and constructor visibility. Failable calls use [];
other calls use ().

```verse
Ordered<public> := module:
```

## Types and constructors

All three classes have internal constructors. Use `MakeMap`/`MakeSet` for
empty containers and `SingletonMap`/`SingletonSet` for one-entry containers.
The comparator is retained by returned versions. Entry fields are immutable.

```verse
ordered_entry<public>(key:type, value:type) := class<internal><final>:
    Key<public>:key
    Value<public>:value
```

```verse
ordered_map<public>(key:type, value:type) := class<internal><final>:
    Count<public>()<computes>:int
    GetEntry<public>(Key:key)<transacts><decides>:ordered_entry(key, value)
    Find<public>(Key:key)<transacts><decides>:value
    With<public>(Key:key, Value:value)<transacts>:ordered_map(key, value)
    Insert<public>(Key:key, Value:value)<transacts><decides>:ordered_map(key, value)
    Replace<public>(Key:key, Value:value)<transacts><decides>:tuple(ordered_map(key, value), value)
    Clear<public>()<transacts>:ordered_map(key, value)
    Remove<public>(Key:key)<transacts><decides>:tuple(ordered_map(key, value), ordered_entry(key, value))
    First<public>()<transacts><decides>:ordered_entry(key, value)
    Last<public>()<transacts><decides>:ordered_entry(key, value)
    LowerBound<public>(Key:key)<transacts><decides>:ordered_entry(key, value)
    UpperBound<public>(Key:key)<transacts><decides>:ordered_entry(key, value)
    Successor<public>(Key:key)<transacts><decides>:ordered_entry(key, value)
    Predecessor<public>(Key:key)<transacts><decides>:ordered_entry(key, value)
    Entries<public>()<transacts>:[]ordered_entry(key, value)
    Range<public>(Lower:key, Upper:key, MaxResults:int)<transacts><decides>:[]ordered_entry(key, value)
```

```verse
ordered_set<public>(set_key:type) := class<internal><final>:
    Count<public>()<computes>:int
    Find<public>(Element:set_key)<transacts><decides>:set_key
    Contains<public>(Element:set_key)<transacts><decides>:void
    With<public>(Element:set_key)<transacts>:ordered_set(set_key)
    Insert<public>(Element:set_key)<transacts><decides>:ordered_set(set_key)
    Remove<public>(Element:set_key)<transacts><decides>:tuple(ordered_set(set_key), set_key)
    Clear<public>()<transacts>:ordered_set(set_key)
    Elements<public>()<transacts>:[]set_key
    First<public>()<transacts><decides>:set_key
    Last<public>()<transacts><decides>:set_key
    LowerBound<public>(Element:set_key)<transacts><decides>:set_key
    UpperBound<public>(Element:set_key)<transacts><decides>:set_key
    Predecessor<public>(Element:set_key)<transacts><decides>:set_key
    Successor<public>(Element:set_key)<transacts><decides>:set_key
    Range<public>(Lower:set_key, Upper:set_key, MaxResults:int)<transacts><decides>:[]set_key
```

Module factories and functions:

```verse
MakeMap<public>(key:type, value:type, Less:type {_(:key, :key)<computes><decides>:void})<transacts>:ordered_map(key, value)
SingletonMap<public>(key:type, value:type, Key:key, Value:value, Less:type {_(:key, :key)<computes><decides>:void})<transacts>:ordered_map(key, value)
MakeSet<public>(set_key:type, Less:type {_(:set_key, :set_key)<computes><decides>:void})<transacts>:ordered_set(set_key)
SingletonSet<public>(set_key:type, Element:set_key, Less:type {_(:set_key, :set_key)<computes><decides>:void})<transacts>:ordered_set(set_key)
```

## Operations

| Operations | Behavior |
| --- | --- |
| `Find`, map `GetEntry`, set `Contains` | Exact-equivalence lookup. Map Find returns the value; set Find returns the stored representative. Missing keys fail. |
| `With` | Insert/replace and return a new container; retain an existing representative key. Set insertion is idempotent by equivalence. |
| `Insert` | Fail if an equivalent key exists. |
| Map `Replace` | Require a key; return `(new_map, old_value)`. |
| `Remove` | Require a key; return `(new_map, removed_entry)` or `(new_set, removed_representative)`. |
| `Count`, `Clear` | Count entries; return an empty container retaining its comparator. |
| `Entries`, `Elements` | Complete snapshot in comparator order. |
| `First`, `Last` | Least/greatest entry or representative; empty containers fail. |
| `LowerBound`, `UpperBound` | Least key not preceding the query / strictly following it. Fail when no candidate exists. |
| `Predecessor`, `Successor` | Greatest strictly preceding / least strictly following key. Query need not exist. |
| `Range` | Ordered prefix up to MaxResults in half-open comparator interval [Lower,Upper). |

Range fails for a negative cap or Upper preceding Lower. Cap0/equal bounds
return empty. The cap truncates to a prefix without an overflow flag; request a
larger cap or continue via bounds when a complete export is needed.

## Examples

```verse
IntLess(Left:int, Right:int)<computes><decides>:void =
    Left < Right

Before := Ordered.MakeMap(int, string, IntLess)
After := Before.With(2, "two").With(1, "one")
if (Entry := After.LowerBound[1]):
    Print(Entry.Value)
if (Removed := After.Remove[2]):
    Remaining := Removed(0)
    Print("{Remaining.Count()}")
# Before is empty; After still contains both entries.
```

## Failure and cost notes

Updates return new immutable values; assigning them inside failure contexts
follows normal Verse rollback. Class keys/payloads are shallow references.
Do not mutate comparator-relevant state while stored. Invalid comparators
violate a precondition; no checked recovery is promised.

Insertion and deletion rebalance the red-black tree. Abstract lookup/update
work is O(log n) node/comparator operations and path-copy nodes, assuming bounded
comparator cost. Count/clear use constant tree work. Exports/ranges visit the
needed portion and concatenate arrays; native copying, allocation/GC and wall
costs are unmeasured. Do not interpret abstract traversal work as a proven
linear export time or a frame budget. No persistence promise is made.

The thirteen modules compiled together and passed the source-bound
13-group public-consumer smoke check in UEFN 42.40 CL59247843. Historical full
suites in the README remain bound to their original bytes and were not rerun.
This short integration check supplies no performance measurements.
