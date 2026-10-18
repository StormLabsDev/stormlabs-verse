# stormlabs-bloom

Generic insertion-only Bloom membership filters for Verse, under the repository-wide [MIT License](../../LICENSE).

## Public API

`Bloom.MakeBloomFilter` creates a generic membership prefilter with Insert/MightContain, Clear and independent Clone. See [API.md](API.md) for exact effects, limits, hash consistency and mutable ownership.

**Current validation: the thirteen libraries compiled together without diagnostics and passed the 13-group public API smoke on 2026-10-18 UTC. This bounded smoke is not a full-suite rerun or benchmark. Full-suite counts and timings below remain historical evidence for the earlier source; current-source performance is unmeasured.**

**Historical status: The earlier implementation compiled with zero diagnostics and passed six native test groups plus constructor/storage visibility controls in UEFN. Performance remains unmeasured; no performance guarantee is implied.**

Follow the [root installation convention](../../README.md#installation): copy `../stormlabs-bits/src/stormlabs_bits.verse` as `00_stormlabs_bits.verse` and `src/stormlabs_bloom.verse` as `10_stormlabs_bloom.verse` into the same Verse source folder. Keep application consumers later, for example `90_game.verse`. Canonical repository filenames remain unchanged. The public modules remain `Bloom` and `Bits`. No crypto, encoding, STL, native hash suite or device dependency is introduced. The packed bitset remains owned by Bits.

## Generic contract: bloom-v1

`MakeBloomFilter[t, BitCount, HashCount, Hash]` returns `bloom_filter(t)`. The hash callback has type `type{_(:t, :int)<computes>:int}` and receives `(Value, ProbeIndex)`, where the index is `0..HashCount - 1`. The factory validates `1..2147483647` bits and `1..32` hash probes before allocation. These bounds are arithmetic/work bounds, not a promise that every size fits the island's memory or execution budget.

Every signed hash result is permitted, including negative values and the minimum signed value. Positive-denominator `Mod[HashResult, BitCount]` maps it into the bit range without `Abs`, unsigned conversion or multiplication. A hash returning the same positions for every value is legal but yields poor selectivity. Hash quality and the relationship between probe outputs are the caller's responsibility.

| Method | Contract | Effects |
| --- | --- | --- |
| `BitCount()` | Fixed bit-storage capacity | `<transacts>` |
| `HashCount()` | Number of hash probes | `<transacts>` |
| `Insert[Value]` | Set all positions for Value atomically | `<transacts><decides>` |
| `MightContain[Value]` | Success: possibly present; failure: definitely absent | `<transacts><decides>` |
| `Clear()` | Clear all bits while retaining bit count, hash count and callback | `<transacts>` |
| `Clone()` | Independent mutable storage with the same bits, parameters and callback | `<transacts>` |

The callback must be deterministic and consistent for the same logical value and probe throughout a filter's lifetime. Equivalent logical values must hash consistently. For class-valued keys, do not mutate fields used by hashing after insertion. The generic type has no `comparable` constraint: integers, strings, user records and user classes can all be keys.

Storage is private and mutation between clears is insertion-only. Under consistent hashing, a successfully inserted value has no false negative until the filter is cleared. A successful membership query can be a false positive. No distinct values are retained or counted; the bit count is the explicit storage capacity, and there is no enforced element-count capacity. Duplicate insertion is idempotent at the bit level. More insertions can saturate the filter. This is a probabilistic prefilter, not evidence of identity, a security boundary, cryptography, or an exact set.

For sizing only, the familiar approximate false-positive rate is `(1 - exp(-k*n/m))^k` for `m` bits, `k` probes and `n` inserted values, assuming independent, uniformly distributed hash positions. Caller-selected callbacks may violate those assumptions completely; the formula is not an observed rate, bound or guarantee for this implementation. No automatic sizing or false-positive estimate API is provided.

Each instance needs a single logical owner. Assigning a class reference creates an alias. Methods are synchronous, do not yield, and offer no concurrency or frame-time guarantee. Failed insertion, or failure in its enclosing transaction, rolls back all changed bits. A caller must not negate a successful insertion merely to branch on it: Verse transaction rollback would undo that insertion. Negating a read-only membership query is safe.

`Clone()` shares the immutable hash function value and independent copies of all bit storage. Clearing or inserting into either filter does not change the other. Generic fields are immutable: mutable state lives in the existing nonparametric Bits object, avoiding an assumption that mutable generic fields are supported by the installed compiler. The private constructor prevents bypassing parameter validation; construct through `MakeBloomFilter`.

```verse
HashInt(Value:int, Probe:int)<computes>:int =
    BitXor(Value, Probe)

if (Filter := Bloom.MakeBloomFilter[int, 128, 3, HashInt]):
    if (Filter.Insert[42]):
        if (Filter.MightContain[42]):
            Print("42 may be present")
```

This small example demonstrates callback wiring, not a recommended hash distribution. Use a deterministic type-appropriate strategy when selectivity matters. The same API works with strings and user records/classes by supplying callbacks of their corresponding types.

This is original StormLabs implementation code informed by the standard Bloom-filter construction; no third-party implementation source was translated.

On 2026-10-17, local UEFN checks compiled the implementation with the pinned Bits dependency and zero diagnostics. The importing consumer passed six named groups with complete ordered BEGIN/END records: integer/string/user-class keys, parameter and signed-hash edges, clone/collision behavior, and transaction rollback. Separate compiler controls rejected direct constructor and backing-storage access; the exact positive consumer was restored and compiled cleanly. The checks used matching source/dependency/consumer versions.

Independent host fixtures supplement this bounded native run. Prepared performance probes remain unrun; no measured false-positive rate, timing or allocation result is claimed.
