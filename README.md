<div align="center">
  <img src="assets/hero.svg" alt="CapsLock Extended — a second keyboard control layer for Windows" width="1200" style="max-width: 100%; height: auto;">

  <h1>CapsLock Extended</h1>
  <p><strong>Turn CapsLock into a predictable second control layer for Windows.</strong></p>
  <p>Text · Clipboard · Windows · Tabs · Files · Documents</p>

  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest"><img src="https://img.shields.io/github/v/release/CYoJkoY/CapsLock-?style=flat-square&label=latest" alt="Latest release"></a>
    <a href="https://github.com/CYoJkoY/CapsLock-/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/CYoJkoY/CapsLock-/release.yml?style=flat-square&label=build" alt="Build status"></a>
    <img src="https://img.shields.io/badge/AutoHotkey-v2-5B86C9?style=flat-square" alt="AutoHotkey v2">
    <img src="https://img.shields.io/badge/platform-Windows-3A5A8C?style=flat-square" alt="Windows">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-C4A95E?style=flat-square" alt="GPL-3.0"></a>
  </p>

  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-.exe"><strong>Download x64</strong></a>
    ·
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-_x86.exe"><strong>Download x86</strong></a>
    ·
    <a href="#start-here">Shortcuts</a>
  </p>
</div>

> **The idea:** one rarely-used key becomes a stable modifier layer. The physical keyboard stays unchanged, common actions move close to the home position, and `CapsLock ×2` still exposes native CapsLock.

## What it is

CapsLock Extended is a local Windows utility written in **AutoHotkey v2**. Hold `CapsLock` and use a compact set of combinations for text navigation, selection, deletion, clipboard workflows, window management, browser tabs, and file-oriented operations.

The project deliberately avoids becoming a second global-hotkey language. The modifier stays constant; only the action changes.

**Requirements:** AutoHotkey v2. AutoHotkey v1 is not supported.

## Start here

Every shortcut below uses `CapsLock` as the modifier unless noted otherwise.

| Area | Shortcut | Action |
| :--- | :--- | :--- |
| System | `CapsLock ×2` | Toggle native CapsLock |
| Navigation | `Left / Right` | Move one word left / right |
| Navigation | `Up / Down` | Jump to line start / end |
| Selection | `Space` | Select the current word |
| Selection | `Shift + Left / Right` | Extend selection by word |
| Selection | `Shift + Up / Down` | Extend selection to line start / end |
| Editing | `A / D` | Delete one character backward / forward |
| Editing | `Shift + A / D` | Delete one word backward / forward |
| Editing | `Backspace / Delete` | Delete the current line |
| Clipboard | `C` | Copy as plain text and add to history |
| Clipboard | `V` | Paste using the current paste mode |
| Clipboard | `Shift + V` | Open clipboard history |
| Clipboard | `F` | Toggle case of the last copied English text and paste |
| Documents | `P` | Convert clipboard file paths with Pandoc |
| Window | `T` | Toggle always-on-top with OSD feedback |
| Window | `W / 8 / Num8` | Maximize or restore |
| Window | `S / 2 / Num2` | Minimize |
| Mouse | `Left Button` | Increase active-window opacity |
| Mouse | `Right Button` | Decrease active-window opacity |
| Mouse | `Middle Button` | Toggle 10% / 100% ghost mode |
| Tabs | `Q / E` | Previous / next browser tab |
| Windows | `Shift + Q / Shift + E` | Previous / next taskbar window |

## Why the layer works

The same modifier carries related actions, so the mental model remains stable instead of growing into a large collection of unrelated shortcuts.

### Text control

Word-wise navigation, line jumps, selection expansion, word selection, and deletion stay near the home position.

### Clipboard control

The clipboard pipeline supports plain-text copying, configurable paste modes, local history, case conversion, batch paste, and file-aware actions.

### Window and tab control

Always-on-top, maximize/restore, minimize, opacity, ghost mode, browser tab switching, and taskbar window switching share the same modifier.

### File and document workflows

Smart paste can validate paths, expand directories recursively, process image inputs, and manage temporary files. Optional Pandoc and ImageMagick integrations extend these workflows without becoming requirements for the core modifier layer.

## Clipboard-first workflows

### Smart paste

`CapsLock + V` follows the configured paste mode. File-oriented modes can validate paths, expand directories recursively, process images, and place the resulting files into the target application.

### Clipboard history

`CapsLock + Shift + V` opens the local history interface. Entries can be previewed, searched, selected in batches, pasted, and deleted.

History stays local. Its current persistence layer uses a fixed XOR-based transform; this is **local obfuscation, not strong cryptography**.

### Ignore rules and cleanup

File-based paste workflows support gitignore-style exclusions and configurable temporary-file cleanup, including delayed cleanup, batch cleanup, or disabled automatic deletion.

## Optional integrations

The modifier layer itself does not require third-party tools.

**Pandoc** converts clipboard file paths into document formats. Configure `pandoc.exe` in the tray settings, choose the output format, then use `CapsLock + P`.

**ImageMagick** adds image-to-PDF processing to smart-paste workflows. Configure `magick.exe` in the tray settings when that pipeline is needed.

## Configuration

Runtime configuration is created under the `configs` directory when needed.

| Setting | Purpose |
| :--- | :--- |
| ImageMagick | Select the ImageMagick executable |
| Pandoc | Select the executable and output format |
| Cleanup | Delayed, batch, or disabled temporary-file cleanup |
| History | Configure clipboard-history retention |
| Paste Mode | Paste as files or text with source information |
| Ignore Rules | Manage gitignore-style exclusions |
| Language | Change the interface language |
| Auto Start | Enable Windows startup integration |
| Reload / Exit | Restart or close the application |

The bundled UI currently supports 13 languages.

## Installation

### Recommended: release build

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
5. Confirm that CapsLock Extended is running in the Windows system tray.

The release workflow builds both architectures and regenerates the application icon from [`assets/CapsLock-icon.svg`](assets/CapsLock-icon.svg) before embedding it in the executables.

## Architecture

```text
CapsLock-.ahk
    │
    ├── Config/       settings, globals, local data transform
    ├── Core/         clipboard, paste, files, cleanup, windows, conversion
    ├── History/      clipboard-history storage and UI
    ├── Hotkeys/      bindings and actions
    ├── Tray/         tray menu and settings
    ├── UI/           interface components
    └── Utils/        shared utilities
```

The application separates shortcut definitions, clipboard behavior, settings, and UI concerns so individual subsystems remain independently maintainable.

## Release model

Release builds are created automatically from `v*.*.*` tags.

```text
Git tag
  │
  ▼
regenerate icon → build x64 + x86 → publish artifacts
```

Published artifacts are:

- `CapsLock-.exe` — x64
- `CapsLock-_x86.exe` — x86

## Security and privacy

CapsLock Extended is a local Windows application. The core program does not require a cloud account or external authentication service.

Clipboard history may contain sensitive text, paths, or files. Review retention and cleanup settings before using it with confidential data.

The history transform uses a fixed XOR key and is **not** a security boundary against a determined local attacker.

Only configure Pandoc or ImageMagick to trusted executables.

## Development

The normal loop is intentionally simple:

```text
edit .ahk modules → run CapsLock-.ahk → test → package through CI
```

When changing shortcuts, keep the user-facing table synchronized with the hotkey binding module. When changing runtime settings, update the configuration modules and tray controls together.

## Contributing

Useful contributions add a clear capability, fix a concrete defect, improve compatibility, or reduce complexity without hiding behavior.

For bug reports, include the Windows version, AutoHotkey version, affected shortcut or feature, and the exact error message. Do not include private clipboard contents or sensitive local paths.

## Support

Development support is available through the project payment page:

**https://cyojkoy.github.io/Payment/**

## License

CapsLock Extended is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text.

<div align="center">
  <sub>CapsLock as a second control layer for Windows.</sub>
</div>
