<div align="center">
  <img src="assets/hero.svg" alt="CapsLock Extended — a second keyboard control layer for Windows" width="1200" style="max-width: 100%; height: auto;">

  <h1>CapsLock Extended</h1>
  <p><strong>Turn one rarely-used key into a second control layer for everyday Windows work.</strong></p>
  <p>Text navigation · Clipboard · Windows · Tabs · Files · Optional document tools</p>

  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest"><img src="https://img.shields.io/github/v/release/CYoJkoY/CapsLock-?style=flat-square&label=latest%20release" alt="Latest release"></a>
    <a href="https://github.com/CYoJkoY/CapsLock-/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/CYoJkoY/CapsLock-/release.yml?style=flat-square&label=build" alt="Build status"></a>
    <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2-5B86C9?style=flat-square" alt="AutoHotkey v2"></a>
    <img src="https://img.shields.io/badge/platform-Windows-3A5A8C?style=flat-square" alt="Windows">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-C4A95E?style=flat-square" alt="GPL-3.0"></a>
  </p>

  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-.exe"><strong>Download x64</strong></a>
    ·
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-_x86.exe"><strong>Download x86</strong></a>
    ·
    <a href="#installation">Install from source</a>
  </p>
</div>

> **At a glance:** CapsLock becomes a consistent modifier. The physical keyboard stays unchanged, common desktop actions stay near the home position, and a double press still exposes native CapsLock.

## What it is

CapsLock Extended is a local Windows utility written in **AutoHotkey v2**. Hold `CapsLock` as a modifier and use a compact key layer for navigation, selection, clipboard workflows, window control, browser tabs, and file-oriented actions.

The core idea is deliberately narrow: do not replace the keyboard and do not add a new global-hotkey vocabulary. Reuse one existing key to create a predictable second control layer.

> **Compatibility:** AutoHotkey v2 is required. AutoHotkey v1 is not supported.

## Start here

Every shortcut below uses `CapsLock` as the modifier unless noted otherwise.

| Area | Shortcut | Result |
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
| Clipboard | `F` | Toggle case of the last copied English text and paste it |
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

The same modifier carries multiple workflows, so the mental model remains stable instead of turning into a collection of unrelated global shortcuts.

### Text control

Word-wise navigation, line jumps, selection expansion, deletion, and word selection all stay close to the home position.

### Clipboard control

The clipboard pipeline supports plain-text copying, configurable paste modes, history, case conversion, batch paste, and file-oriented operations.

### Window and tab control

The layer covers always-on-top, maximize/restore, minimize, opacity, ghost mode, browser tab switching, and taskbar window switching.

### File and document workflows

Smart paste can validate file paths, expand directories recursively, process image inputs, and manage temporary files. Optional Pandoc and ImageMagick integrations extend those workflows without becoming requirements for the core layer.

## Clipboard-first workflows

### Smart paste

`CapsLock + V` uses the configured paste mode. File-oriented workflows can validate paths, expand directories recursively, process images, and place the resulting files into the target application.

### Clipboard history

`CapsLock + Shift + V` opens the local history interface. Entries can be previewed, searched, selected in batches, pasted, and deleted.

History is stored locally. The current storage layer uses a fixed XOR-based transform, which is **local data protection rather than strong cryptography**.

### Ignore rules and cleanup

File-based paste workflows support gitignore-style exclusions and configurable temporary-file cleanup, including delayed cleanup, batch cleanup, or disabled automatic deletion.

## Optional integrations

The modifier layer does not require third-party tools.

### Pandoc

Use Pandoc when clipboard file paths should be converted into a document format.

1. Install Pandoc.
2. Select `pandoc.exe` in the tray settings.
3. Choose an output format.
4. Copy file paths and press `CapsLock + P`.

The current configuration exposes a broad Pandoc format set with `docx` as the default output.

### ImageMagick

Use ImageMagick for image-to-PDF workflows in the smart-paste pipeline.

1. Install ImageMagick.
2. Select `magick.exe` in the tray settings.
3. Use the image-to-PDF workflow through smart paste.

## Configuration

Configuration lives in the runtime `configs` directory and is created automatically when needed.

| Setting | Purpose |
| :--- | :--- |
| ImageMagick | Select or change the ImageMagick executable |
| Pandoc | Select the executable and output format |
| Cleanup | Delayed, batch, or disabled temporary-file cleanup |
| History | Configure clipboard-history retention |
| Paste Mode | Paste as files or text with source information |
| Ignore Rules | Manage gitignore-style exclusions |
| Language | Change the interface language |
| Auto Start | Enable Windows startup integration |
| Reload / Exit | Restart or close the application |

The bundled interface currently supports 13 languages: English, French, Simplified Chinese, Japanese, Korean, Traditional Chinese, Russian, Polish, Spanish, Portuguese, German, Turkish, and Italian.

## Installation

### Recommended: prebuilt release

Download the latest Windows build from the [Releases](https://github.com/CYoJkoY/CapsLock-/releases) page.

| Build | Artifact |
| :--- | :--- |
| 64-bit Windows | `CapsLock-.exe` |
| 32-bit Windows | `CapsLock-_x86.exe` |

### From source

1. Install **AutoHotkey v2**.
2. Clone or download this repository.
3. Keep `CapsLock-.ahk` alongside its included directories.
4. Run `CapsLock-.ahk` with AutoHotkey v2.
5. Confirm that CapsLock Extended is running in the Windows system tray.

The release workflow builds both architectures and regenerates the application icon from [`assets/CapsLock-icon.svg`](assets/CapsLock-icon.svg) before embedding it in the executables.

## Architecture

The project separates the modifier layer from reusable subsystems:

```text
CapsLock-.ahk
    │
    ├── Config/       settings, globals, local data transform
    ├── Core/         clipboard, paste, files, cleanup, windows, conversion
    ├── History/      clipboard-history storage and UI
    ├── Hotkeys/      bindings, actions, paste handling
    ├── Tray/         tray menu and settings
    ├── UI/           user-interface components
    └── Utils/        shared utilities
```

This makes shortcut behavior, clipboard behavior, settings, and interface code independently maintainable instead of putting the entire application behind one large script.

## Release workflow

Releases are created automatically when a `v*.*.*` tag is pushed.

```text
Git tag
  │
  ▼
regenerate icon → build x64 + x86 → publish release artifacts
```

The workflow packages:

- `CapsLock-.exe` — x64
- `CapsLock-_x86.exe` — x86

## Security and privacy

CapsLock Extended is a local Windows utility. The core program does not require a cloud account or external authentication service.

Clipboard history may contain sensitive text, paths, and files. Review retention and cleanup settings before using the application with confidential data.

The history transform is XOR-based with a fixed key. It is **not** intended to protect clipboard contents against a determined local attacker.

When configuring Pandoc or ImageMagick, point the application only at executables you trust.

## Development

The normal development loop is intentionally simple:

```text
edit .ahk modules → run CapsLock-.ahk → test → package through release workflow
```

When changing shortcuts, keep the user-facing table synchronized with `Hotkeys/HotkeyBindings.ahk`. When changing runtime settings, update the configuration modules and tray controls together.

For bug reports, include the Windows version, AutoHotkey version, affected shortcut or feature, and the exact error message. Do not include private clipboard contents or sensitive local paths.

## Contributing

Useful contributions add a clear capability, improve an existing workflow, fix a concrete defect, or reduce complexity without obscuring behavior.

For shortcut or setting changes, update the implementation and the corresponding documentation together.

## Support

If CapsLock Extended saves you time or improves your workflow, development support is available through the deployed payment page:

**https://cyojkoy.github.io/Payment/**

## License

CapsLock Extended is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text.

<div align="center">
  <sub>CapsLock as a second control layer for Windows.</sub>
</div>
