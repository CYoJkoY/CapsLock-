<div align="center">
  <img src="assets/hero.svg" alt="CapsLock Extended — a second keyboard control layer for Windows" width="1200" style="max-width:100%;height:auto;">
  <h1>CapsLock Extended</h1>
  <p><strong>Turn one rarely-used key into a predictable second control layer for Windows.</strong></p>
  <p>Text navigation · Clipboard · Windows · Tabs · Files · Documents</p>
  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases"><img src="https://img.shields.io/github/v/release/CYoJkoY/CapsLock-?style=flat-square&label=latest" alt="Latest release"></a>
    <a href="https://github.com/CYoJkoY/CapsLock-/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/CYoJkoY/CapsLock-/release.yml?style=flat-square&label=build" alt="Build status"></a>
    <img src="https://img.shields.io/badge/AutoHotkey-v2-5B86C9?style=flat-square" alt="AutoHotkey v2">
    <img src="https://img.shields.io/badge/platform-Windows-3A5A8C?style=flat-square" alt="Windows">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-C4A95E?style=flat-square" alt="GPL-3.0"></a>
  </p>
  <p><a href="#what-it-is">Overview</a> · <a href="#core-layer">Core layer</a> · <a href="#installation">Install</a> · <a href="#architecture">Architecture</a> · <a href="#development--support">Development</a></p>
</div>

> **Design thesis:** CapsLock is not replaced; it becomes a stable modifier layer. Native CapsLock remains available through a double press.

## <img src="assets/readme/icons/overview.svg" width="20" height="20" alt=""> What it is

CapsLock Extended is a local Windows utility written in **AutoHotkey v2**. Hold `CapsLock` and use a compact set of combinations for text navigation, editing, clipboard workflows, window control, browser tabs, and file-oriented operations.

The project keeps the modifier constant so related actions share one mental model instead of becoming an unrelated collection of global shortcuts.

**Requirements:** AutoHotkey v2. AutoHotkey v1 is not supported.

## <img src="assets/readme/icons/features.svg" width="20" height="20" alt=""> Core layer

Every shortcut below uses `CapsLock` as the modifier unless noted otherwise.

| Area | Shortcut | Action |
| :--- | :--- | :--- |
| System | `CapsLock ×2` | Toggle native CapsLock |
| Navigation | `Left / Right` | Move one word left / right |
| Navigation | `Up / Down` | Jump to line start / end |
| Selection | `Space` | Select the current word |
| Selection | `Shift + Left / Right` | Extend selection by word |
| Editing | `A / D` | Delete one character backward / forward |
| Editing | `Shift + A / D` | Delete one word backward / forward |
| Clipboard | `C` | Copy as plain text and add to history |
| Clipboard | `V` | Paste using the current paste mode |
| Clipboard | `Shift + V` | Open clipboard history |
| Window | `T` | Toggle always-on-top |
| Window | `W / 8 / Num8` | Maximize / restore |
| Window | `S / 2 / Num2` | Minimize |
| Tabs | `Q / E` | Previous / next browser tab |
| Windows | `Shift + Q / Shift + E` | Previous / next taskbar window |

### Clipboard-first workflows

`CapsLock + V` follows the configured paste mode. File-oriented modes can validate paths, expand directories recursively, process images, and manage temporary files.

`CapsLock + Shift + V` opens the local clipboard history. Entries can be searched, previewed, batch-selected, pasted, or deleted.

History uses a fixed XOR-based transform for local data handling. This is **obfuscation, not strong cryptography**.

### Optional document tools

Pandoc can convert clipboard file paths into document formats. ImageMagick can extend smart-paste image-to-PDF workflows. Neither is required for the core modifier layer.

## <img src="assets/readme/icons/architecture.svg" width="20" height="20" alt=""> Architecture

The codebase separates the modifier layer from reusable subsystems:

```text
CapsLock-.ahk
    │
    ├── Config/       settings and local state
    ├── Core/         clipboard, paste, files, windows, conversion
    ├── History/      clipboard-history storage and UI
    ├── Hotkeys/      bindings and actions
    ├── Tray/         settings and lifecycle controls
    ├── UI/           interface components
    └── Utils/        shared utilities
```

The release process regenerates the application icon, then builds both x64 and x86 artifacts from the same source tree.

## <img src="assets/readme/icons/installation.svg" width="20" height="20" alt=""> Installation

### Release build

Download the latest executable from [Releases](https://github.com/CYoJkoY/CapsLock-/releases).

| Build | Artifact |
| :--- | :--- |
| 64-bit Windows | `CapsLock-.exe` |
| 32-bit Windows | `CapsLock-_x86.exe` |

### From source

1. Install **AutoHotkey v2**.
2. Clone or download this repository.
3. Keep `CapsLock-.ahk` beside its included directories.
4. Run `CapsLock-.ahk` with AutoHotkey v2.
5. Confirm the tray application is running.

## <img src="assets/readme/icons/development.svg" width="20" height="20" alt=""> Development & support

For behavior changes, keep the shortcut table synchronized with the hotkey binding module. For configuration changes, update both the settings implementation and the tray controls.

For bug reports, include the Windows version, AutoHotkey version, affected shortcut or feature, and exact error message. Do not include clipboard contents, tokens, or sensitive local paths.

<a href="https://cyojkoy.github.io/Payment/"><img src="assets/readme/support-cta.svg" alt="Support CapsLock Extended" width="900" style="max-width:100%;height:auto;"></a>

Development support: **https://cyojkoy.github.io/Payment/**

## License

CapsLock Extended is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text.

<div align="center"><sub>CapsLock as a second control layer for Windows.</sub></div>
