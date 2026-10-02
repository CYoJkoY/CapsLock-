# Optional AHK + C# performance backend

**Status:** resident history indexing/search and batched ignore matching are wired
into the real application, **opt-in only**. The AutoHotkey checks below run for
real on Windows CI (x64 and x86), and section 5 records the first Windows timings
(a shared GitHub-hosted runner, not a desktop). Those timings are micro-workloads;
they are not an application-level speedup, and desktop, whole-process and input
latency measurements are still outstanding.

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

Single-path ignore checks (`FileHelper.ShouldIgnore`, used at paste time) are not
in the right-hand column even with the backend enabled: section 5 shows one C#
call costs about twice one AHK call, and the first one would start the CLR inside
a paste hotkey. Only whole-file batches cross the bridge.

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

`FileHelper.ShouldIgnore(path)` is always the AHK matcher. `Services.IgnoreMatch`
(one path through the bridge) remains as the tested scalar entry and as a
benchmark of per-call overhead, but nothing in the application calls it.

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

## 3. Enable the optional backend

[AHKSharp](https://github.com/owhs/AHKSharp) is not vendored. The runtime/test
reference is pinned to commit `e3b895c7590eba47748b0ed963b7978c237d1daf`.
It hosts the Framework 4.x CLR in the AHK process; use **.NET Framework 4.7.2+
(4.8 recommended)** for these `netstandard2.0` services. The .NET 8 SDK is needed
only to build/test them, not on an end user's machine. One AnyCPU assembly serves
both x86 and x64 hosts.

The boundary needs exactly two files, and every route below ends at the same
place:

```text
lib\CapsLockSharp.dll            the precompiled services (AnyCPU)
lib\ahk#\lib\ahk#.bridge.dll     the pinned AHK# bridge
```

`Core\CSharpRuntime.ahk` owns that provisioning. It never starts the CLR:
`Services.Boot()` remains the only place that does, on the first service that is
actually called.

Two halves, because `Services` is also loaded by the headless harnesses, which
define neither `Lang()` nor `ConfigManager`:

| File | Responsibility |
| --- | --- |
| `Core\CSharpPayload.ahk` | read the packaged resources, write them with a SHA-256 compare. No dependency beyond `Utils\Hash.ahk`. |
| `Core\CSharpRuntime.ahk` | setup, build, download, diagnostics, the Settings Center button. Loaded by `CapsLock-.ahk` only. |

### 3.1 One click, in the Settings Center

**Settings Center → General → System & Runtime → “Set Up C# Backend”**, next to
the backend selector. The status line beside it reports `Active`, `Installed
(backend is AHK)`, `Bundled with this build`, `Not installed`, or `Disabled after
an error (restart to retry)`.

The button runs `CSharpRuntime.Install()`, which

1. makes the two files exist, in this order of preference:
   * unpack them from the running EXE, when the build packages them (§3.3);
   * build the assembly with the .NET SDK, when `src\CapsLockSharp` is present;
   * download the pinned bridge (`ahk#.ahk`, `ahk#.bridge.dll`, `build.ps1`) from
     the pinned commit and the published `CapsLockSharp.dll` from the latest
     release, when there is no SDK. A downloaded bridge is checked against the
     SHA-256 that AHK# pins in `ahk#.ahk` before it is kept, so a corrupt or
     intercepted download is reported instead of failing at CLR boot;
2. writes `[Services] Backend=csharp` and saves the configuration;
3. performs **one real managed call** and reports success only if that call went
   through the bridge (`Services.calls` has to increase, `Services.ready` stay
   true and the breaker stay closed).

If the install folder is not writable (`Program Files`), the files are placed in
`%LOCALAPPDATA%\CapsLock-\lib` instead and `Services.assemblyPath` /
`Services.bridgePath` are pointed there. Every step is listed in the result
dialog. Failures also write a full report to
`%LOCALAPPDATA%\CapsLock-\Logs\csharp-setup.log` (or the temporary folder
when `LOCALAPPDATA` is unavailable), including the failing stage, exception
location/stack, selected .NET host, and download/build diagnostics.

The bridge digest report distinguishes the two ways a check can fail: a
**mismatch** means the bytes differ from the pinned digest, and the copy is
deleted so the next attempt re-downloads; **"could not be computed"** means
the file exists but could not be read or hashed at that moment (a scanner may
still own a file the download just closed), so the file is kept after a short
retry and AHK#'s own boot-time check has the final say. Only a proven
mismatch throws the download away - otherwise a transient lock would turn a
perfectly valid bridge into an endless fetch-delete loop.

A **source run** needs one more step: `#Include *i lib\ahk#\lib\ahk#.ahk` is
resolved when the process starts, so a freshly downloaded bridge only becomes
visible after a reload. The button asks to reload right away.

### 3.2 Scripted setup, or by hand

```powershell
# Downloads the pinned bridge, builds the services assembly and writes the
# generated CSharpPayload.ahk used by the compiler (see 3.3).
.\scripts\Setup-CSharpBackend.ps1            # add -Force to redo both
.\scripts\Setup-CSharpBackend.ps1 -SkipAssembly   # no .NET SDK on this machine
```

The equivalent by hand, which produces the same layout:

```powershell
git clone https://github.com/owhs/AHKSharp.git lib\ahk#
git -C lib\ahk# checkout --detach e3b895c7590eba47748b0ed963b7978c237d1daf
dotnet build src\CapsLockSharp\CapsLockSharp.csproj -c Release -o lib
```

Then choose C# in the Settings Center, or set the existing setting in
`configs\Config.ini`:

```ini
[Services]
Backend=csharp
```

The entry script and the test/profiling scripts already carry the optional
`#Include *i` for that checkout; no source edit is needed. Generated assemblies,
bridge checkouts, the generated `CSharpPayload.ahk`, `bin`/`obj` and benchmark
results are ignored by Git.

Two diagnostic switches run headlessly and exit, which is also how CI checks a
compiled EXE. `#SingleInstance Force` has already replaced a running instance by
then, so use them while CapsLock- is not running:

```powershell
.\scripts\ci\Invoke-Ahk.ps1 .\CapsLock-.ahk -ScriptArguments '-ProbeCSharp'
.\build\CapsLock-.exe -ProbeCSharp      # prints the packaged payload, unpacks it,
                                          # boots the CLR, makes one managed call
.\build\CapsLock-.exe -InstallCSharp    # the one-click setup, headlessly
```

### 3.3 Packaged into the compiled EXE

`scripts\build.ps1` is the local one-command build: provision, then Ahk2Exe.

```powershell
.\scripts\build.ps1                    # x64 -> build\CapsLock-.exe
.\scripts\build.ps1 -Architecture both # plus build\CapsLock-_x86.exe
.\scripts\build.ps1 -SkipCSharp        # pure-AHK executable
```

`release.yml` and the packaging check in `dotnet.yml` take the same two steps
explicitly instead, with `benmusson/ahk2exe-action` as the compiler, so the
artifact that ships and the artifact CI verifies are produced by the same
commands.

`Setup-CSharpBackend.ps1` writes `CSharpPayload.ahk` next to the entry script,
and that file holds nothing but the two `AddResource` directives that embed the
assembly and the bridge as RCDATA resources. `CapsLock-.ahk` picks it up through
`#Include *i CSharpPayload.ahk`, so **the same source compiles either way**: with
the generated file present the payload is packaged, without it the build stays
pure AHK. `scripts\ci\Test-CSharpPayload.ps1` reads the resource directory of
the finished EXE and fails the build when a resource is missing, empty, or a
different size than the file on disk.

At runtime `CSharpPayload.ExtractTo()` writes both resources next to the EXE -
into `%LOCALAPPDATA%\CapsLock-\lib` when the install folder is read-only -
comparing SHA-256 first, so a normal start writes nothing and an already loaded
bridge is never deleted underneath the CLR. `Services.Boot()` calls it directly,
so it touches only local disk: no network, no compiler, still no CLR. Boot skips
it entirely when a caller pinned `Services.assemblyPath`/`bridgePath`, which the
harnesses do - one of them to a deliberately missing file.

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

# AutoHotkey is a GUI-subsystem program. Started from a console it neither waits,
# prints its output nor reports an exit code, so run every AHK check through
# the wrapper (see below).
.\scripts\ci\Invoke-Ahk.ps1 .\CapsLock-.ahk -Validate
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\HotkeyRegression.ahk
# Real AHK behavior and missing-backend fallback (no bridge required):
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\ServiceEquivalence.ahk
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\HistoryGuiPaging.ahk
# Require the real bridge: absence/fallback is a failure, not a skipped success.
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\ServiceEquivalence.ahk -ScriptArguments '-CSharp'
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\ServiceEquivalence.ahk -ScriptArguments '-CSharp' -Architecture x86
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\HistoryGuiPaging.ahk -ScriptArguments '-CSharp'
```

`scripts\ci\Invoke-Ahk.ps1` starts AutoHotkey directly, waits for it with a timeout,
copies stdout and stderr to the log, and fails on a non-zero exit code, a timeout
or any load-time warning. It also injects `scripts\ci\Headless.ahk` (`/include`):
without a `#Warn` directive AutoHotkey shows a modal MsgBox for every warning and
for an uncaught error, which nobody can click on a build agent. Headless mode
prints warnings to stdout and ends on an uncaught error with exit code 2. It finds
`autohotkey\AutoHotkey64.exe` (where the CI action installs it), `AHK_EXE`, or the
usual install folders; pass `-Executable` otherwise.

Managed tests cover 10,000 deterministic randomized edits against an independent
list reference, 5,000 randomized ASCII/Unicode search comparisons, loaded duplicates, ring growth/wraparound/eviction, malformed
snapshots and deltas, UTF-16 framing, raw/preview search, multiline normalization,
and bounded rule caching. They do not substitute for Windows bridge checks.

`ServiceEquivalence.ahk` uses the **real** AHK matcher/history code. It exercises
backend toggling, reload, add/delete/trim without resending a warm snapshot,
case/Unicode/display search, recursive file ordering, constant-count batch
crossings, malformed responses, boot failures, and injected post-commit failures.
It also asserts that `FileHelper.ShouldIgnore` makes no C# call. It creates only a
unique temporary workspace; it does not register hotkeys, change the real
clipboard or open a GUI.

`HistoryGuiPaging.ahk` runs the real `RefreshFullHistoryList` and `OnLoadMoreClicked`
against a real ListView in a window that is never shown, and edits history through
the real `HistoryManager`: first page, Load More, filtering (including a query that
matches only the collapsed preview), and that delete/add/trim while the window is
open invalidate the incremental cache. With `-CSharp` the same scenario also runs on
the resident index and both runs must produce identical rows. It cannot judge how
the window looks; a visual pass is still worthwhile.

`HotkeyRegression.ahk` cross-references the sources (includes, `FileInstall`, language
keys, documented shortcuts versus bindings, config load/save symmetry). It scans only
the application's own folders.

`.github/workflows/dotnet.yml` builds the precompiled assembly, runs the managed tests,
checks the pure-AHK fallback on x64 and x86, checks out the pinned bridge, then
validates the application, the real service boundary and the history window with
**both x64 and x86 AutoHotkey**, and finally runs the profile harness (below).
Its second job is the packaging check, and it takes the release route on purpose:
`scripts\Setup-CSharpBackend.ps1` provisions both DLLs and writes the generated
include, `benmusson/ahk2exe-action` compiles x64 and x86 the way `release.yml`
does, `scripts\ci\Test-CSharpPayload.ps1` reads the resource directories of the
finished executables, and each executable is then run with `-ProbeCSharp`, which
unpacks the resources, boots the CLR and makes one managed call. That is the
only place the whole chain - generated directives, Ahk2Exe resources, extraction,
bridge hash check, CLR boot - is exercised end to end.
`test.yml` runs `/Validate`, the hotkey regression, the pure-AHK service checks and
the history window paging check.

## 5. Measure the complete boundary, not just a faster loop

```powershell
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\CapsLockProfile.ahk
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\CapsLockProfile.ahk -ScriptArguments '-History','1000,10000,50000','-Files','20' -TimeoutSeconds 1800
# Optional: overwrites the real clipboard.
.\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\CapsLockProfile.ahk -ScriptArguments '-Clipboard'
```

`-JsonMax <n>` (default 1000) bounds the JSON round-trip row: `Utils\Json.ahk` grows
faster than linearly (about 1 s per round trip at 1,000 entries on the CI runner,
minutes at 10,000), so larger sizes are recorded as an explicit "skipped" note.

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
| `compare-ignore-batch-pack-ahk`, `-unpack-ahk` | The AHK half of that crossing alone (build the request frame, decode a reply of the kept paths); no bridge |
| `compare-file-enum-*` | Native directory walk plus the real backend's filtering |
| `csharp-cold-boot` | One cold CLR/assembly/type initialization observation |

Also retained: history save/load, JSON round-trip, ignore compilation, file walk
without rules, and opt-in clipboard round-trip baselines.

### Windows results (CI runner, not a desktop)

Measured by the "Windows baseline" step of `dotnet.yml` on a GitHub-hosted
`windows-latest` runner: Windows 10.0.26100 (Server 2025), 4 logical processors,
AutoHotkey 2.0.28, AHK# `e3b895c`, one harness run per architecture
([run 36954914088](https://github.com/CYoJkoY/CapsLock-/actions/runs/36954914088)).
The runner is a shared virtual machine: absolute times move by tens of percent from
run to run (a 1,000-entry history add measured 0.33 to 0.49 ms across four runs),
while the AHK/C# ratios stayed within a few percent. Read the ratios, and repeat on
a real desktop before relying on any absolute figure.

p50 / p95 in ms. "Ratio" is AHK p50 divided by C# p50, so above 1 means C# is faster.

| Workload (what is compared) | Size | x64 AHK | x64 C# | x64 ratio | x86 AHK | x86 C# | x86 ratio |
| :-- | --: | :-- | :-- | --: | :-- | :-- | --: |
| `HistoryManager.Add`, new clip (whole call) | 1,000 | 0.480 / 0.914 | 0.054 / 0.080 | 9.0× | 0.540 / 0.584 | 0.060 / 0.070 | 9.0× |
| `HistoryManager.Add`, new clip (whole call) | 10,000 | 4.83 / 5.04 | 0.059 / 0.087 | 82× | 5.31 / 5.59 | 0.071 / 0.101 | 75× |
| Duplicate lookup only: reverse scan vs resident index | 1,000 | 0.297 / 0.331 | 0.018 / 0.020 | 17× | 0.356 / 0.391 | 0.020 / 0.022 | 17× |
| Duplicate lookup only: reverse scan vs resident index | 10,000 | 3.04 / 3.19 | 0.018 / 0.023 | 173× | 3.58 / 3.65 | 0.023 / 0.028 | 156× |
| History search, sparse query | 1,000 | 2.96 / 3.01 | 0.594 / 0.636 | 5.0× | 3.38 / 3.51 | 0.817 / 0.860 | 4.1× |
| History search, sparse query | 10,000 | 33.1 / 34.7 | 6.41 / 6.56 | 5.2× | 38.6 / 40.4 | 9.09 / 9.35 | 4.2× |
| Naive whole-array scan (what the first prototype did) | 1,000 | 0.297 / 0.331 | 1.30 / 2.43 | 0.23× | 0.356 / 0.391 | 1.61 / 2.24 | 0.22× |
| Naive whole-array scan (what the first prototype did) | 10,000 | 3.04 / 3.19 | 22.6 / 25.9 | 0.13× | 3.58 / 3.65 | 24.9 / 26.9 | 0.14× |
| One-time snapshot of the history | 1,000 | — | 1.70 / 2.04 | — | — | 2.51 / 3.02 | — |
| One-time snapshot of the history | 10,000 | — | 25.4 / 26.1 | — | — | 29.2 / 37.8 | — |
| Ignore matching, single path | — | 0.013 / 0.014 | 0.029 / 0.038 | 0.45× | 0.014 / 0.015 | 0.034 / 0.044 | 0.42× |
| Ignore matching, 924-path batch | — | 9.20 / 9.66 | 7.34 / 8.39 | 1.25× | 10.0 / 10.3 | 8.42 / 9.57 | 1.19× |
| Recursive enumeration + filtering, 924 files | — | 19.99 / 20.15 | 17.22 / 18.24 | 1.16× | 21.6 / 22.0 | 18.9 / 19.6 | 1.14× |
| Cold CLR boot (single observation) | — | n/a | 82.0 | — | n/a | 93.0 | — |

What this says:

- **History is where C# pays off.** The add path and the search path win by about 4×
  to about 80× at every size and in both architectures, with a better p95 as well.
  The reverse-scan cost grows with the history; the resident index does not.
- **The design change mattered.** Sending the whole array on every call is 4-8×
  *slower* than the AHK scan it replaces; keeping the text resident turns that into
  a 17-170× win. Building the index once costs about 25-30 ms at 10,000 entries.
- **Ignore matching is a near wash.** One warm call through the bridge costs about
  2.2-2.4× one AHK call, so single-path checks stay in AHK. A 924-path batch is 1.2×
  faster, the whole walk 1.15×. The matching work (`PathMatchSpecW` plus regexes) is
  the same in both; AHK-side framing is only about 1.6 ms of the batch
  (`compare-ignore-batch-pack-ahk` 0.66 ms plus `-unpack-ahk` 0.92 ms), so a leaner
  wire format would not change this much.
- **Absolute savings are small at normal history sizes.** Pure AHK adds a clip in
  about 5 ms at 10,000 entries and filters a keystroke in about 33 ms. Both costs
  grow roughly linearly with the history (extrapolating, about 165 ms per keystroke
  at 50,000 entries).
- **One-time costs** are the CLR boot (70-100 ms across the runs so far; 82 and 93 ms
  above) and, for history, the snapshot above. They are paid on the first C#-routed
  call, never at startup.
- An earlier x86 run measured the enumeration at 30.7 ms for C# against 22.3 ms for
  AHK. It had run right after the naive whole-array scan; with the enumeration
  measured before the history workloads the same code took 21.1 ms, so the harness
  now orders them that way. That suggests (it is not proven) that managed garbage left
  by one workload can add around 10 ms to the next C# call. Nothing here measures
  that inside the real application.

Pure-AHK baselines on the same runner (x64, p50 ms): history save 14.1 at 1,000 and
153 at 10,000 entries; load 14.3 and 159; `Utils\Json.ahk` round trip 1,184 at
1,000 entries (superlinear, hence `-JsonMax`); ignore-rule compilation about 0.1;
`FileHelper.ShouldIgnore` 0.014.

Whole-process startup, idle CPU/working set, `CapsLock → Send` latency and Smart
Paste end-to-end figures come from `scripts\benchmark\Measure-CapsLockBuild.ps1`
and have **not** been run. Run both backends back-to-back on the same Windows
desktop, same power plan, on AC power, with at least three repetitions. Include
sparse and dense searches and small histories; marshalling/JIT costs can outweigh the
faster loop there.

Do not enable C# by default or change release packaging until the full workloads
win by at least **2× at p50**, are no worse at p95, preserve input/startup behavior,
and pass Windows equivalence/hotkey regressions. Against that bar the history
workloads qualify on these micro-benchmarks; the ignore workloads do not, and the
whole-process and input-latency checks have not been done. The C# ring removes a scan;
it cannot remove all remaining AHK, COM, disk or GUI costs.

## 6. Release scope and remaining work

The shipped x86/x64 executables now **package** the C# backend: `release.yml`
provisions the pinned bridge and the precompiled AnyCPU services, embeds both as
RCDATA resources through the generated `CSharpPayload.ahk`, verifies that the
finished executables really carry them, and publishes `CapsLockSharp.dll` next to
them (which is what the one-click setup downloads on a machine without the .NET
SDK). Packaging follows exactly the constraints this document set for it:
**precompiled** AnyCPU services, the exact hash-matching bridge, the matching AHK
source included at build time, and real DLL files extracted before CLR boot. No
user-side compiler, Roslyn/NuGet download or developer rebuild flag is involved,
and `AHKSHARP_DEV` rebuilds are still refused by `Services.Boot()`.

What did **not** change is the default: `[Services] Backend=ahk`. A packaged
executable behaves like the pure-AHK build until someone enables the backend, and
nothing C#-related runs at startup - the resources are unpacked on the first C#
request, and the CLR starts then. `scripts\build.ps1 -SkipCSharp` still produces
a pure-AHK executable from the same source, and an executable built that way says
so instead of pretending to install a backend it cannot reach (the AHK# library is
`#Include`d at compile time, so no file on disk can add it afterwards).

The bar in section 5 still applies to *enabling C# by default*: the history
workloads clear it on these micro-benchmarks, the ignore workloads do not, and the
whole-process and input-latency checks have not been done. Packaging the payload
changes what a release contains, not what the application does by default.

Outstanding verification: whole-process, input-latency and idle measurements on a
real desktop, now also with the packaged executable (a build that unpacks two DLLs
on first use is the one that ships); a visual pass over the history window
(`HistoryGuiPaging.ahk` checks its behavior, not its appearance); and PCRE/.NET
regex and non-ASCII case behavior on Windows versions other than the CI runner's.
Any unsupported generated expression must fail safely back to AHK. The bridge
needs .NET Framework 4.7.2+ (the CI runner has 4.8.x); older Windows 10 builds
have not been tried.

Possible later work, not part of this change: JSON/large history codecs (the AHK
`Utils\Json.ahk` round trip is superlinear, about 1.2 s for 1,000 entries, and is
the reason the harness has `-JsonMax`), and full file-content I/O.
