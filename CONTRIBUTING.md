# Contributing

Keep changes small, reviewable and backed by checks appropriate to the behavior
they affect. Start with the [API catalog](docs/API.md) and the relevant README.
This repository ships source/docs without a package manager, bundled island,
public automated suite or CI test command.

## Setup

Install UEFN and Fortnite and create a disposable Verse-enabled island. Local
checks used Windows UEFN 42.40 CL59247843; later toolchains and other VM
configurations need their own checks.

Copy the library under change and its full dependency closure into one Verse
source folder. Use the [numbered layout](README.md#installation), with application
consumers afterward. Keep canonical repository filenames unchanged and avoid
account-specific module paths.

Use Verse Explorer to create a small Verse device. Compile with **Verse > Build
Verse Code**, place the device in the level, launch a session and start the game
to execute it. Push changed code to an existing session before trusting a new
run. Epic's [Verse device guide](https://dev.epicgames.com/documentation/fortnite/create-your-own-device-using-verse-in-unreal-editor-for-fortnite)
describes the editor workflow.

## Layout and style

```text
libraries/stormlabs-<name>/
  README.md
  API.md
  src/
    stormlabs_<name>.verse
```

Use underscores in source basenames when a directory name contains a hyphen:
`stormlabs-disjoint-set/src/stormlabs_disjoint_set.verse`. Keep dependency
declarations and the root catalog accurate. STL stays independent of specialized
packages.

Follow [Epic's Verse style guide](https://dev.epicgames.com/documentation/fortnite/verse-code-style-guide-in-unreal-editor-for-fortnite):
four spaces, lower_snake_case types, PascalCase other names, readable failure
contexts and restricted visibility. Preserve established arithmetic notation
when it aids comparison with a specification. Keep compact source API comments
and complete API.md references synchronized.

Effects, optional defaults, overloads, constructor visibility, failure behavior,
ordering and ownership are public contracts. Discuss breaking changes before
implementing them; update examples/consumers when an agreed change affects
callers. `SHA256Async` remains the existing compatibility wrapper; yielding hash
APIs use `HashSHA...` names.

Generic collections must support distinct key/payload types and custom class
values. Preserve strict weak comparison, comparator equivalence, representative
keys, immutable snapshots and shallow-reference ownership. Do not replace a
generic implementation with an integer-only specialization. Mutable APIs need
explicit aliasing, clone, failure-atomicity and rollback behavior.

## Verification

Keep local devices, vectors, generated files, results and benchmarks in ignored
local directories; they are not shipped. No private test command is required
to contribute. Create bounded cases in your disposable UEFN project and report
what actually ran.

1. Build the changed library, dependencies and a small importing consumer.
   Build the assembled library set for shared-provider, namespace or generic
   composition changes.
2. Compare observable results with independent expected values, including
   empty/singleton inputs, boundaries, invalid inputs and failure paths.
   Round trips alone are insufficient for serializers and encodings.
3. For generic containers, use multiple type combinations and a custom class
   comparator. Cover equivalent keys, missing values, false payloads, retained
   snapshots and rollback. Exercise resource limits using small configured limits.
4. For cryptography, use published known answers and independent references,
   padding boundaries and one-shot/incremental agreement. Do not infer that
   untested algorithms, input sizes or runtime modes passed.
5. Run the placed device with the newly compiled source. Label each check and
   capture complete begin/end results with expected counts. Pace lengthy output
   and yield between independent groups; interrupted/throttled logs are incomplete.
6. Rebuild and rerun affected checks after the last relevant edit. Distinguish
   compile-only, host-reference and native-runtime results; report unavailable
   checks and environment blockers.

Record the UEFN build, observable VM configuration, source version or hashes,
installed filenames, dependencies, expected/actual results and checks performed.
Omit machine-local absolute paths, secrets and player data from public reports.
A compact synthetic reproduction is more useful than a large raw editor log.

## Performance changes

Establish correctness before measuring. Separate theoretical node/comparison
bounds from Verse array copying, allocation/GC and wall time. Immutable array
updates can copy much more than a textbook operation count suggests.

Start with a quick bounded tier, then opt into geometric input counts/lengths
after reviewing costs. Measure hits/misses, insertion/removal, empty/full limits,
retained snapshots, wide branches and pathological depth/shape as appropriate.
Record batch size, yields, repetitions, timing scope, platform/build and
background load. Compare equivalent behavior on matching inputs/dependencies
and report medians/ranges plus total work.

Do not treat correctness-run duration as a benchmark, host-reference timing as
Verse performance, or a sample maximum as a frame guarantee. Explain copying
and ownership tradeoffs and how generic behavior was preserved.

## Reports and pull requests

Open an issue with the affected operation, a concise problem statement, minimal
synthetic inputs, expected/actual behavior and toolchain version. Include only
redacted relevant diagnostics. For a patch, explain the concrete change,
compatibility impact, checks actually run and remaining limits. Keep unrelated
formatting/dependency changes separate.

Retain the root [MIT license](LICENSE) and required copyright notices. Document
provenance and compatible licensing for third-party material; do not copy an
implementation without the required permission and notices.
