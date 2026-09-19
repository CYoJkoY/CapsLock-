#Requires AutoHotkey v2.0

Assert(condition, message) {
    if !condition
        throw Error(message)
}

RunTests() {
    root := A_WorkingDir

    customMenu := FileRead(root "\History\CustomMenu.ahk", "UTF-8")
    hotkeys := FileRead(root "\Hotkeys\HotkeyBindings.ahk", "UTF-8")
    windowHole := FileRead(root "\Core\WindowHole.ahk", "UTF-8")

    anchorCheck := InStr(
        customMenu,
        'if this.menuAnchorX != "" && this.menuAnchorY != ""'
    )
    graceCheck := InStr(
        customMenu,
        "if now < graceUntil"
    )
    rightButtonCheck := InStr(
        customMenu,
        'GetKeyState("RButton", "P")'
    )

    Assert(anchorCheck > 0, "Tray menu no longer treats the tray anchor as an interaction surface.")
    Assert(graceCheck > 0, "Tray menu opening grace period is missing.")
    Assert(rightButtonCheck > 0, "Tray menu outside-button dismissal guard is missing.")
    Assert(graceCheck < rightButtonCheck, "Tray opening grace must be checked before button-state dismissal.")
    Assert(InStr(customMenu, "A_TickCount + 1200") > 0, "Tray opening grace period was not extended.")
    Assert(InStr(customMenu, "outsideSurfaceSince := 0") > 0, "Tray outside-surface debounce state is missing.")
    Assert(InStr(customMenu, "outsideDismissDelay := 240") > 0, "Tray outside-surface debounce interval is missing.")
    Assert(InStr(customMenu, "interactionPadding := 10") > 0, "Tray interaction padding is missing.")
    Assert(InStr(customMenu, "IsPointInInteractionSurface") > 0, "Tray interaction-surface hit test is missing.")
    Assert(InStr(customMenu, "IsPointInWindowBridge") > 0, "Tray submenu transition bridge is missing.")
    Assert(InStr(customMenu, "now - this.outsideSurfaceSince < this.outsideDismissDelay") > 0, "Tray outside-surface debounce is not enforced.")
    Assert(InStr(customMenu, 'CoordMode("Mouse", "Screen")') > 0, "Tray outside watchdog must use screen mouse coordinates.")
    Assert(
        InStr(customMenu, 'CoordMode("Mouse", "Screen")') < InStr(customMenu, 'MouseGetPos(&mx, &my)'),
        "Tray outside watchdog must set screen coordinate mode before reading the mouse position."
    )

    Assert(
        InStr(hotkeys, "WindowHole.InitializeSecondLevelHotkey()") > 0,
        "Second-level Window Hole global hotkey initialization is missing."
    )
    Assert(
        InStr(hotkeys, 'WindowHole.Active') == 0
            || InStr(hotkeys, '#HotIf GetKeyState( "CapsLock", "P" ) && WindowHole.Active') == 0,
        "Second-level hotkey must not depend on a WindowHole.Active #HotIf expression."
    )
    Assert(
        InStr(windowHole, 'Hotkey("1", this.SecondLevelHotkeyCallback, "Off")') > 0,
        "Second-level global hotkey registration is missing."
    )
    Assert(
        InStr(windowHole, 'Hotkey("1", enabled ? "On" : "Off")') > 0,
        "Second-level global hotkey state toggle is missing."
    )
    Assert(false, "TEST RUNNER SENTINEL: this commit must fail CI.")
    Assert(
        InStr(windowHole, "static SecondLevelHotkeyKeyDown := false") > 0,
        "Second-level hotkey is missing a per-keypress state latch."
    )
    Assert(
        InStr(windowHole, "this.SecondLevelHotkeyKeyDown := true") > 0
            && InStr(windowHole, "this.SecondLevelHotkeyKeyDown := false") > 0,
        "Second-level hotkey does not acquire and release its per-keypress state latch."
    )
    Assert(
        InStr(windowHole, "KeyWait("1")") > 0,
        "Second-level hotkey must wait for the key release so keyboard auto-repeat cannot toggle it twice."
    )
    Assert(
        InStr(windowHole, "this._SetSecondLevelHotkeyEnabled(true)") > 0,
        "Window Hole activation does not enable the second-level hotkey."
    )
    Assert(
        InStr(windowHole, "if !this._ApplyHole(hwnd, true)") < InStr(windowHole, "if !this._SetSecondLevelHotkeyEnabled(true)"),
        "Second-level hotkey must not be enabled before the primary hole is established."
    )
    Assert(
        InStr(windowHole, "this._SetSecondLevelHotkeyEnabled(false)") > 0,
        "Window Hole stop path does not disable the second-level hotkey."
    )
    Assert(
        InStr(windowHole, "if !result {") > 0
            && InStr(windowHole, "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE") > 0,
        "Second-level activation failure does not provide feedback."
    )

    Assert(
        InStr(windowHole, "CHROMIUM_MIN_UPDATE_INTERVAL := 60") > 0,
        "Chromium update interval safeguard is missing."
    )
    Assert(
        InStr(windowHole, "CHROMIUM_MIN_MOVE_DISTANCE := 8") > 0,
        "Chromium movement threshold is missing."
    )
    Assert(
        InStr(windowHole, "static _ShouldApplyPosition(state, x, y)") > 0,
        "Chromium movement filter helper is missing."
    )
    Assert(
        InStr(windowHole, 'state.isChromium ? 0 : 1') > 0,
        "Chromium SetWindowRgn path does not suppress automatic redraw."
    )
    Assert(
        InStr(windowHole, "redrawFlags := chromium") > 0,
        "Chromium-specific redraw flags are missing."
    )
    Assert(
        InStr(windowHole, "nextRegionRepairTick") > 0,
        "Chromium region repair cooldown is missing."
    )
    Assert(
        InStr(windowHole, "primaryRegionApplied := false") > 0,
        "Primary update path does not prevent same-cycle region reapplication."
    )
    Assert(
        InStr(windowHole, "secondaryRegionApplied := false") > 0,
        "Secondary update path does not prevent same-cycle region reapplication."
    )
    Assert(
        InStr(windowHole, "CHROMIUM_REGION_REPAIR_INTERVAL := 250") > 0,
        "Chromium region repair cooldown is too aggressive or missing."
    )
    Assert(
        InStr(windowHole, "firstRegionApply := !state.hasAppliedPosition") > 0,
        "Chromium initial region refresh guard is missing."
    )
    Assert(
        InStr(windowHole, "if !state.isChromium || firstRegionApply") > 0,
        "Chromium per-move redraw suppression is missing."
    )
    Assert(
        InStr(windowHole, "if !chromium") > 0,
        "Chromium synchronous UpdateWindow suppression is missing."
    )

    return true
}

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend(
        "Regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\RegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
