<div align="center">
  <img src="assets/hero.svg" alt="CapsLock Extended — keyboard-first Windows productivity layer" width="1200" style="max-width: 100%; height: auto;">

  <p>
    <a href="https://www.autohotkey.com/"><img src="https://img.shields.io/badge/AutoHotkey-v2-5B86C9?style=flat-square&logo=autohotkey&logoColor=white" alt="AutoHotkey v2"></a>
    <img src="https://img.shields.io/badge/Platform-Windows-3A5A8C?style=flat-square&logo=windows&logoColor=white" alt="Windows">
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest"><img src="https://img.shields.io/github/v/release/CYoJkoY/CapsLock-?style=flat-square&label=Release&color=6FA572" alt="Latest release"></a>
    <a href="https://github.com/CYoJkoY/CapsLock-/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/CYoJkoY/CapsLock-/release.yml?style=flat-square&label=Build" alt="Build status"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-C4A95E?style=flat-square" alt="GPL-3.0"></a>
  </p>

  <p>
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-.exe"><strong>Download x64</strong></a>
    &nbsp;·&nbsp;
    <a href="https://github.com/CYoJkoY/CapsLock-/releases/latest/download/CapsLock-_x86.exe"><strong>Download x86</strong></a>
    &nbsp;·&nbsp;
    <a href="https://github.com/CYoJkoY/CapsLock-/releases">All releases</a>
  </p>
</div>

<div align="center">
  <img src="assets/dots.svg" alt="section separator" width="160" height="12">
</div>

## What is CapsLock Extended?

**CapsLock Extended** turns `CapsLock` into a keyboard-first modifier layer for Windows. Hold `CapsLock` and use familiar keys for text navigation, selection, editing, clipboard workflows, window control, tab switching, and document conversion.

It is built with **AutoHotkey v2** and keeps the native CapsLock state available through a double-click. The project is modular: the keyboard layer, clipboard pipeline, history system, configuration, tray UI, and optional external-tool integrations are separated into focused modules.

> [!IMPORTANT]
> **AutoHotkey v2 only.** AutoHotkey v1 is not supported.

## Why it is useful

The project is designed around one idea: **put frequent desktop actions behind a single consistent modifier**.

| Workflow | What it provides |
| :--- | :--- |
| Text navigation | Word-wise movement, line jumps, selection expansion, word selection, and fast deletion |
| Clipboard | Plain-text copy, smart paste, case conversion, history browsing, and batch paste |
| Files | Recursive folder expansion, validation, temporary-file handling, and ignore rules |
| Documents | Optional Pandoc conversion from clipboard file paths |
| Windows | Opacity control, ghost mode, always-on-top, maximize/restore, minimize, and window cycling |
| Tabs | Previous/next browser tab navigation and taskbar-based window switching |
| Interface | Dark tray menu, OSD feedback, configurable cleanup, and language switching |

## Shortcut map

Every shortcut in this table uses `CapsLock` as the modifier unless noted otherwise.

| Category | Shortcut | Action |
| :--- | :--- | :--- |
| System | `CapsLock` ×2 | Toggle the native CapsLock state |
| Navigation | `Left / Right` | Move one word left / right |
|  | `Up / Down` | Jump to line start / end |
|  | `Space` | Select the current word |
| Selection | `Shift + Left / Right` | Extend selection by word |
|  | `Shift + Up / Down` | Extend selection to line start / end |
| Editing | `A / D` | Delete one character backward / forward |
|  | `Shift + A / D` | Delete one word backward / forward |
|  | `Backspace / Delete` | Delete the current line |
| Clipboard | `C` | Copy as plain text and add to history |
|  | `V` | Paste using the current paste mode |
|  | `Shift + V` | Open clipboard history |
|  | `F` | Toggle case of the last copied English text and paste it |
|  | `P` | Convert clipboard file paths with Pandoc |
| Window | `T` | Toggle always-on-top with OSD feedback |
|  | `W / 8 / Num8` | Maximize or restore the active window |
|  | `S / 2 / Num2` | Minimize the active window |
| Mouse | `Left Button` | Increase active-window opacity |
|  | `Right Button` | Decrease active-window opacity |
|  | `Middle Button` | Toggle 10% / 100% ghost-mode opacity |
| Tabs / Windows | `Q / E` | Previous / next tab |
|  | `Shift + Q / Shift + E` | Previous / next taskbar window |

## Clipboard-first workflows

### Smart paste

`CapsLock + V` uses the configured paste mode and can work with file paths rather than text alone. File-oriented workflows can validate paths, expand directories recursively, process images, and place the resulting files into the target application.

### Clipboard history

`CapsLock + Shift + V` opens the history interface. The history subsystem supports previewing entries, searching, selecting multiple records, pasting batches, and deleting stored entries.

The project keeps clipboard history locally. The stored history is transformed with a fixed XOR-based routine; this should be treated as local data protection rather than strong cryptography. fileciteturn16file0L1-L2

### Ignore rules and cleanup

File-based paste workflows can use gitignore-style patterns to exclude unwanted paths. Temporary files can be managed through configurable delayed cleanup, batch cleanup, or disabled automatic deletion.

## Optional document conversion

CapsLock Extended can integrate with **Pandoc** for document conversion and **ImageMagick** for image-to-PDF workflows.

The external tools are optional. The core modifier, navigation, clipboard, window, and tray functionality remains available without either dependency.

### Pandoc

1. Install Pandoc.
2. Set the `pandoc.exe` path from the tray menu.
3. Choose an output format.
4. Copy file paths and press `CapsLock + P`.

The script exposes a broad Pandoc format set; `docx` is the default output format in the current configuration. fileciteturn8file0L2-L2

### ImageMagick

1. Install ImageMagick.
2. Set the `magick.exe` path from the tray menu.
3. Use the image-to-PDF workflow through the smart-paste pipeline.

## Window and desktop controls

The modifier layer is not limited to text editing. Mouse combinations can change the opacity of the active window, while `CapsLock + Middle Button` switches between near-transparent and fully opaque states. `CapsLock + T` toggles always-on-top and provides sound and OSD feedback. fileciteturn13file0L2-L2

Taskbar-oriented window switching is handled by the utility layer, allowing `Shift + Q / Shift + E` to move through windows without leaving the keyboard. fileciteturn5file0L2-L2

## Installation

### Recommended: prebuilt executable

Download the latest build from [Releases](https://github.com/CYoJkoY/CapsLock-/releases).

| Build | File |
| :--- | :--- |
| 64-bit Windows | `CapsLock-.exe` |
| 32-bit Windows | `CapsLock-_x86.exe` |

The release workflow builds both targets from `CapsLock-.ahk` with AutoHotkey v2 and embeds the project icon. fileciteturn11file0L2-L2

### From source

1. Install **AutoHotkey v2**.
2. Clone or download this repository.
3. Keep `CapsLock-.ahk` alongside its included directories.
4. Run `CapsLock-.ahk` with AutoHotkey v2.
5. Confirm that CapsLock Extended is running in the Windows system tray.

## Configuration

Configuration is loaded from the runtime `configs` directory and is created automatically when needed. The current configuration state includes clipboard limits, paste mode, cleanup behavior, external executable paths, Pandoc output format, language selection, and ignore rules. fileciteturn8file0L2-L2

Most user-facing options are exposed through the tray menu:

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

The bundled `lang.csv` currently defines 13 interface languages: English, French, Simplified Chinese, Japanese, Korean, Traditional Chinese, Russian, Polish, Spanish, Portuguese, German, Turkish, and Italian. fileciteturn10file0L1-L2

## How the code is organized

```text
CapsLock-/
├── .github/
│   └── workflows/
│       └── release.yml
├── Config/
│   ├── ConfigManager.ahk
│   ├── Encryption.ahk
│   └── Globals.ahk
├── Core/
│   ├── Clipboard.ahk
│   ├── ClipboardPaste.ahk
│   ├── Cleanup.ahk
│   ├── FileOperations.ahk
│   ├── FileValidation.ahk
│   ├── ImageToPdf.ahk
│   ├── Pandoc.ahk
│   └── WindowUtils.ahk
├── History/
│   ├── CustomMenu.ahk
│   ├── FullHistoryGui.ahk
│   ├── FullHistoryHandlers.ahk
│   ├── HistoryDelete.ahk
│   ├── HistoryMenu.ahk
│   ├── HistoryPaste.ahk
│   └── HistoryStorage.ahk
├── Hotkeys/
│   ├── HotkeyActions.ahk
│   ├── HotkeyBindings.ahk
│   └── PasteHandler.ahk
├── Tray/
│   ├── TrayMenu.ahk
│   └── TraySettings.ahk
├── UI/
├── Utils/
├── assets/
│   ├── CapsLock-.ico
│   ├── dots.svg
│   └── hero.svg
├── CapsLock-.ahk
├── lang.csv
├── LICENSE
└── README.md
```

The entry script loads the utility, configuration, core, history, hotkey, tray, and UI modules before initializing language, configuration, history, cleanup, and clipboard handling. fileciteturn6file0L2-L2

## Release workflow

Releases are generated automatically when a `v*.*.*` tag is pushed. The workflow builds:

- `CapsLock-.exe` — x64
- `CapsLock-_x86.exe` — x86

Both builds use the project's `assets/CapsLock-.ico` icon and are uploaded directly to the GitHub Release. fileciteturn11file0L2-L2

## Security and privacy

CapsLock Extended is a local Windows utility. Its core features do not require a cloud account or external authentication service.

Clipboard history can contain sensitive text, paths, and files. Review the retention and cleanup configuration before using the program with confidential data.

The history transform in `Config/Encryption.ahk` is XOR-based and uses a fixed key. It should **not** be presented as strong encryption or as protection against a determined local attacker. fileciteturn16file0L1-L2

When using Pandoc or ImageMagick, point the application only at executables you trust.

## Development

The project is plain AutoHotkey v2 rather than a compiled framework application, so the easiest development loop is to edit the `.ahk` modules and run `CapsLock-.ahk` directly.

For changes affecting shortcuts, keep the user-facing shortcut table synchronized with `Hotkeys/HotkeyBindings.ahk`. For changes affecting settings or runtime state, update the relevant configuration modules and tray controls together.

Issues and pull requests are welcome. Bug reports are most useful when they include the Windows version, AutoHotkey version, affected shortcut or feature, and the exact error message. Do not include private clipboard contents or sensitive local paths.

## License

CapsLock Extended is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text.

## Support the Author

If this project saves you time or improves your workflow, consider supporting its development.

<div align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/Support_the_Author-9E8F7E?style=for-the-badge&logo=buy-me-a-coffee&logoColor=BEB8AE" alt="Support the Author">
  </a>
</div>

<div align="center">
  <sub>Keyboard-first automation for Windows, built with AutoHotkey v2.</sub>
</div>
