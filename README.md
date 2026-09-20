<div align="center">
  <img src="assets/hero.svg" alt="CapsLock Extended — a second keyboard control layer for Windows" width="1200" style="max-width:100%;height:auto;">
  <h1>CapsLock Extended</h1>
  <p><strong>Turn CapsLock into a predictable second control layer for Windows.</strong></p>
  <p>Text navigation · Clipboard · Windows · Window Hole · Quick Phrases · Documents</p>
  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases"><img src="https://img.shields.io/github/v/release/CYoJkoY/CapsLock-?style=flat-square&label=latest" alt="Latest release"></a>
    <a href="https://github.com/CYoJkoY/CapsLock-/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/CYoJkoY/CapsLock-/release.yml?style=flat-square&label=build" alt="Build status"></a>
    <img src="https://img.shields.io/badge/AutoHotkey-v2-5B86C9?style=flat-square" alt="AutoHotkey v2">
    <img src="https://img.shields.io/badge/platform-Windows-3A5A8C?style=flat-square" alt="Windows">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-C4A95E?style=flat-square" alt="GPL-3.0"></a>
  </p>
  <p>
    <a href="#readme-overview">Overview</a> ·
    <a href="#readme-features">Features</a> ·
    <a href="#readme-quick-start">Quick Start</a> ·
    <a href="#readme-development">Development &amp; Status</a> ·
    <a href="#readme-support">Support &amp; License</a>
  </p>
</div>

> **Design thesis:** CapsLock is not replaced. It becomes a modifier layer for related actions, while a double press keeps native CapsLock available.

<a name="readme-overview"></a>
## <img src="assets/readme/icons/overview.svg" width="20" height="20" alt=""> Overview

CapsLock Extended is a local Windows productivity utility written in **AutoHotkey v2**. Hold `CapsLock` and use a compact set of combinations for text navigation, selection, editing, clipboard workflows, window management, browser-tab navigation, Quick Phrases, Window Hole, and document conversion.

The project is intentionally centered on one interaction model:

```text
CapsLock
   ├─ text navigation / selection
   ├─ clipboard / paste
   ├─ windows / tabs
   ├─ Quick Phrase templates
   ├─ Window Hole
   └─ document conversion
```

**Requirements**

- Windows
- AutoHotkey v2 for running from source
- Optional ImageMagick and Pandoc for the features that use them

AutoHotkey v1 is not supported.

<a name="readme-features"></a>
## <img src="assets/readme/icons/features.svg" width="20" height="20" alt=""> Features

### Shortcut layer

All bindings below use `CapsLock` as the modifier unless noted otherwise.

| Category | Shortcut | Action |
| :--- | :--- | :--- |
| Native | `CapsLock ×2` | Toggle the native CapsLock state |
| Navigation | `Left / Right` | Move by word |
| Navigation | `Up / Down` | Jump to line start / end |
| Selection | `Shift + Left / Right` | Extend selection by word |
| Selection | `Shift + Up / Down` | Extend selection to line start / end |
| Selection | `Space` | Select the current word |
| Editing | `A / D` | Delete one character backward / forward |
| Editing | `Shift + A / Shift + D` | Delete one word backward / forward |
| Editing | `Backspace / Delete` | Delete the current line |
| Clipboard | `C` | Copy as plain text and add it to history |
| Clipboard | `V` | Paste using the current paste mode |
| Clipboard | `Shift + V` | Open the clipboard history menu |
| Clipboard | `F` | Change the case of the last copied text and paste it |
| Quick Phrase | `Shift + P` | Open the Quick Phrase selector |
| Documents | `P` | Convert clipboard file paths with Pandoc |
| Files | `Alt + Q` | Open the temporary folder used by file workflows |
| Window | `T` | Toggle always-on-top with OSD feedback |
| Window | `W / 8 / Num8` | Maximize / restore |
| Window | `S / 2 / Num2` | Minimize |
| Window | `Left Button` | Increase active-window opacity |
| Window | `Right Button` | Decrease active-window opacity |
| Window | `Middle Button` | Toggle 10% / 100% ghost mode |
| Window Hole | `X` | Activate Window Hole according to the configured activation mode |
| Window Hole | `X`, then `1` | Temporarily hide the current focused window and reveal the next layer; repeat while Window Hole is active |
| Browser tabs | `Q / E` | Previous / next browser tab |
| Help | `H / F1` | Open the built-in hotkey reference |

The built-in reference is also available from the tray UI and is intended to stay aligned with `Hotkeys/HotkeyReference.ahk`.

### Clipboard and smart paste

**Plain-text copy**

`CapsLock + C` copies the current selection as text and adds it to local clipboard history.

**Smart paste**

`CapsLock + V` routes the clipboard according to the configured paste mode. File-oriented workflows can handle single files, multiple files, directories, mixed paths, text-oriented controls, and supported image inputs.

**Clipboard history**

`CapsLock + Shift + V` opens the history menu. The full history interface supports search, multi-selection, batch operations, deletion, and paginated loading.

History retention is configurable. Automatic trimming can also be enabled for long-running installations.

### Quick Phrases

`CapsLock + Shift + P` opens a local searchable phrase selector.

Templates may contain variables such as:

```text
Please summarize {{topic}} for {{audience}} in {{language}}.
```

When a phrase is used:

1. Unique placeholders are detected in first-appearance order.
2. Each placeholder is requested once.
3. The completed text can be reviewed before insertion.
4. Confirming inserts the result into the application that was focused before the selector opened.

Templates without placeholders are inserted directly.

Phrase data is stored locally under:

```text
configs/
├── QuickPhrases.ini
└── QuickPhrases/
    └── phrase template files
```

The tray manager provides phrase creation, editing, deletion, categories, and ordering. The shortcut can be disabled without deleting the phrase library.

### Window Hole

`CapsLock + X` provides a temporary window-penetration mode.

The current implementation uses a native Win32 window region rather than a visual blur effect:

- the configured hole is cut from an eligible top-level window;
- the revealed lower window remains directly visible through the removed region;
- the hole follows the pointer while the mode is active;
- supported shapes are **circle**, **rounded rectangle**, and **square**;
- activation can be **hold** or **toggle**;
- second-level penetration can be enabled; while Window Hole is active, pressing `1` temporarily hides the current focused window, and repeated presses can traverse deeper window layers;
- incompatible windows can optionally use a temporary minimize fallback;
- executable and window-class allow/exclude rules can restrict eligible windows.

The default Window Hole settings are:

| Setting | Default |
| :--- | :--- |
| Diameter | `360 px` |
| Shape | `circle` |
| Activation | `hold` |
| Second level | enabled |
| Fallback minimize | enabled |
| Update interval | `30 ms` |

Releasing the mode restores the affected windows to their captured visual and window state.

### Window and tab controls

CapsLock also acts as a compact window-control layer:

- `T` toggles always-on-top and reports the state through OSD and sound feedback.
- `W`, `8`, and `Num8` maximize or restore the active window.
- `S`, `2`, and `Num2` minimize the active window.
- The mouse-button bindings adjust active-window opacity; the middle button switches between normal and 10% ghost mode.
- `Q` and `E` switch browser tabs using the corresponding `Ctrl+PgUp` / `Ctrl+PgDn` actions.

### Document conversion

`CapsLock + P` converts clipboard file paths through **Pandoc**.

The integration supports a broad list of Pandoc input/output formats, expands folders recursively, applies the configured ignore rules, and provides progress feedback for batch processing.

### Optional ImageMagick integration

ImageMagick is used for image-to-PDF workflows when required by smart paste.

It is optional; the core application remains usable without it.

### Localization

The project ships a CSV-based translation resource with **13 interface languages**:

```text
en · fr · zh · ja · ko · zh_TW · ru
pl · es · pt · de · tr · it
```

Language selection is available from the tray. Translation caches are generated locally from `lang.csv`.

<a name="readme-quick-start"></a>
## <img src="assets/readme/icons/installation.svg" width="20" height="20" alt=""> Quick Start &amp; Configuration

### Download a release

Download the latest executable from [GitHub Releases](https://github.com/CYoJkoY/CapsLock-/releases).

| Artifact | Target |
| :--- | :--- |
| `CapsLock-.exe` | Windows x64 |
| `CapsLock-_x86.exe` | Windows x86 |

Release builds are produced by GitHub Actions from version tags matching `v*.*.*`.

### Run from source

1. Install AutoHotkey v2.
2. Clone or download this repository.
3. Keep `CapsLock-.ahk` together with the repository's source directories.
4. Run `CapsLock-.ahk`.
5. Confirm the CapsLock- tray icon is visible.

The application creates its runtime `configs/` directory automatically.

### Optional integrations

#### ImageMagick

Install ImageMagick and configure `magick.exe` from the tray menu when image-to-PDF conversion is needed.

#### Pandoc

Install Pandoc and configure `pandoc.exe` from the tray menu when document conversion is needed. The same tray submenu controls the output format.

### Configuration files

Runtime configuration is kept outside the source modules:

```text
configs/
├── Config.ini
├── ClipHistory.bin
├── QuickPhrases.ini
└── QuickPhrases/
```

The application creates this directory automatically and does not require an account or network connection for normal local use.

Important configuration areas include:

| Area | Purpose |
| :--- | :--- |
| `[Cleanup]` | Delete mode, delete delay, cleanup interval |
| `[History]` | Clipboard history limit |
| `[General]` | Paste mode, auto-clean, language |
| `[QuickPhrase]` | Quick Phrase enable/disable state |
| `[Pandoc]` | Pandoc path and output format |
| `[WindowHole]` | Diameter, shape, activation, update interval, second level, fallback, executable/class rules |
| `[Ignore]` | Gitignore-style path/file patterns |

Most settings are intentionally exposed through the tray rather than requiring manual INI editing.

### Configuration defaults

The current code defines these notable defaults:

```text
History limit             10,000 entries
Delete mode               1 (delayed)
Delete delay              10 seconds
Cleanup interval          30 seconds
Paste mode                1
Auto history trim         disabled
Quick Phrase              enabled
Window Hole diameter      360 px
Window Hole shape         circle
Window Hole activation    hold
Window Hole second level  enabled
Window Hole fallback      enabled
```

The interface language is initialized by the language system and may be persisted in `[General]`.

### Security and privacy

Clipboard history is local data and may contain sensitive text, file paths, or application-specific content.

The history persistence layer applies a fixed XOR-based transform. This is **obfuscation, not strong cryptography**, and it should not be treated as protection against a local attacker.

For stronger protection, rely on Windows storage protections such as BitLocker or EFS around the relevant data rather than treating the built-in transform as a cryptographic boundary.

<a name="readme-development"></a>
## <img src="assets/readme/icons/development.svg" width="20" height="20" alt=""> Development &amp; Status

### Project structure

```text
CapsLock-/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
│       ├── release.yml
│       └── test.yml
├── Config/
├── Core/
├── History/
├── Hotkeys/
├── Tray/
├── UI/
├── Utils/
├── assets/
├── scripts/
├── CapsLock-.ahk
├── lang.csv
├── LICENSE
└── README.md
```

The entry script wires the project modules together and initializes language, configuration, clipboard history, Quick Phrases, cleanup, tray handling, and clipboard listeners.

The main functional boundaries are:

| Directory | Responsibility |
| :--- | :--- |
| `Config/` | Persistent application state and configuration |
| `Core/` | Clipboard, file, cleanup, Pandoc, Quick Phrase, Window Hole, and window utilities |
| `History/` | Clipboard history storage and interfaces |
| `Hotkeys/` | User-facing keyboard bindings and action routing |
| `Tray/` | Tray menus and settings |
| `UI/` | OSD, Quick Phrase UI, preview, and shared theme helpers |
| `Utils/` | Language and shared utility functions |
| `scripts/` | Build-time helper scripts |

### Architecture

CapsLock Extended keeps the keyboard layer, feature logic, state, and UI separated:

```text
CapsLock-.ahk
   │
   ├── Hotkeys ───────► actions
   ├── Core ──────────► feature logic
   ├── Config ────────► persistent state
   ├── History ───────► clipboard persistence / UI
   ├── Tray ──────────► configuration controls
   └── UI / Utils ────► presentation + shared services
```

This modular layout is intended to make individual features easier to change without turning the entry script into a monolith.

### Testing and release automation

The repository includes GitHub Actions for:

- source/build validation through `.github/workflows/test.yml`;
- tagged x86/x64 release builds through `.github/workflows/release.yml`.

Release compilation currently uses **AutoHotkey v2.0.27** through the configured AHK build action.

### Project status

The current implementation is centered on local Windows productivity workflows. Two larger features are explicitly planned but **not part of the shipped feature set yet**:

| Roadmap item | Status |
| :--- | :--- |
| [Custom low-glare light theme](https://github.com/CYoJkoY/CapsLock-/issues/41) | Planned |
| [Optional cloud sync](https://github.com/CYoJkoY/CapsLock-/issues/42) | Planned |

Cloud Sync is intended to remain optional; normal local use should not depend on a hosted CapsLock service.

### Known development considerations

Window Hole is a comparatively low-level feature because it interacts with native Win32 window regions, DWM attributes, hit testing, focus, and temporary window state. Changes in that area should be tested against overlapping windows, drag-and-drop, multiple DPI/scaling configurations, and special Windows applications.

Translation changes should be made in `lang.csv` and then checked through the generated language-cache path used by the application.

Shortcut changes should keep these sources synchronized:

```text
Hotkeys/HotkeyBindings.ahk
        ↓
Hotkeys/HotkeyReference.ahk
        ↓
built-in reference UI + README shortcut table
```

<a name="readme-support"></a>
## <img src="assets/readme/icons/architecture.svg" width="20" height="20" alt=""> Support &amp; License

### Support

CapsLock Extended is maintained as a local, modular utility. Support helps sustain ongoing maintenance, debugging, documentation, localization, and feature work.

<div align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="assets/readme/support-cta.svg" alt="Support CapsLock Extended" width="900" style="max-width:100%;">
  </a>
  <p><strong>Support:</strong> https://cyojkoy.github.io/Payment/</p>
</div>

### Bug reports and feature requests

Use GitHub Issues for reproducible bugs and focused feature requests.

For a useful bug report, include the Windows version, AutoHotkey version, affected shortcut or feature, reproduction steps, and the exact error text when available. Do not include clipboard contents, credentials, or other sensitive local data.

### License

CapsLock Extended is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text.

<div align="center"><sub>CapsLock as a second control layer for Windows.</sub></div>
