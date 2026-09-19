#Requires AutoHotkey v2.0

Assert(condition, message) {
    if !condition
        throw Error(message)
}

RunTests() {
    root := A_WorkingDir

    customMenu := FileRead(root "\History\CustomMenu.ahk", "UTF-8")
    hotkeys := FileRead(root "\Hotkeys\HotkeyBindings.ahk", "UTF-8")

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

    Assert(
        InStr(hotkeys, '#HotIf GetKeyState( "CapsLock", "P" ) && WindowHole.Active') > 0,
        "Second-level hotkey still uses a dynamic IsActive() call in #HotIf."
    )
    Assert(
        InStr(hotkeys, '1:: WindowHole.ToggleSecondLevel()') > 0,
        "Second-level Window Hole hotkey binding is missing."
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
