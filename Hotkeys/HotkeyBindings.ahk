#Requires AutoHotkey v2.0

*CapsLock:: {
    if !(A_PriorKey = "CapsLock")
        return
    if (A_TimeSincePriorHotkey > 300 || A_TimeSincePriorHotkey < 50)
        return
    if GetKeyState("CapsLock", "T")
        SetCapsLockState("AlwaysOff")
    else
        SetCapsLockState("AlwaysOn")
}

CapsLockHotkeysAvailable() {
    return GetKeyState("CapsLock", "P")
        && !HotkeySettingsGui.IsCapturing()
        && !FileDeleter.Busy
        && !AppState.QuickPhraseTransactionActive
        && !MouseControl.Active
        && ApplicationProfiles.IsHotkeysEnabledForActiveWindow()
}

CapsLockShortcutGroupAvailable(groupId) {
    return GetKeyState("CapsLock", "P")
        && !HotkeySettingsGui.IsCapturing()
        && !FileDeleter.Busy
        && !AppState.QuickPhraseTransactionActive
        && !MouseControl.Active
        && ApplicationProfiles.IsShortcutGroupEnabledForActiveWindow(groupId)
}

WindowOpacityHotkeysAvailable() {
    ; Check the hole and physical X before the foreground application profile.
    return !WindowHole.IsActive()
        && !HotkeyRegistry.IsHeld("windowHole")
        && CapsLockShortcutGroupAvailable("window")
}

QuickPhraseUiActive() {
    if AppState.QuickPhraseTransactionActive
        return true
    return IsObject(AppState.QuickPhraseGui)
    || IsObject(AppState.QuickPhraseVariableGui)
    || IsObject(AppState.QuickPhraseManagerGui)
}

QuickPhraseHotkeyAvailable() {
    return CapsLockShortcutGroupAvailable("quickphrase")
    && !QuickPhraseUiActive()
}

; True while the switcher's search box owns keyboard focus. Defined here so the
; hotkey variants below resolve it at load time; the switcher GUI itself is only
; touched at runtime.
WindowSwitcherSearchFocused() {
    try {
        if !IsObject(WindowSwitcherGui.Instance)
            return false
        if !WindowSwitcherGui.Instance.HasProp("SearchBox")
            return false
        return DllCall("user32\GetFocus", "Ptr")
        == WindowSwitcherGui.Instance.SearchBox.Hwnd
    } catch
        return false
}


; True only while the full-history search box or result list owns keyboard focus.
FullHistorySearchOrListFocused() {
    try {
        myGui := AppState.FullHistoryGui
        if !IsObject(myGui)
            return false
        if !myGui.HasProp("SearchBox") || !myGui.HasProp("ListView")
            return false

        focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        return focusedHwnd == myGui.SearchBox.Hwnd
            || focusedHwnd == myGui.ListView.Hwnd
    } catch
        return false
}


; Batch-selection shortcuts must not intercept text-editing keys in the search box.
FullHistoryListFocused() {
    try {
        myGui := AppState.FullHistoryGui
        if !IsObject(myGui) || !myGui.HasProp("ListView")
            return false
        return DllCall("user32\GetFocus", "Ptr") == myGui.ListView.Hwnd
    } catch
        return false
}


; True only while the command palette search field owns keyboard focus.
; Keep these navigation keys scoped to the palette so normal application input
; is untouched whenever the palette is closed.
CommandPaletteSearchFocused() {
    try {
        if !IsObject(CommandPaletteGui.Instance)
            return false
        if !CommandPaletteGui.Instance.HasProp("SearchBox")
            || !CommandPaletteGui.Instance.HasProp("ListView")
            return false

        focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        return focusedHwnd == CommandPaletteGui.Instance.SearchBox.Hwnd
            || focusedHwnd == CommandPaletteGui.Instance.ListView.Hwnd
    } catch
        return false
}

#HotIf CommandPaletteSearchFocused()
Up:: CommandPaletteGui.MoveSelection(-1)
Down:: CommandPaletteGui.MoveSelection(1)
PgUp:: CommandPaletteGui.MoveSelection(-5)
PgDn:: CommandPaletteGui.MoveSelection(5)
Enter:: CommandPaletteGui.RunSelected()
NumpadEnter:: CommandPaletteGui.RunSelected()
Esc:: CommandPaletteGui.Close()
#HotIf

; --- Window switcher (CapsLock + L) keyboard navigation ---
; Scoped to the switcher's search box so arrow keys move the selection while
; typing, without interfering with any other window or GUI.
#HotIf WindowSwitcherSearchFocused()
Up:: WindowSwitcherGui.MoveSelection(-1)
Down:: WindowSwitcherGui.MoveSelection(1)
PgUp:: WindowSwitcherGui.MoveSelection(-5)
PgDn:: WindowSwitcherGui.MoveSelection(5)
#HotIf

; Full-history navigation is active only while its search or result control has focus.
#HotIf FullHistorySearchOrListFocused()
Up:: MoveFullHistorySelection(-1)
Down:: MoveFullHistorySelection(1)
PgUp:: MoveFullHistorySelection(-5)
PgDn:: MoveFullHistorySelection(5)
Enter:: PasteSelectedFromFullHistory()
NumpadEnter:: PasteSelectedFromFullHistory()
#HotIf

; List-only actions: Space toggles a checkbox, Ctrl+Shift+L loads more rows,
; Delete removes the focused row, and Ctrl+A toggles visible checks. Search Edit keeps native editing behavior.
#HotIf FullHistoryListFocused()
Space:: ToggleFullHistoryFocusedCheck()
^a:: ToggleFullHistorySelectAll()
Home:: MoveFullHistorySelectionToBoundary(false)
End:: MoveFullHistorySelectionToBoundary(true)
^f:: FocusFullHistorySearch()
^+l:: LoadMoreFullHistoryEntries()
^c:: CopyFocusedFullHistoryEntry()
^+c:: CopySelectedFullHistoryEntriesAsText()
^+p:: PreviewFocusedFullHistoryEntry()
^Enter:: PasteFocusedFullHistoryEntryAsText()
^+Enter:: PasteSelectedFromFullHistoryText()
^+Delete:: DeleteSelectedFullHistoryEntries()
Delete:: DeleteFocusedFullHistoryEntry()
#HotIf

; CapsLock + Shift raises the top-edge progress bar as a short visual hint. The
; Shift shortcuts are real chords (CapsLock + Shift + W/S and the number-key
; aliases) and fire on their own, so this indicator never gates an action. It
; is unavailable while the native CapsLock light is on because Shift then
; controls the mouse layer.
#HotIf CapsLockHotkeysAvailable() && !MouseControl.EntryAvailable()
~Shift:: ActivateShiftLayer()
#HotIf

; Modal mouse control. The wildcard Shift binding catches both Shift keys and
; every modifier combination; two taps within the entry window are needed to
; enter, while a single tap exits. The movement and button keys restore their
; own native behavior as soon as the mode exits.
#HotIf MouseControl.EntryAvailable() || MouseControl.Active
*Shift:: MouseControl.ToggleFromShift()
#HotIf

~*Shift up:: MouseControl.ShiftReleased()

#HotIf MouseControl.Active
*Esc:: MouseControl.Stop()

*w:: MouseControl.UpdateMovementTimer()
*w up:: MouseControl.UpdateMovementTimer()
*a:: MouseControl.UpdateMovementTimer()
*a up:: MouseControl.UpdateMovementTimer()
*s:: MouseControl.UpdateMovementTimer()
*s up:: MouseControl.UpdateMovementTimer()
*d:: MouseControl.UpdateMovementTimer()
*d up:: MouseControl.UpdateMovementTimer()

*j:: MouseControl.PressButton("left")
*j up:: MouseControl.ReleaseButton("left")
*k:: MouseControl.PressButton("middle")
*k up:: MouseControl.ReleaseButton("middle")
*l:: MouseControl.PressButton("right")
*l up:: MouseControl.ReleaseButton("right")

*i:: MouseControl.StartScroll("up")
*i up:: MouseControl.StopScroll("up")
*m:: MouseControl.StartScroll("down")
*m up:: MouseControl.StopScroll("down")

*q:: MouseControl.StartHorizontalScroll("left")
*q up:: MouseControl.StopHorizontalScroll("left")
*e:: MouseControl.StartHorizontalScroll("right")
*e up:: MouseControl.StopHorizontalScroll("right")
#HotIf

; While the shortcut editor is capturing, mouse buttons and the wheel become
; replacement keys instead of running their normal CapsLock actions.
#HotIf HotkeySettingsGui.IsCapturing()
*LButton:: HotkeySettingsGui.CaptureMouse("LButton")
*RButton:: HotkeySettingsGui.CaptureMouse("RButton")
*MButton:: HotkeySettingsGui.CaptureMouse("MButton")
*XButton1:: HotkeySettingsGui.CaptureMouse("XButton1")
*XButton2:: HotkeySettingsGui.CaptureMouse("XButton2")
*WheelUp:: HotkeySettingsGui.CaptureMouse("WheelUp")
*WheelDown:: HotkeySettingsGui.CaptureMouse("WheelDown")
*WheelLeft:: HotkeySettingsGui.CaptureMouse("WheelLeft")
*WheelRight:: HotkeySettingsGui.CaptureMouse("WheelRight")
#HotIf

; Window Hole second-level penetration is registered as a global hotkey and
; enabled only for the lifetime of an active Window Hole session. This avoids
; #HotIf timing on the CapsLock + X + 1 sequence.
WindowHole.InitializeSecondLevelHotkey()
