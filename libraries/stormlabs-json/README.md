# stormlabs-json

## Public API overview

See the complete [API reference](API.md) for public types, exact signatures,
effects, operations, examples, failure behavior and ownership.

Original MIT-licensed Verse JSON library, module `JSON`.

**Status: all thirteen libraries compile together and passed a bounded
13-group native smoke check. Earlier implementation-level results remain separate.
Experimental; performance is unmeasured.**

The library implements one immutable value model for objects, arrays, strings,
numbers, Booleans, and null, plus a strict parser, functional builders/editors,
compact/pretty serialization, and structured diagnostics. The local verification
described below covers a bounded set of contracts and inputs.

Copy the canonical sources into the same Verse source folder as
`00_stormlabs_stl.verse`, `10_stormlabs_encoding.verse`, and
`20_stormlabs_json.verse`. Put application files afterward, such as
`90_game.verse`, and import `JSON` using that folder's project-specific
module path. Repository source filenames stay unchanged; the public module is
now `JSON`.
See the root [installation guidance](../../README.md#installation). This
numbered-copy convention is a local UEFN 42.40 CL59247843 workaround, without a
Verse language ordering guarantee. Dependencies are
`stormlabs-encoding` for strict UTF-8 helpers and
[stormlabs-stl](../stormlabs-stl/README.md) for byte-array holders. Use dependency sources from the same repository snapshot.

```verse
if (Number := JSON.JSONNumber["9007199254740993"]):
    if (Exact := Number.GetInteger[]):
        Print("{Exact}")
    if (Text := JSON.WriteScalar[Number]):
        Print(Text)

Parsed := JSON.Parse("[null,true,1.2300e+004]")
if (Value := Parsed.Value[]):
    Written := JSON.Write(Value, ?Pretty := true)
    if (Text := Written.Text[]):
        Print(Text)
else if (Error := Parsed.Error[]):
    Print("JSON failed at byte {Error.ByteOffset}")
```

`GetNumberLiteral` and scalar output preserve the original token, including
`-0`, fraction zeros, and exponent spelling. `GetInteger` accepts only
integer-form tokens in `-9223372036854775808..9223372036854775807`; it fails for
fraction/exponent forms and out-of-range values. There is no implicit float
conversion or dependency on arbitrary-precision arithmetic.

Factories are `JSONNull`, `JSONBoolean`, `JSONNumber`, `JSONInteger`,
`JSONString`, `JSONArray`, and `JSONObject`. Object construction accepts an
insertion-ordered `[]json_member`, whose fields are `Name:string` and
`Value:json_value`. Number, string, and object factories accept optional
`?Limits := json_limits{...}`. They validate their immediate token/string/key
inputs; building a container does not recursively validate subtree limits.
`Write` always checks the entire tree against its supplied limits.

Typed getters are `GetBoolean`, `GetNumberLiteral`, `GetInteger`, `GetString`,
`GetArray`, and `GetObject`; every getter fails for the wrong kind. `GetElement`
uses a zero-based index. `GetMember` fails for a missing name; a present null
succeeds with `Kind = json_kind.Null`. No normalization is applied to names.
Both parser and builder reject duplicate decoded names.

Edits return new values and preserve earlier snapshots. `WithMember` replaces
an existing name in its original position or appends a new name;
`WithoutMember` removes it and succeeds if it was absent. Array `WithElement`
replaces an existing index, `Append` adds a value, and `WithoutElement` removes
an existing index. Wrong-kind and out-of-range edits fail. No persistence
guarantee is made.

Factories and edits use `<transacts>`; operations which may reject input also
use `<decides>` and square-bracket calls. Typed getters use
`<computes><decides>`, except integer conversion and name lookup, which use
`<transacts><decides>`. `Parse`, `ParseBytes`, and `Write` use `<transacts>` and
return result objects. Result getters `Value`/`Text` and `Error` use
`<computes><decides>`. These effects are part of the API.

`Parse(Text)` consumes a Verse UTF-8 string; `ParseBytes(Bytes)` consumes
`[]int` bytes in `0..255`. Each returns exactly a value or `json_error` through
the result's failable `Value()` and `Error()` getters. Parse the result into a
local before testing its getter when preserving failure information matters.
No parsed prefix is exposed after failure.

`Write(Value, ?Pretty := false)` returns exactly complete text or an error
through `Text()` and `Error()`. Compact output preserves member order and the
numeric lexemes. Pretty output uses two spaces per level, LF, no trailing
newline, and compact empty containers. Quotes/backslashes are escaped; every
control byte is written as lowercase `\u00xx`. Other Unicode remains UTF-8.
Output is deterministic for the same value and options; it is not canonical
JSON or a numeric normalization format. `WriteScalar` is a small failable
convenience for null, Boolean, and number values only.

Parser diagnostics use zero-based UTF-8 byte offsets, with input length
representing end of input. Invalid UTF-8 points to the beginning of the failing
sequence; a duplicate points to its second name's opening quote; unpaired
surrogates point to the initiating backslash. Invalid number offsets point to
the byte at which grammar fails; `NumberLimit` points just past the allowed
token prefix. Input limits are checked first, then all UTF-8, then JSON grammar.
Writer offsets count output bytes successfully emitted before failure; an
oversized output chunk is rejected as a unit. Failed writes expose no partial
text. Error codes include invalid limits/UTF-8/escapes/numbers, duplicate names,
unexpected token/end, trailing input, and each resource limit.

The default limits are 64 container levels (root container depth one), 100,000
value nodes, 1 MiB input/output/decoded string bytes, and 4,096 bytes per number
token. Every size is measured in UTF-8 bytes. String limits apply to each
decoded value/key, and keys are not value nodes. Scalars consume no container
depth. Bounds accepted by `json_limits` are depth `1..256`, nodes
`1..1000000`, input/output `1..67108864`, string `0..67108864`, and number
`1..1048576`. Limits bound accepted data, not a promised frame budget.

The grammar follows [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259), with a
strict Unicode policy: malformed UTF-8 and unpaired escaped surrogates fail.
Escaped high/low surrogate pairs combine into one Unicode scalar. A leading
byte-order mark, trailing input, comments, trailing commas, non-JSON whitespace,
NaN, and infinity are rejected. No Unicode normalization or replacement occurs.

The current bare namespaces compiled together in UEFN 42.40 CL59247843. The
local public consumer passed all 13 module groups
with zero failures and complete, unique records. This bounded integration check
is not a rerun of the historical full suites or a performance benchmark.

The verification below predates the bare-namespace refresh and binds its
original source bytes. It does not verify the renamed sources.

The earlier implementation compiled without diagnostics in the local UEFN host. Its local run passed all 163 assertions with zero failures. The strict log
verifier required every expected unique check and complete BEGIN/END records;
no missing, duplicate, unknown, or failed records were present.

The suite includes independent compact/pretty expected bytes, all six kinds,
missing versus null, exact numeric lexemes and signed integer boundaries,
malformed grammar/UTF-8/escapes/surrogates, duplicate names, byte diagnostics,
builder snapshots, and small configured resource-limit boundaries. Separate
negative compiler controls rejected direct value construction and internal
number-field access with only the expected access diagnostics. The exact positive
wrapper was restored and compiled without diagnostics afterward.

These results cover the tested local environment and fixtures. The VM mode was
not independently established; performance, allocation costs, maximum-size
inputs, other environments, and exhaustive input coverage remain unverified.
Performance probes are prepared but have not been compiled or run. Test wrappers,
vectors, negative controls, and logs are ignored local artifacts, not shipped
library dependencies.

The library follows [Epic's Verse style guide](https://dev.epicgames.com/documentation/fortnite/verse-code-style-guide-in-unreal-editor-for-fortnite?lang=en-US).
Factory function names identify the kind they create; a closed factory-only
class keeps invalid numbers and strings out of the shared value model.
