# JSON API

## Overview

One immutable model for all six JSON kinds, strict parsing, functional editing
and deterministic writing. Numbers preserve exact input lexemes; object members
retain insertion order and duplicate decoded names fail. Depends on Encoding
and STL. See the [README](README.md) for installation and full contract detail.

Public signatures below omit implementation bodies and retain exact effects,
optional defaults and constructor visibility. Failable calls use [];
other calls use ().

```verse
JSON<public> := module:
```

## Types and constructors

`json_value`, `json_parse_result` and `json_write_result` have internal
constructors. Obtain them from the module functions. `json_member` and
`json_error` are value structs; `json_limits{...}` is directly constructible
using the defaults shown. All public fields are immutable.

```verse
json_kind<public> := enum:
    Null
    Boolean
    Number
    String
    Array
    Object
```

```verse
json_value<public> := class<internal><final>:
    Kind<public>:json_kind
    GetBoolean<public>()<computes><decides>:logic
    GetNumberLiteral<public>()<computes><decides>:string
    GetInteger<public>()<transacts><decides>:int
    GetString<public>()<computes><decides>:string
    GetArray<public>()<computes><decides>:[]json_value
    GetElement<public>(Index:int)<computes><decides>:json_value
    GetObject<public>()<computes><decides>:[]json_member
    GetMember<public>(Name:string)<transacts><decides>:json_value
    WithElement<public>(Index:int, Value:json_value)<transacts><decides>:json_value
    Append<public>(Value:json_value)<transacts><decides>:json_value
    WithoutElement<public>(Index:int)<transacts><decides>:json_value
    WithoutMember<public>(Name:string)<transacts><decides>:json_value
    WithMember<public>(Name:string, Value:json_value, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value
```

```verse
json_member<public> := struct:
    Name<public>:string
    Value<public>:json_value
```

```verse
json_limits<public> := class<final>:
    MaxDepth<public>:int = 64
    MaxNodes<public>:int = 100000
    MaxInputBytes<public>:int = 1048576
    MaxOutputBytes<public>:int = 1048576
    MaxStringBytes<public>:int = 1048576
    MaxNumberBytes<public>:int = 4096
```

```verse
json_error_code<public> := enum:
    InvalidLimits
    InputLimit
    OutputLimit
    DepthLimit
    NodeLimit
    StringLimit
    NumberLimit
    InvalidUTF8
    UnexpectedEnd
    UnexpectedToken
    InvalidEscape
    InvalidNumber
    DuplicateName
    TrailingInput
```

```verse
json_error<public> := struct:
    Code<public>:json_error_code
    ByteOffset<public>:int
```

```verse
json_parse_result<public> := class<internal><final>:
    Value<public>()<computes><decides>:json_value
    Error<public>()<computes><decides>:json_error
```

```verse
json_write_result<public> := class<internal><final>:
    Text<public>()<computes><decides>:string
    Error<public>()<computes><decides>:json_error
```

Module factories and functions:

```verse
JSONNull<public>()<transacts>:json_value
JSONBoolean<public>(Value:logic)<transacts>:json_value
JSONNumber<public>(Literal:string, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value
JSONInteger<public>(Value:int)<transacts>:json_value
JSONArray<public>(Values:[]json_value)<transacts>:json_value
JSONString<public>(Text:string, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value
JSONObject<public>(Members:[]json_member, ?Limits:json_limits = json_limits{})<transacts><decides>:json_value
WriteScalar<public>(Value:json_value)<transacts><decides>:string
Write<public>(Value:json_value, ?Pretty:logic = false, ?Limits:json_limits = json_limits{})<transacts>:json_write_result
ParseBytes<public>(Bytes:[]int, ?Limits:json_limits = json_limits{})<transacts>:json_parse_result
Parse<public>(Text:string, ?Limits:json_limits = json_limits{})<transacts>:json_parse_result
```

## Operations

| Operations | Behavior |
| --- | --- |
| `JSONNull`, `JSONBoolean`, `JSONInteger` | Construct scalars; integers use integer-form tokens. |
| `JSONNumber` | Validate a complete number lexeme and retain its spelling, including minus zero and fraction/exponent zeros. |
| `JSONString`, `JSONObject` | Validate immediate UTF-8 string/name inputs and limits; object names must be unique. |
| `JSONArray` | Wrap an immutable array. Container construction does not recursively enforce subtree limits. |
| Typed `Get*` getters | Fail for the wrong kind. `GetInteger` also requires integer form and signed64 range; no implicit float conversion. |
| `GetElement`, `GetMember` | Fail for a missing index/name; a present null succeeds. Indices are zero based. |
| `WithElement`, `Append`, `WithoutElement` | Return new array values; existing-index operations require valid indices. |
| `WithMember`, `WithoutMember` | Return new objects; replacement retains position, insertion appends, removing an absent name succeeds. |
| `Parse`, `ParseBytes` | Return exactly a value or error through result getters; no parsed prefix is exposed on failure. |
| `Write` | Validate the complete tree/limits and return exactly complete text or error. |
| `WriteScalar` | Convenience for null, Boolean and number only. |

Bind parse/write results before testing `Value` or `Text`; on failure `Error`
is available instead. Compact output preserves member order and numeric lexemes.
Pretty output uses two spaces per depth, LF, compact empty containers and no
trailing newline. Quotes/backslashes are escaped, controls use lowercase
backslash-u00xx, and other valid Unicode remains UTF-8. Output is not canonical
JSON normalization.

## Examples

```verse
Parsed := JSON.Parse("[null,false,1.2300e+004]")
if (Value := Parsed.Value[]):
    if (Token := Value.GetElement[2].GetNumberLiteral[]):
        Print(Token)
    Written := JSON.Write(Value, ?Pretty := true)
    if (Text := Written.Text[]):
        Print(Text)
else if (Error := Parsed.Error[]):
    Print("Byte {Error.ByteOffset}")

if (Number := JSON.JSONNumber["9007199254740993"]):
    if (Exact := Number.GetInteger[]):
        Print("{Exact}")
```

## Failure and cost notes

Failable functions use square brackets. Parse/write entry points instead
return result objects. `GetInteger` rejects fractions, exponent forms and values
outside -9223372036854775808..9223372036854775807 independently of lexeme validity.
`ParseBytes` elements must be0..255. Unicode is strict: malformed UTF-8,
unpaired surrogate escapes and a BOM fail; there is no replacement or
normalization. Comments, trailing commas/input, non-JSON whitespace, NaN and
infinity fail.

Offsets are zero-based UTF-8 bytes; input length means EOF. Invalid UTF-8 reports
sequence start, duplicates the second name's opening quote, unpaired surrogates
the initiating backslash. Input limits precede full-input UTF-8 and grammar.
Writer offsets count output bytes already emitted; oversized chunks fail as a
unit and no partial text is exposed.

Limits use UTF-8 bytes except nodes/depth. Root container depth1; scalars consume
no depth and keys are not value nodes. Allowed settings: depth1..256,
nodes1..1000000, input/output1..67108864, string0..67108864,
number1..1048576. Defaults are in the signatures. Limits bound accepted data,
not a frame budget.

Edits preserve old snapshots. Member lookup currently scans every member and
allocates a matches array. Duplicate-name scans, recursive parse/write depth,
and repeated byte/string/array assembly have costs; no measured new-library
timing, allocation or persistence guarantee is made.

The thirteen modules compiled together and passed the source-bound
13-group public-consumer smoke check in UEFN 42.40 CL59247843. Historical full
suites in the README remain bound to their original bytes and were not rerun.
This short integration check supplies no performance measurements.
