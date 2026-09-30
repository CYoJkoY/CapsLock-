# Hybrid AHK + AHK#/.NET architecture (issue #12)

**Status: boundary prototyped, baseline harness ready, no measurements yet.**

CI is green: `AutoHotkey64.exe /Validate` passes on the whole script,
`scripts\HotkeyRegression.ahk` passes all of its checks, and
`src\CapsLockSharp\` compiles. No benchmark has been run, **every result
table below is empty**, and the boundary itself has never been exercised —
which is the whole reason the tables exist.

This document exists so that moving *anything* out of AutoHotkey is a measured
decision. Do not fill the tables in from memory, from another machine, or from
a build that is not the one being evaluated.

---

## 1. The principle

> High-frequency input paths stay in native AutoHotkey.
> Computation-heavy, data-heavy and I/O-heavy services may move to C#.

Concretely, for this codebase:

| Stays in AutoHotkey, always | May move to C# |
| :-- | :-- |
| every hotkey and the CapsLock layer | history duplicate scan and search |
| `Send`, `SendInput`, key state | ignore-rule compilation and matching |
| the clipboard itself (`A_Clipboard`, `OpenClipboard`) | text normalisation and preview truncation |
| every GUI, menu, tray and theme | file-tree enumeration and filtering |
| `DllCall` (269 call sites) | JSON / serialisation of large payloads |
| Pandoc and ImageMagick, as **external processes** | — |

The last row is a hard rule, not a preference: Pandoc and ImageMagick are
external binaries invoked as child processes today, and they stay that way.
There is nothing to gain from wrapping a process launch in .NET, and there is a
lot to lose — their output parsing, quoting and timeout handling all work.

---

## 2. AHK#

[`owhs/AHKSharp`](https://github.com/owhs/AHKSharp) hosts the .NET Framework
4.x CLR **inside** the AutoHotkey process and talks to it through a small
COM-visible bridge DLL. From AHK you get `CS.System.Math.Pow(5, 3)`, embedded
C# classes, async/await, delegates and NuGet.

| | |
| :-- | :-- |
| Pinned to | commit `e3b895c7590eba47748b0ed963b7978c237d1daf` (2026-09-23, branch `main`) |
| Tags available | **none** — a commit is the only reproducible reference |
| Runtime needed | `lib\ahk#.ahk` + `lib\ahk#.bridge.dll` |
| User requirements | AutoHotkey v2.0+, Windows 7 SP1+, .NET Framework 4.0+ (pre-installed on Windows 10/11) |
| Admin / Visual Studio / NuGet CLI | not required |
| CLR bitness | follows the AutoHotkey exe that hosts it |
| First `CS` call | boots the CLR, about **100 ms** |

### Limitations that shape this design

Read from the project's own README and docs at the pinned commit:

* **The CLR is .NET Framework 4.x.** No `Span<T>`, no `System.Index`/`Range`,
  no default interface members, no async streams. NuGet packages that only
  target `net5.0+` are refused. C# 9–12 *syntax* works through Roslyn, but the
  runtime is still Framework 4.
* **The AppDomain cannot be unloaded.** Loaded assemblies stay until the
  process exits, so a service that recompiles or reloads per call is a leak.
* **Async, events and worker-thread callbacks need AHK's message pump.** If
  the AHK thread blocks inside a synchronous .NET call that waits for workers
  (`Task.Run(fn).Wait()`, `Parallel.ForEach`), the worker gets a
  `TimeoutException` after 5 s. A clipboard utility has no business blocking
  its own message pump, so **the migrated services are synchronous and pure**.
* **`out`/`ref` work on method calls only**, not constructors, `.Async` or
  `_CSModule` methods. Generic *methods* are inferred from arguments alone.
  Both are reasons to keep the boundary narrow.
* **The bridge DLL is hash-pinned.** `Boot()` verifies its SHA-256 against the
  value inside `ahk#.ahk` by default. Ship the exact DLL that belongs to the
  `ahk#.ahk` you compiled in.
* **Runtime compilation needs a compiler.** `csc.exe` from the .NET Framework
  is used when the bridge is missing, and Roslyn is downloaded for modern C#.
  Neither belongs on a user's machine, which is why §7 requires precompiled
  assemblies.

---

## 3. What was built

```
scripts\perf\CapsLockProfile.ahk     baseline + AHK-vs-C# comparison harness
Core\Services.ahk                    the AHK <-> C# boundary, off by default
src\CapsLockSharp\                   candidate C# implementations
    CapsLockSharp.csproj             netstandard2.0, AnyCPU, deterministic
    HistoryService.cs                duplicate scan, insert, remove, search
    IgnoreMatcher.cs                 gitignore-style rules, compiled and cached
    ClipboardService.cs              file-path-list test, normalise, preview
Config\Globals.ahk                   AppState.ServiceBackend
Config\ConfigManager.ahk             [Services] Backend, loaded and saved
```

### The boundary is guarded three ways

1. **Off by default.** `AppState.ServiceBackend` is `"ahk"` unless someone
   writes `[Services] Backend=csharp` into Config.ini. Adding the module
   changed no behaviour.
2. **Circuit breaker.** The first exception sets `Services.tripped` and the
   backend is never touched again for the rest of the process. A broken bridge
   costs one exception, not a degraded session.
3. **Every call has an AutoHotkey half.** `Services.Dispatch` runs the C#
   function, and on any failure falls back and counts it.

### The CLR is never booted at start-up

`Services.Configure()`, called right after `ConfigManager.Load()`, only reads a
string. `Services.Boot()` — which hosts the CLR, ~100 ms — runs on the first
service call that actually asks for the C# backend. With the default
configuration it never runs at all.

### AHK# is deliberately not vendored

The library ships a prebuilt `ahk#.bridge.dll`. Committing a binary we did not
build, and re-pinning its hash on every upgrade, is a supply-chain decision
that should be made explicitly, not smuggled in with a prototype. The module
looks for AHK# on disk and reports `AHK# is not installed` when it is absent.

To enable the C# path:

```powershell
git clone https://github.com/owhs/AHKSharp.git lib\ahk#
cd lib\ahk#; git checkout e3b895c7590eba47748b0ed963b7978c237d1daf
dotnet build src\CapsLockSharp\CapsLockSharp.csproj -c Release -o lib
```

then add `#Include lib\ahk#\lib\ahk#.ahk` to `CapsLock-.ahk` **above** every
other include, and set `[Services] Backend=csharp`.

---

## 4. Running the baseline

```powershell
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk -Clipboard
AutoHotkey64.exe /ErrorStdOut scripts\perf\CapsLockProfile.ahk -History 1000,10000,50000 -Files 20
```

The script loads the project's **real** modules — `HistoryManager`,
`FileHelper`, `Json` — and times the exact code a migrated service would
replace. It builds a throwaway file tree in `%TEMP%`, fills a history to the
requested sizes, runs every workload, then deletes the workspace.

Whole-process figures (start-up, idle CPU, idle memory, `CapsLock → Send`
latency, Smart Paste end to end) are **not** measured here; they come from
`scripts\benchmark\Measure-CapsLockBuild.ps1` and share their protocol: same
machine, same session, AC power, same power plan, nothing else running, at
least three repetitions, both candidates measured back to back.

### Workloads

| Benchmark | What it measures |
| :-- | :-- |
| `history-add-new-<n>` | the real "copy something new" cost: reverse duplicate scan, `InsertAt(1)`, `Pop` |
| `history-add-duplicate-top-<n>` | re-copying the most recent clip, the one-comparison fast path |
| `history-save-<n>` / `history-load-<n>` | the binary codec in `DoSave` / `Load`, including `CryptBuffer` |
| `json-roundtrip-<n>` | `Json.Stringify` + `Json.Parse` of a full history |
| `ignore-shouldignore` | `FileHelper.ShouldIgnore` over a real file corpus |
| `ignore-build-patterns` | `FileHelper.BuildIgnoreRegexes`, the compile step |
| `file-enum-recursive-with-ignore` | `CollectFilesFromFolder`, the walk *plus* per-path matching |
| `file-enum-recursive-no-ignore` | the same walk with no rules, to separate the two costs |
| `clipboard-text-roundtrip` | `A_Clipboard` write and read (opt-in; it overwrites the clipboard) |
| `compare-*-ahk` / `compare-*-csharp` | the same inputs through both halves of the boundary |

---

## 5. Baseline — the numbers that must exist first

*Fill in from `scripts\perf\results\baseline-*.md`. Leave a cell blank rather
than estimating it.*

### 5.1 History service

Measured on: _______ — machine _______, AutoHotkey _______, build _______

| Benchmark | n | p50 (ms) | p95 (ms) | min (ms) | max (ms) |
| :-- | --: | --: | --: | --: | --: |
| `history-add-new-1000` | | | | | |
| `history-add-duplicate-top-1000` | | | | | |
| `history-save-1000` | | | | | |
| `history-load-1000` | | | | | |
| `json-roundtrip-1000` | | | | | |
| `history-add-new-10000` | | | | | |
| `history-add-duplicate-top-10000` | | | | | |
| `history-save-10000` | | | | | |
| `history-load-10000` | | | | | |
| `json-roundtrip-10000` | | | | | |

### 5.2 File service and ignore matcher

Corpus: _______ files, _______ ignore rules

| Benchmark | n | p50 (ms) | p95 (ms) | min (ms) | max (ms) |
| :-- | --: | --: | --: | --: | --: |
| `ignore-shouldignore` | | | | | |
| `ignore-build-patterns` | | | | | |
| `file-enum-recursive-with-ignore` | | | | | |
| `file-enum-recursive-no-ignore` | | | | | |

### 5.3 Clipboard and end-to-end paths

| Measurement | Source | Result |
| :-- | :-- | :-- |
| `clipboard-text-roundtrip` | `CapsLockProfile.ahk -Clipboard` | |
| clipboard copy → history insert | `history-add-new-*` | |
| Smart Paste, end to end | `Measure-CapsLockBuild.ps1` | |
| `CapsLock → Send` latency | `Measure-CapsLockBuild.ps1` | |
| start-up to idle | `Measure-CapsLockBuild.ps1` | |
| idle CPU | `Measure-CapsLockBuild.ps1` | |
| idle working set | `Measure-CapsLockBuild.ps1` | |

---

## 6. AHK vs C# on identical workloads

*These stay empty until AHK# is installed and `CapsLockSharp.dll` is built, at
which point `CapsLockProfile.ahk` fills them in automatically.*

| Benchmark | AHK p50 (ms) | C# p50 (ms) | AHK p95 | C# p95 | Verdict |
| :-- | --: | --: | --: | --: | :-- |
| `compare-ignore-match` | | | | | |
| `compare-history-scan` | | | | | |

### Reading the history-scan row honestly

`compare-history-scan-csharp-naive` passes **the whole array across the
boundary on every call**, so it includes marshalling that a finished
`HistoryService` would not pay: the real design keeps the list resident on the
.NET side and sends only the candidate text. Treat that row as a **worst case**.
If the naive number already wins, the service is worth migrating; if it loses,
the next step is a resident-state API (`Load` / `Add` / `Search` across the
boundary, no bulk transfer per call) before drawing any conclusion.

### Decision rule

A service moves to C# only when all three hold on the same machine, in the same
session:

1. the C# path is **at least 2× faster** at p50 *and* no worse at p95;
2. start-up and idle are unchanged — the ~100 ms CLR boot must be paid lazily
   and must never show up in the cold-start figure;
3. `scripts\perf\ServiceEquivalence.ahk` and `scripts\HotkeyRegression.ahk`
   both pass with the backend enabled.

"2×" is deliberately strict. A migration costs a permanent second language, a
second build, a second release artefact and a new failure mode; 20 % is not
worth that for a clipboard utility that spends most of its life idle.

---

## 7. Release packaging: precompiled assemblies only

The acceptance criteria require precompiled .NET assemblies in release builds.
That is not a preference, it is forced by AHK#:

* `ahk#.bridge.dll` **must be a real file** when the runtime starts. In a
  compiled script it travels inside the exe and is extracted with `FileInstall`.
* Compiling C# at run time needs `csc.exe` or a Roslyn download. Neither is
  acceptable on a user's machine.
* Modules ship as `PrecompiledDLL`, which needs no compiler at all.

So a release that enables the C# backend carries:

```
CapsLock-.exe                 (Ahk2Exe output, x64)
    extracts, on first use:  ahk#.bridge.dll      (FileInstall, hash-pinned)
                             CapsLockSharp.dll    (FileInstall, precompiled)
```

`.github\workflows\dotnet.yml` builds the assembly on every change under
`src\CapsLockSharp\` and publishes it as the `CapsLockSharp-netstandard2.0`
artifact. It is **not** wired into `release.yml`: no DLL ships inside the
release while the default backend is AHK.

Rules for the release job, when that changes:

* build `CapsLockSharp.csproj` with `dotnet build -c Release`, **AnyCPU** — one
  assembly serves both the x86 and the x64 exe, because the CLR takes the
  bitness of the host exe;
* `netstandard2.0` is the target: loadable by the Framework 4.x CLR that AHK#
  hosts, and buildable on a runner with nothing but the .NET SDK;
* ship the exact `ahk#.bridge.dll` that matches the `ahk#.ahk` in the build;
* put the `FileInstall` lines **above** any module class definition, because a
  class initialises as soon as its definition is reached;
* set `CS.Config.BridgeDll` **before the first `CS` use**.

---

## 8. Acceptance criteria

| Criterion | Status |
| :-- | :-- |
| Establish and document a reproducible performance baseline | Harness ready (`scripts\perf\CapsLockProfile.ahk`), §5 tables **empty — not yet run** |
| Add an AHKSharp integration without changing existing user-facing hotkeys | `Core\Services.ahk`, off by default, no hotkey touched |
| Prototype ClipboardService | `ClipboardService.cs` + `Services.LooksLikeFilePathList` |
| Benchmark AHK and C# implementations using identical workloads | `compare-*` workloads, §6 tables **empty** |
| Prototype HistoryService if the benchmark justifies migration | `HistoryService.cs` written; **migration not justified until §6 is filled in** |
| Prototype FileService / IgnoreMatcher if benchmarks justify migration | `IgnoreMatcher.cs` written; **same condition** |
| Preserve existing behavior and configuration | Default backend is AHK; `[Services] Backend` is loaded and saved like every other setting |
| Add regression tests for migrated services | `scripts\perf\ServiceEquivalence.ahk` — **not yet written** |
| Package precompiled .NET assemblies for release builds | `.github\workflows\dotnet.yml` builds and publishes the assembly; wiring it into `release.yml` waits on §6 |

The outstanding items are deliberately blocked on the same thing: there is no
point writing equivalence tests, or shipping a DLL inside the release, for a
migration that the measurements may yet reject. Building the assembly in CI is
cheap and keeps the project honest about whether it still compiles.

---

## 9. Known gaps

* **What has run, and what has not.** `AutoHotkey64.exe /Validate` passes on
  the whole script and `scripts\HotkeyRegression.ahk` passes all of its
  checks, both on a real Windows runner. `src\CapsLockSharp\` compiles in
  CI. What has **not** run anywhere is `scripts\perf\CapsLockProfile.ahk`:
  it needs a real Windows desktop, so every table in §5 and §6 is empty until
  someone runs it. The C# services have never been called from AutoHotkey, so
  the boundary itself is unproven — no measurement, no migration.
* **The C# implementations are ports, not proven equals.** `IgnoreMatcher`
  replaces `PathMatchSpecW` with compiled .NET regexes; the semantics of
  Windows glob matching are close but not identical, and the equivalence tests
  are what would settle it.
* **Array marshalling is unmeasured.** Whether a 10,000-element AHK array
  crosses into `string[]` efficiently, or at all, is exactly what
  `compare-history-scan-csharp-naive` is there to find out.
* **AHK# itself is young.** Seven commits, no tags, fourteen stars, at the
  pinned commit. Its own test workflow is "written, but not yet exercised on
  GitHub". That is a reason to keep the circuit breaker, not necessarily a
  reason to avoid it.
* **One machine is not a lab.** A result here justifies a decision for this
  project; it is not a published benchmark.
