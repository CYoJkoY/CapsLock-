# AHKCompiler evaluation (issue #46)

**Status: harness ready, no measurements yet.**

Everything in this directory exists so the question "should the release switch
from Ahk2Exe to [AHKCompiler](https://github.com/owhs/AHKCompiler)?" can be
answered with numbers instead of opinions. **This document deliberately
contains no results.** The scripts have never been run against a real Windows
host from this repository, so every number below is a blank cell. Do not fill
them in from memory, from a different machine, or from a different build — run
the harness and fill them in from its output.

---

## 1. What is being decided

| | |
| :-- | :-- |
| Current compiler | `benmusson/ahk2exe-action@v1`, Ahk2Exe against AutoHotkey **v2.0.28** |
| Candidate | `owhs/AHKCompiler`, "AHK2 Builder & Compiler" |
| Pinned to | commit `ede37a56ed49b6dcfa52f8697dda30fc8c40b671` (2026-09-17, branch `main`) |
| Published artifacts that must not change | `CapsLock-.exe` (x64) and `CapsLock-_x86.exe` (x86) |

The pin is a **commit, not a branch or a tag**, because the project publishes
no tags and `main` can move at any time. Every documented behaviour in this
file was read from the README at that commit.

### Hard requirements for a switch

1. **Both x64 and x86** outputs are produced. The release ships two files
   today and must keep doing so.
2. **Artifact names, icon and version resources are unchanged.** A user
   replacing the exe must not see a different icon or a blank version tab.
3. **Behaviour is identical.** `scripts/HotkeyRegression.ahk` and a real
   `AutoHotkey64.exe /Validate` run against the compiled script must pass.
4. **The measurements justify it.** "Smaller" alone is not a reason to change
   the tool that produces what users download.

If any of the four fails, the answer is "keep Ahk2Exe" and this document
records that as the outcome.

---

## 2. What the candidate can and cannot strip here

AHKCompiler can compile AutoHotkey from source with individual features
removed. Which levers are actually available depends entirely on what the
script uses, so the codebase was audited against the feature list at the
pinned commit.

| Lever | Available for CapsLock-? | Evidence |
| :-- | :-- | :-- |
| RegEx → Windows ICU backend (drops ~130 KB of PCRE) | **Yes** | 11 `RegExMatch`, 10 `RegExReplace`, 19 `~=`; **zero** uses of the ICU-unsupported constructs `(?C`, `(?R`, `(?U` |
| C runtime → `ucrt.dll` (~180 KB) | **Yes** | no dependency on the statically linked CRT |
| DBGp script debugger (~43 KB) | **Yes** | never used at runtime |
| Strip RegEx entirely (151 KB) | No | the app is full of pattern matching |
| Strip COM (20 KB, also removes ActiveX) | No | `Utils/HttpClient.ahk` (`WinHttp.WinHttpRequest.5.1`) and `Utils/TaskbarOrder.ahk` (`Shell.Application`) |
| Strip `DllCall` / `CallbackCreate` (8 KB) | No | 269 `DllCall` call sites |
| Strip GUI (90 KB) | No | the app *is* GUI |
| Strip GUI ListView / TreeView / StatusBar (11 KB) | No | `History/FullHistoryGui.ahk` uses a ListView |
| Offload RegEx Unicode tables (74 KB) | Careful | only safe while no pattern needs a Unicode class outside ICU's tables |
| NTFS `compact` the exe | Yes | packaging only, no behaviour change |

**Realistic best case** is therefore the ICU RegEx backend plus the shared C
runtime plus the debugger, on top of whatever the size-optimised build already
saves — not the full "strip everything" figure.

Two further properties matter and are separate from size:

* **Removing a function is loud, not silent.** A script that calls a stripped
  function fails at load with a clear message. That is exactly why the
  behavioural gate in §5 matters more than the size table.
* **There are two engine modes.** *Build from source* (~20–50 s, needs MSVC)
  supports feature stripping and the ICU backend. *Prebuilt base* (~0.2 s,
  `UpdateResource` into an existing exe) is essentially Ahk2Exe with the same
  output — it **skips** feature stripping, the Windows RegEx backend, import
  hardening, string scrubbing and embedded-script encryption. A "prebuilt base"
  measurement says nothing about AHKCompiler; only the from-source engine is
  worth benchmarking.

---

## 3. Producing a candidate build

### 3.1 Through CI (recommended — reproducible)

`.github/workflows/release.yml` has an `ahkcompiler` job that is **off by
default**. It never publishes: the exe lands in a workflow artifact called
`CapsLock-AHKCompiler-eval`.

1. *Actions* → *Build and Release* → *Run workflow*.
2. `compiler` → `ahkcompiler` (or `both`).
3. `profile` → an AHKCompiler profile name (default `Engine: lean`).
4. Download the artifact and unzip it next to the Ahk2Exe build.

The job also runs `AHK2BC.cmd /list` and `cli.ahk /features` as
`continue-on-error` steps. Those two steps are the authoritative list of
profile names and feature switches for the pinned commit — read their output
in the run log before trusting the `profile` input.

A tag push is unaffected: it still builds both targets with Ahk2Exe and
uploads them, and the release upload is now guarded by
`startsWith(github.ref, 'refs/tags/')` so a manual dispatch can no longer
create or overwrite a release from a branch ref.

### 3.2 Locally

Requirements, all of which a `windows-latest` runner already has:

* Visual Studio Build Tools with the **Desktop development with C++** workload
* Git for Windows (source fetch and patch application)
* AutoHotkey v2 (to run the builder itself)
* Windows 10 1903+ / Windows 11 for the ICU RegEx backend

```powershell
git clone https://github.com/owhs/AHKCompiler.git tools\AHKCompiler
cd tools\AHKCompiler
git checkout ede37a56ed49b6dcfa52f8697dda30fc8c40b671
AHK2BC.cmd /list                 # real profile names for this commit
AHK2BC.cmd /build "Engine: lean"
```

Output lands in `tools\AHKCompiler\out`.

### 3.3 Artifact-equivalence checks (do these first)

Before measuring anything, confirm the candidate is even a valid replacement:

| Check | How | Result |
| :-- | :-- | :-- |
| x64 produced | file exists | ☐ |
| x86 produced | file exists | ☐ |
| main icon present | open the exe properties, compare with `assets\CapsLock-.ico` | ☐ |
| version resource populated | compare `(Get-Item .\CapsLock-.exe).VersionInfo` with the Ahk2Exe build — product name, version, company, copyright | ☐ |
| loads without error | `AutoHotkey64.exe /ErrorStdOut /Validate` on the compiled script | ☐ |
| source-level checks | `AutoHotkey64.exe /ErrorStdOut .\scripts\HotkeyRegression.ahk` | ☐ |
| launches and reaches idle | `scripts\benchmark\Measure-CapsLockBuild.ps1` (see §4) | ☐ |

---

## 4. The measurement harness

```
scripts\benchmark\
    CapsLockBench.psm1            Win32 interop + measurement helpers
    Measure-CapsLockBuild.ps1     measures ONE build, writes JSON + Markdown
    Compare-CapsLockBuilds.ps1    compares two result files, writes a verdict
```

Everything is measured **from outside the process**. Neither build is
instrumented, so a compiled-by-AHKCompiler exe and a compiled-by-Ahk2Exe exe
are measured in exactly the same way and any difference is a real difference.

### What is measured

| Metric | Definition |
| :-- | :-- |
| executable size, SHA-256 | from the file on disk |
| start-up | time from launch until the process stops advancing its CPU time (see below) |
| idle working set / private KB | last sample after a configurable settle period |
| idle CPU % | `KernelTime + UserTime` delta over a sample window, divided by wall time |
| idle handles, GDI, USER objects | `GetProcessHandleCount`, `GetGuiResources` |
| `CapsLock + T` latency | key press → `WS_EX_TOPMOST` changes on a scratch window |
| `CapsLock + C` latency | key press → `GetClipboardSequenceNumber()` advances |
| `CapsLock + Shift + V` latency | key press → a new visible window owned by the script PID appears |
| resident-feature soak | drives always-on-top, clipboard history, quick phrase, cheatsheet, spotlight, dynamic zoom, window hole and window switcher, then reports handle/thread/GDI/USER/private-KB deltas and whether the process survived |

**Start-up needs no app instrumentation.** "Idle" is defined as four
consecutive 100 ms samples where total CPU time does not advance. That works
identically for both builds and is the one definition that does not require
adding code to the app.

**Polling uses `Thread.Sleep(0)`, not `Start-Sleep`.** The latencies being
measured are the same order of magnitude as the Windows timer tick
(~15.6 ms), so a `Start-Sleep 1` poll would hide everything.

**Latency probes need an interactive session.** They synthesise key events and
observe real windows. On a locked or headless session the script detects this
and skips them, recording `skip_latency` in the environment block so the
comparison can report "not measured" instead of a fake number.

### Protocol — follow this or the numbers mean nothing

1. Same machine, same Windows session, **both builds measured back to back**.
2. AC power, the **same power plan**, high performance.
3. No other user work. Close browsers, IDEs, sync clients and chat apps.
4. Nothing else touching the clipboard — a cloud clipboard sync will corrupt
   the `CapsLock + C` probe.
5. No Windows Update, indexing, antivirus scan or Defender quick scan.
6. Run each build at least 3 times (`-Repetitions 3`); use 5 if the numbers
   look unstable.
7. Do not compare results produced on different days. Start both runs in the
   same session.
8. Let the machine settle for a minute after logging in before the first run.

```powershell
# x64, current compiler
.\scripts\benchmark\Measure-CapsLockBuild.ps1 `
    -ExePath .\build\CapsLock-.exe `
    -Profile ahk2exe-x64 `
    -OutDir .\bench

# x64, candidate
.\scripts\benchmark\Measure-CapsLockBuild.ps1 `
    -ExePath .\build-ahkcompiler\CapsLock-.exe `
    -Profile ahkcompiler-x64 `
    -OutDir .\bench

# then the same pair for _x86
```

Each run writes `<profile>.json`, `<profile>.env.json` and `<profile>.md` into
`.\bench`.

---

## 5. Comparing

```powershell
.\scripts\benchmark\Compare-CapsLockBuilds.ps1 `
    -Baseline  .\bench\ahk2exe-x64.json `
    -Candidate .\bench\ahkcompiler-x64.json
```

Every metric gets a **noise band** = `max(absolute floor, |baseline| × relative
floor)`, because the interesting differences are small and the uninteresting
ones are everywhere:

| Metric | Absolute floor | Relative floor |
| :-- | :-- | :-- |
| executable size | 0 bytes | 0 % (deterministic) |
| start-up | 25 ms | 5 % |
| idle working set / private | 512 KB | 3 % |
| idle CPU | 0.05 % | 10 % |
| idle handles / GDI | 5 / 3 | 5 % |
| latency p50 | 1.5 ms | 5 % |
| latency p95 | 3 ms | 5 % |
| soak deltas | 1024 KB, 25 handles, 15 GDI/USER | 20 % |

A change inside the band is reported as **`same`** — that is a result, not a
failure to measure.

The comparison also refuses to guess across environments: if `machine`,
`cpu_name`, `cpu_cores`, `power_plan`, `os_build` or `ahk_version` differ
between the two files, every verdict becomes **`not comparable`**.

Use `-FailOnRegression` to exit with code 2 when anything is significantly
worse, which is how you would wire this into a pipeline later.

---

## 6. Results

### 6.1 x64

*Fill in from `Compare-CapsLockBuilds.ps1`. Leave a cell blank rather than
estimating it.*

| Metric | Ahk2Exe | AHKCompiler | Change | Verdict |
| :-- | --: | --: | --: | :-- |
| Executable size (bytes) | | | | |
| Start-up to idle (ms) | | | | |
| Idle working set (KB) | | | | |
| Idle private bytes (KB) | | | | |
| Idle CPU (%) | | | | |
| Idle handles | | | | |
| Idle GDI objects | | | | |
| `CapsLock + T` p50 (ms) | | | | |
| `CapsLock + T` p95 (ms) | | | | |
| `CapsLock + C` p50 (ms) | | | | |
| `CapsLock + C` p95 (ms) | | | | |
| `CapsLock + Shift + V` p50 (ms) | | | | |
| `CapsLock + Shift + V` p95 (ms) | | | | |
| Soak: process alive | | | | |
| Soak: delta handles | | | | |
| Soak: delta private KB | | | | |

Measured on: _______ — machine _______, power plan _______, build _______

### 6.2 x86

| Metric | Ahk2Exe | AHKCompiler | Change | Verdict |
| :-- | --: | --: | --: | :-- |
| Executable size (bytes) | | | | |
| Start-up to idle (ms) | | | | |
| Idle working set (KB) | | | | |
| Idle private bytes (KB) | | | | |
| Idle CPU (%) | | | | |
| `CapsLock + T` p50 (ms) | | | | |
| `CapsLock + C` p50 (ms) | | | | |
| Soak: process alive | | | | |

### 6.3 Artifact equivalence

| Check | x64 | x86 |
| :-- | :-- | :-- |
| Icon preserved | ☐ | ☐ |
| Version resource preserved | ☐ | ☐ |
| `HotkeyRegression.ahk` passes | ☐ | ☐ |
| Notable behaviour differences | | |

---

## 7. Decision

Record the outcome here once §6 is filled in, including the build SHA-256s and
the date.

| Question | Answer |
| :-- | :-- |
| Do both targets build? | |
| Are name / icon / version resources identical? | |
| Is any metric significantly worse? | |
| Is any metric significantly better, and does it matter to a user? | |
| **Decision** | keep Ahk2Exe / switch AHKCompiler |
| If switching: which profile, and what is the new release job? | |

A switch needs: no regression that a user would feel, both targets, unchanged
artifact identity, and a benefit worth the risk of changing what produces the
download. Size alone does not qualify — nobody notices 150 KB. Start-up,
idle CPU and hotkey latency are the metrics that matter; size is a tiebreak.

---

## 8. Known gaps in this harness

Stated plainly, because a benchmark that hides its own limits is worse than no
benchmark.

* **Never executed.** No PowerShell exists in the environment where these
  scripts were written, so they are unproven. Expect to fix syntax or scoping
  errors on the first real run; the first thing to do is run
  `Measure-CapsLockBuild.ps1 -SkipLatency -SkipSoak -Repetitions 1` on any
  build to smoke-test the non-interactive path.
* **The AHKCompiler CLI surface is partly inferred.** The entry points
  (`AHK2BC.cmd /build "<profile>"`, `/list`, `cli.ahk /features`) and the two
  engine modes come from the README at the pinned commit, and could not be
  re-verified when this document was written. The CI job prints `/list` and
  `/features` output precisely so the real surface is visible in the log.
* **How AHKCompiler selects x86 vs x64 is unconfirmed.** It may be a profile
  setting, an environment flag or a separate profile. Confirm it from the
  `/list` output and, if needed, add a second profile for the x86 build.
* **Output naming is unconfirmed.** The job copies every `*.exe` it finds
  under `tools\AHKCompiler\out`; if the builder derives names differently,
  rename in the "Collect the compiled output" step so §6 tables stay legible.
* **Idle CPU is a floor, not an absolute.** Any background driver or service
  that wakes the process shows up in both builds equally, which is exactly
  why the comparison is valid even though the absolute number is not.
* **One machine is not a lab.** A result here is good enough to justify
  keeping or changing the release compiler; it is not a published benchmark.
