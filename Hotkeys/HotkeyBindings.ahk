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
    return GetKeyState("CapsLock", "P") && !AppState.QuickPhraseTransactionActive
}

QuickPhraseUiActive() {
    if AppState.QuickPhraseTransactionActive
        return true
    return IsObject(AppState.QuickPhraseGui)
    || IsObject(AppState.QuickPhraseVariableGui)
    || IsObject(AppState.QuickPhraseManagerGui)
}

QuickPhraseHotkeyAvailable() {
    return CapsLockHotkeysAvailable()
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

; --- Window switcher (CapsLock + L) keyboard navigation ---
; Scoped to the switcher's search box so arrow keys move the selection while
; typing, without interfering with any other window or GUI.
#HotIf WindowSwitcherSearchFocused()
Up:: WindowSwitcherGui.MoveSelection(-1)
Down:: WindowSwitcherGui.MoveSelection(1)
PgUp:: WindowSwitcherGui.MoveSelection(-5)
PgDn:: WindowSwitcherGui.MoveSelection(5)
#HotIf

#HotIf GetKeyState("CapsLock", "P")
j:: JumpToLine()
k:: TerminateProcessByPid()
#HotIf

#HotIf CapsLockHotkeysAvailable()
~Shift:: ActivateShiftLayer()
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
q:: Send("^{PgUp}")
e:: Send("^{PgDn}")

#HotIf CapsLockHotkeysAvailable() && !WindowHole.IsActive()
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

#HotIf CapsLockHotkeysAvailable()
; --- CapsLock + W / 8 / Num8 and CapsLock + S / 2 / Num2 ------------------
;
; Every key of the two groups reaches these handlers through a wildcard hotkey,
; because a separate "+w" / "+8" / "+s" / "+2" binding next to the stacked
; "w / 8 / Numpad8" and "s / 2 / Numpad2" definitions is never registered: the
; stacked head owns the key and the Shift variant is dropped. Resolving the
; modifier state here keeps one reliable entry point per key.
;
;   CapsLock + W / 8 / Num8             maximize / restore
;   CapsLock + Shift + W / 8 / Num8     borderless fullscreen
;   CapsLock + S / 2 / Num2             minimize
;   CapsLock + Shift + S / 2 / Num2     hide to tray
;
; Ctrl / Alt / Win combinations belong to the active window (Ctrl + S saves,
; Ctrl + W closes a tab), so they are forwarded untouched.
*w:: WindowWildcardMaximize()
*8:: WindowWildcardMaximize()
*Numpad8:: WindowWildcardMaximize()
*s:: WindowWildcardMinimize()
*2:: WindowWildcardMinimize()
*Numpad2:: WindowWildcardMinimize()

c:: CopyAsPlainTextAndAddToHistory()
v:: PasteWithCurrentMode()
+v:: ShowHistoryMenu()
f:: ChangeCaseOfLastCopy()
t:: ToggleAlwaysOnTopWithOSD()
p:: ConvertWithPandoc()
l:: WindowSwitcherGui.Show()
o:: Spotlight.HandleDown()
z:: Zoom.HandleDown()
x:: WindowHole.HandleXDown()
; --- Files: open the temp folder used by file-oriented paste ---
!q:: OpenTempFolder()
; --- Help: built-in hotkey reference & Settings Center ---
h::
F1:: HotkeyReferenceGui.Toggle()
,::
i:: SettingsGui.Toggle()
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
