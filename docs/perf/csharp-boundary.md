# Optional AHK + C# performance backend

**Status:** resident history indexing/search and batched ignore matching are wired
into the real application, **opt-in only**. Windows end-to-end timing tables
remain unmeasured. Managed-only timings are not proof of an application-level
speedup, and adding CI checks does not mean those checks have already run.

## 1. Keep the input layer native

| AutoHotkey owns | Optional C# work |
| :-- | :-- |
| Hotkeys, CapsLock layer, `Send`, key state | Resident history duplicate index |
| Clipboard ownership and copy/paste timing | Search over resident raw text and cached previews |
| History metadata and binary persistence | Pure text helpers |
| Every GUI, menu, tray and theme | Batched ignore matching and compiled-regex cache |
| Native `Loop Files` enumeration, file reading and headers | Filtering the enumerated paths in one batch |
| Pandoc/ImageMagick child processes | — |

No hotkey changes, workers, AHK callbacks from .NET threads, runtime C# compilation,
or new clipboard normalization are introduced. `ClipboardService.NormalizeText`
is an explicit helper, not something silently applied to copied or stored text.
The helper now preserves line separators and trims each line in a single pass.

The shipped default remains `[Services] Backend=ahk`. Changing the backend in the
Settings Center applies immediately, without booting the CLR just to change a
setting. A circuit breaker stays tripped until process restart, even if the
setting is toggled.

## 2. What changed at the boundary

### Resident history: one snapshot, then deltas

The old prototype rebuilt/passed a whole `string[]` on every duplicate query and
scanned it linearly in C#. That merely changed the language of the loop while
adding marshalling overhead; it was not a useful hot path.

`HistoryService` is now an **instance** containing an oldest-first ring and an
ordinal text dictionary. Occurrence links also preserve duplicates already in a
loaded history. A stored ring slot gives an entry's current newest-first rank
without renumbering the entire index on every prepend:

- Duplicate lookup: expected **O(1)**, including the oldest matching occurrence,
  as required by AHK's reverse scan. Hashing still costs O(candidate length).
- New insertion and oldest eviction: amortized **O(1)** on the C# side.
- Arbitrary deletion/moving an old duplicate: moves the shorter side of the ring;
  worst case **O(n)**. AHK's authoritative `InsertAt`/`RemoveAt` still has its
  own shifting cost, so the complete `HistoryManager.Add` is **not** O(1).
- Search: scans the resident texts in managed code; raw text is not
  lowercased/copied for each query. AHK's default `InStr` folds **ASCII A-Z only**;
  non-ASCII characters remain exact. All-ASCII strings use the optimized .NET
  search; mixed/Unicode strings use one query-side KMP prefix table, avoiding both
  Unicode-case false positives and quadratic repetitive-text scans. Display
  previews are computed lazily and retained with their entries, including PCRE's
  Unicode vertical-whitespace behavior (NEL/line/paragraph separators).

AHK still performs the most-recent-duplicate fast check before calling any
service. After the first query, only the candidate, add/delete/trim deltas, and
search query/results cross the bridge. Metadata never does.

`HistoryManager.revision`, the source-array identity, and the indexed count guard
snapshot reuse. Load/replacement invalidates lazily. Settings, tray limit changes,
and auto-cleaning all use `HistoryManager.Trim`. Disabling/re-enabling C# forces
one resynchronization after edits made while it was off. `Services.Status()`
exposes `history_loads` and `history_deltas` to verify that warm edits do not resend
the table. Replacing the history, disabling the backend, or tripping its breaker
drops the resident history object reference, so obsolete text is not kept rooted by Services.
The CLR/assemblies themselves cannot be unloaded from AHK#'s AppDomain; resident
text is a second copy while enabled, so working-set overhead must be measured,
not assumed away.

The history GUI caches **matching indices**, not a formatted object for every
entry. Only rows actually displayed (initially 50) get AHK preview/time strings.
Incremental “Load More” also checks the history revision before reusing indices.
An empty query builds indices locally without starting .NET or transferring an
all-indices result. These display optimizations benefit the pure-AHK backend too.

### Batch file filtering, without changing ignore semantics

`FileHelper.BuildIgnoreRegexes` is the **only** gitignore-style parser. It supplies
its actual simple-glob and regex buckets to C#, once per rule edit:

- Simple patterns still call **`PathMatchSpecW`**, inside the batch. They are not
  replaced with a roughly equivalent .NET glob; Windows alternatives and wildcard
  behavior are preserved. Filename extraction also mirrors AHK `SplitPath`,
  including drive-relative paths, URL handling and its forward-slash quirks.
- Complex patterns use those exact generated regex strings, with
  `RegexOptions.Compiled` and a 250 ms match timeout. They remain **case-sensitive**,
  like the existing AHK regex bucket; the native simple bucket is case-insensitive.
- The matcher retains **one** rule set, not an unbounded dictionary of every edit.
  Rule publication is transactional: malformed payload/regex input cannot partially
  replace the cache.

Recursive and non-recursive file walks stay in native AHK, preserving enumeration
order and existing error handling. C# gets one framed path batch and returns one
filtered batch. Reading multiple files also filters once rather than crossing
once per file. No directory pruning is introduced: a simple directory-name glob
need not match its descendants, so pruning would change existing behavior.

### Framing, static types, and failure handling

Bulk strings use repeated **`UTF-16-length:text`** frames. `StrLen` and .NET
`String.Length` count the same code units, including surrogate pairs. Newlines,
colons, commas, empty strings and control-character delimiters in clipboard text
cannot corrupt a snapshot. Returning a string also avoids one COM property read
per result-array element.

`HistoryService` and `IgnoreMatcher` are constructible instances.
`ClipboardService` is static and is reached with `CS("CapsLockSharp.ClipboardService")`,
not `CreateObject`. The bridge path is `lib\ahk#\lib\ahk#.bridge.dll`.

Every guarded call has a **real AHK fallback**, including ignore matching (the old
placeholder returned `false`). The first boot/call/response error trips the
breaker and is counted once. A failed history delta happens **after** AHK has
committed the edit; it disables C# without applying the edit again. Missing DLLs
are detected before invoking the bridge, and `AHKSHARP_DEV` runtime rebuilds are
refused. Bridge hash verification stays enabled.

## 3. Enable the optional backend in a source checkout

[AHKSharp](https://github.com/owhs/AHKSharp) is not vendored. The runtime/test
reference is pinned to commit `e3b895c7590eba47748b0ed963b7978c237d1daf`.
It hosts the Framework 4.x CLR in the AHK process; use **.NET Framework 4.7.2+
(4.8 recommended)** for these `netstandard2.0` services. The .NET 8 SDK is needed
only to build/test them, not on an end user's machine. One AnyCPU assembly serves
both x86 and x64 hosts.

From the repository root, in PowerShell:

```powershell
git clone https://github.com/owhs/AHKSharp.git lib\ahk#
git -C lib\ahk# checkout --detach e3b895c7590eba47748b0ed963b7978c237d1daf
dotnet build src\CapsLockSharp\CapsLockSharp.csproj -c Release -o lib
```

The entry script and test/profiling scripts have optional `#Include *i` directives
for that checkout. No manual source edit is needed. Set the existing setting in
`configs\Config.ini` (or choose C# in the Settings Center):

```ini
[Services]
Backend=csharp
```

Run `CapsLock-.ahk`, or compile it **with the bridge checkout present**. An
already-compiled pure-AHK release cannot discover new AHK source by dropping DLLs
beside it. Generated assemblies, bridge checkouts, `bin`/`obj`, and benchmark
results are ignored by Git.

`Configure`, history loading and ignore-rule preparation never start .NET. Boot
and JIT costs are paid on the first actual C# request and must be measured
separately from warmed-up calls. If the bridge/runtime is absent, the application
continues using AHK and reports the reason through `Services.Status()`.

## 4. Regression checks

```powershell
# Portable managed algorithm tests; native glob fixtures run only on Windows.
dotnet run --project tests\CapsLockSharp.Tests -c Release
# Optional managed-only diagnostic, not an AHK/COM benchmark:
dotnet run --project tests\CapsLockSharp.Tests -c Release -- --benchmark

# Actual AHK behavior and missing-backend fallback (no bridge required):
AutoHotkey64.exe /ErrorStdOut scripts\perf\ServiceEquivalence.ahk
# Require the real bridge: absence/fallback is a failure, not a skipped success.
AutoHotkey64.exe /ErrorStdOut scripts\perf\ServiceEquivalence.ahk -CSharp
AutoHotkey32.exe /ErrorStdOut scripts\perf\ServiceEquivalence.ahk -CSharp
AutoHotkey64.exe /ErrorStdOut scripts\HotkeyRegression.ahk
```

Managed tests cover 10,000 deterministic randomized edits against an independent
list reference, 5,000 randomized ASCII/Unicode search comparisons, loaded duplicates, ring growth/wraparound/eviction, malformed
snapshots and deltas, UTF-16 framing, raw/preview search, multiline normalization,
and bounded rule caching. They do not substitute for Windows bridge checks.

`ServiceEquivalence.ahk` uses the **real** AHK matcher/history code. It exercises
backend toggling, reload, add/delete/trim without resending a warm snapshot,
case/Unicode/display search, recursive file ordering, constant-count batch
crossings, malformed responses, boot failures, and injected post-commit failures.
It creates only a unique temporary workspace; it does not register hotkeys,
change the real clipboard or open a GUI.

`.github/workflows/dotnet.yml` builds the precompiled assembly, runs managed tests,
checks the pure-AHK fallback, checks out the pinned bridge, then validates the
application and real service boundary with **both x64 and x86 AutoHotkey**.
`test.yml` also runs the pure-AHK fallback checks. Windows execution/CI results
must still be inspected before accepting a migration.

## 5. Measure the complete boundary, not just a faster loop

```powershell
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk -History 1000,10000,50000 -Files 20
# Optional: overwrites the real clipboard.
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk -Clipboard
```

Results go to `scripts\perf\results\baseline-<timestamp>.{json,md}`. The harness
uses identical corpus sizes and starts each backend from the same history. It
records cold boot separately, then warms snapshot/regex/JIT work before timing.
Debounced save timers are cancelled between workloads so they do not contaminate
unrelated samples. Missing backends are explicitly skipped. **Any fallback or
exception invalidates a C# row** instead of reporting AHK timings under a C# label.

| Comparison workload | What the result includes |
| :-- | :-- |
| `compare-history-scan-*-<n>` | Original AHK reverse scan vs naive whole-array transfer/managed scan |
| `compare-history-snapshot-csharp-<n>` | Snapshot packing/transfer/resident-index construction, forced per sample |
| `compare-history-lookup-resident-csharp-<n>` | Warm scalar query through the actual bridge/hash index |
| `compare-history-add-new-*-<n>` | Real AHK insertion/eviction + backend lookup/delta + debounce scheduling |
| `compare-history-search-*-<n>` | Raw/preview filtering and transfer/decode of matching indices |
| `compare-ignore-match-*` | Scalar matching, useful to expose per-call overhead |
| `compare-ignore-batch-*` | Entire file corpus, including packing/transfer/decode |
| `compare-file-enum-*` | Native directory walk plus the real backend's filtering |
| `csharp-cold-boot` | One cold CLR/assembly/type initialization observation |

Also retained: history save/load, JSON round-trip, ignore compilation, file walk
without rules, and opt-in clipboard round-trip baselines.

### Windows results — deliberately not filled from managed-only diagnostics

Machine / Windows / AHK / Framework / build / power plan: **not yet recorded**.

| Workload | Size | AHK p50 / p95 (ms) | C# p50 / p95 (ms) |
| :-- | --: | :-- | :-- |
| Real history add | 1,000 | — | — |
| Real history add | 10,000 | — | — |
| History search | 10,000 | — | — |
| Ignore whole corpus | — | — | — |
| Recursive enumeration + filtering | — | — | — |
| Cold CLR boot (single observation) | — | n/a | — |

Whole-process startup, idle CPU/working set, `CapsLock → Send` latency and Smart
Paste end-to-end figures come from `scripts\benchmark\Measure-CapsLockBuild.ps1`.
Run both backends back-to-back on the same Windows desktop, same power plan, on
AC power, with at least three repetitions. Include sparse and dense searches and
small histories; marshalling/JIT costs can outweigh the faster loop there.

Do not enable C# by default or change release packaging until the full workloads
win by at least **2× at p50**, are no worse at p95, preserve input/startup behavior,
and pass Windows equivalence/hotkey regressions. The C# ring removes a scan; it
cannot remove all remaining AHK, COM, disk or GUI costs.

## 6. Release scope and remaining work

The normal x86/x64 releases remain pure AHK. `dotnet.yml` uploads
`CapsLockSharp-netstandard2.0` as an optional build artifact; `release.yml` does
not embed or publish the bridge/services. If measurements justify shipping them,
package **precompiled** AnyCPU services and the exact hash-matching bridge, include
the matching AHK source at build time, and extract real DLL files before CLR boot.
No user-side compiler, Roslyn/NuGet download or developer rebuild flag is allowed.

Outstanding verification: Windows bridge/Framework results, real p50/p95 and
end-to-end/input/idle measurements, and visual GUI paging behavior. PCRE/.NET
regex and non-ASCII case behavior must be checked on supported Windows versions;
any unsupported generated expression must fail safely back to AHK. JSON/large
history codecs and full file-content I/O remain possible later migrations, not
part of this change.
