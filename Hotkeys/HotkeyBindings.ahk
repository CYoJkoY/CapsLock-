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
        && !AppState.QuickPhraseTransactionActive
        && ApplicationProfiles.IsHotkeysEnabledForActiveWindow()
}

CapsLockShortcutGroupAvailable(groupId) {
    return GetKeyState("CapsLock", "P")
        && !AppState.QuickPhraseTransactionActive
        && ApplicationProfiles.IsShortcutGroupEnabledForActiveWindow(groupId)
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

; Space toggles one checkbox; Ctrl+A toggles all currently visible checkboxes.
; This context is limited to the ListView so the search box keeps normal editing.
#HotIf FullHistoryListFocused()
Space:: ToggleFullHistoryFocusedCheck()
^a:: ToggleFullHistorySelectAll()
Home:: MoveFullHistorySelectionToBoundary(false)
End:: MoveFullHistorySelectionToBoundary(true)
^f:: FocusFullHistorySearch()
#HotIf

#HotIf GetKeyState("CapsLock", "P") && ApplicationProfiles.IsShortcutGroupEnabledForActiveWindow("text")
j:: JumpToLine()
#HotIf GetKeyState("CapsLock", "P") && ApplicationProfiles.IsShortcutGroupEnabledForActiveWindow("window")
k:: TerminateProcessByPid()
#HotIf

; Shift arms the existing sequential modifier layer; the action hotkeys below
; apply their own per-application group policy.
#HotIf CapsLockHotkeysAvailable()
~Shift:: ActivateShiftLayer()
#HotIf

#HotIf CapsLockShortcutGroupAvailable("text")
+Left:: Send("^+{Left}")
+Right:: Send("^+{Right}")
+Up:: Send("+{Home}")
+Down:: Send("+{End}")
Space:: Send("^{Left}^+{Right}")
a:: Send("{Backspace}")
d:: Send("{Delete}")
+a:: Send("^{Backspace}")
+d:: Send("^{Delete}")
Backspace:: Send("{Home}+{End}{Delete}")
Delete:: Send("{Home}+{End}{Delete}")
#HotIf

#HotIf CapsLockShortcutGroupAvailable("tabs")
q:: Send("^{PgUp}")
e:: Send("^{PgDn}")
#HotIf

#HotIf CapsLockShortcutGroupAvailable("window") && !WindowHole.IsActive()
LButton:: {
    AdjustOpacity(20)
    if KeyWait("LButton", "T0.3")
        return
    while GetKeyState("LButton", "P") {
        AdjustOpacity(5)
        Sleep(50)
    }
}
RButton:: {
    AdjustOpacity(-20)
    if KeyWait("RButton", "T0.3")
        return
    while GetKeyState("RButton", "P") {
        AdjustOpacity(-5)
        Sleep(50)
    }
}
MButton:: {
    hwnd := WinExist("A")
    current := WinGetTransparent(hwnd)
    if current == "" || current == 255
        WinSetTransparent(10, hwnd)
    else
        WinSetTransparent(255, hwnd)
}
#HotIf

#HotIf CapsLockShortcutGroupAvailable("window")
; --- CapsLock + W / 8 / Num8 and CapsLock + S / 2 / Num2 ------------------
; Ctrl / Alt / Win combinations are forwarded untouched.
*w:: WindowWildcardMaximize()
*8:: WindowWildcardMaximize()
*Numpad8:: WindowWildcardMaximize()
*s:: WindowWildcardMinimize()
*2:: WindowWildcardMinimize()
*Numpad2:: WindowWildcardMinimize()
t:: ToggleAlwaysOnTopWithOSD()
l:: WindowSwitcherGui.Show()
#HotIf

#HotIf CapsLockShortcutGroupAvailable("clipboard")
c:: CopyAsPlainTextAndAddToHistory()
v:: PasteWithCurrentMode()
+v:: ShowHistoryMenu()
f:: ChangeCaseOfLastCopy()
#HotIf

#HotIf CapsLockShortcutGroupAvailable("tools")
p:: ConvertWithPandoc()
!q:: OpenTempFolder()
r:: CommandPaletteGui.Show()
h:: HotkeyReferenceGui.Toggle()
F1:: HotkeyReferenceGui.Toggle()
,:: SettingsGui.Toggle()
i:: SettingsGui.Toggle()
#HotIf

#HotIf CapsLockShortcutGroupAvailable("visual")
o:: Spotlight.HandleDown()
z:: Zoom.HandleDown()
x:: WindowHole.HandleXDown()
#HotIf

; X-up, O-up and Z-up are intentionally global so releasing the key still stops hold
; mode even when CapsLock is released first. The tilde keeps the key-up event
; visible to the active application.
~x up:: WindowHole.HandleXUp()
~o up:: Spotlight.HandleUp()
~z up:: Zoom.HandleUp()

#HotIf QuickPhraseHotkeyAvailable() && AppState.QuickPhraseEnabled
+p:: QuickPhraseHandleHotkey()
#HotIf

; Window Hole second-level penetration is registered as a global hotkey and
; enabled only for the lifetime of an active Window Hole session. This avoids
; #HotIf timing on the CapsLock + X + 1 sequence.
WindowHole.InitializeSecondLevelHotkey()
