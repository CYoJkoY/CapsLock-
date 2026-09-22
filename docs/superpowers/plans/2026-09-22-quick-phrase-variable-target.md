# Quick Phrase Current-Mouse Output Architecture

## Goal

Make `CapsLock + Shift + P` insert the final Quick Phrase text at the output-time mouse position instead of preserving the window/control that happened to be focused when the selector opened.

## Architecture

Quick Phrase is split into two independent concerns:

```text
CapsLock + Shift + P
        ↓
Quick Phrase selector
        ↓
Select phrase
        ↓
Optional variable dialog
        ↓
Destroy Quick Phrase UI
        ↓
Resolve window/control under current mouse position
        ↓
Activate that window
        ↓
Click current mouse position
        ↓
Paste completed clipboard text
```

The selector and variable dialog only compose the phrase. They do not capture, store, restore, or mutate a destination window/control.

AutoHotkey v2 `MouseGetPos` is used with flag `2` so the output-time target control HWND can be identified when one exists. The final `Click()` intentionally has no coordinates: it acts at the cursor's current physical position, allowing the target application to perform normal hit-testing and caret placement.

Clipboard backup/restoration remains local to `QuickPhrasePasteText()` and is independent of target resolution.

## Implementation boundaries

- `UI/QuickPhraseGui.ahk` owns phrase selection, variable composition, output-time target resolution, and final Quick Phrase paste.
- `AppState.TargetWindow` remains owned by the existing generic paste workflows; Quick Phrase must never use it.
- `Core/QuickPhraseTarget.ahk` is removed because the historical target/focus-restoration abstraction is no longer part of Quick Phrase.
- Quick Phrase persistence, categories, selection, double-click behavior, variable substitution, multiline input, and clipboard restoration remain unchanged.
- `CapsLock + Shift + P` remains unchanged.

## Output contract

### Fixed phrase

```text
select phrase
    ↓
selector destroyed
    ↓
resolve current mouse target
    ↓
activate target
    ↓
click current cursor position
    ↓
Ctrl+V completed phrase
```

### Variable phrase

```text
select variable phrase
    ↓
fill variables
    ↓
click OK
    ↓
variable dialog destroyed
    ↓
resolve current mouse target
    ↓
activate target
    ↓
click current cursor position
    ↓
Ctrl+V completed phrase
```

## Failure behavior

- If no window exists beneath the mouse, Quick Phrase reports the existing paste-failure message and does not send Ctrl+V.
- If the resolved target is one of CapsLock-'s own visible UI windows, Quick Phrase refuses to paste.
- If the target window disappears before activation, Quick Phrase fails without falling back to another active window.
- Clipboard restoration always runs in `finally`, including activation/paste failures.

## Validation gate

Use the existing Windows AutoHotkey syntax CI gate. Do not add new test suites or fixture files for this change.

Perform source-level review for:
- no `QuickPhrasePasteTarget` or `QuickPhraseTarget` references remain;
- Quick Phrase never assigns `AppState.TargetWindow`;
- fixed and variable phrases share the same final `QuickPhrasePasteText()` path;
- target resolution occurs only after the Quick Phrase GUI has been destroyed;
- final delivery uses current mouse-position hit-testing;
- generic clipboard/history paste behavior is untouched.

The final manual Windows check should cover a fixed phrase and a variable phrase in at least a standard native text field and a Chromium/Electron-style text surface.