#Requires AutoHotkey v2.0

Assert(condition, message) {
    if !condition
        throw Error(message)
}

ReadSource(path) {
    return FileRead(A_WorkingDir "\" path, "UTF-8")
}

RunTests() {
    source := ReadSource("Core\WindowHole.ahk")

    Assert(
        InStr(source, "static CHROMIUM_MIN_UPDATE_INTERVAL := 16")
            && InStr(source, "static CHROMIUM_MIN_MOVE_DISTANCE := 3"),
        "Chromium movement smoothing targets are missing."
    )
    Assert(
        InStr(source, "static RENDER_SURFACE_MIN_REGION_COMMIT_INTERVAL := 16")
            && InStr(source, "static RENDER_SURFACE_MIN_MOVE_DISTANCE := 3"),
        "Chromium render-surface pacing targets are missing."
    )
    Assert(
        InStr(source, "GetPhysicalCursorPos") > 0,
        "Physical cursor API optimization is missing."
    )
    Assert(
        InStr(source, 'className == "Intermediate D3D Window"') > 0
            && InStr(source, 'className == "Chrome_RenderWidgetHostHWND"') > 0,
        "Chromium rendering surfaces are not recognized."
    )
    Assert(
        InStr(source, '"EnumChildWindows",') > 0
            && InStr(source, "CallbackCreate(") > 0
            && InStr(source, "CallbackFree(callback)") > 0,
        "Chromium child-window enumeration lifecycle is incomplete."
    )
    Assert(
        InStr(source, "static _UpdateChromiumRenderSurfaces") > 0
            && InStr(source, "static _EnsureChromiumRenderSurfaces(targetHwnd, targetState)") > 0,
        "Chromium render-surface target lifecycle is incomplete."
    )
    Assert(
        InStr(source, "lastRenderSurfaceScanTick: 0") > 0
            && InStr(source, "this._EnsureChromiumRenderSurfaces(this.PrimaryHwnd, primaryState)") > 0
            && InStr(source, "for layerHwnd in this.HoleLayerOrder") > 0,
        "Chromium surface scanning is not tracked per holed target."
    )
    Assert(
        InStr(source, 'className := WinGetClass("ahk_id " hwnd)') > 0,
        "Chromium surface class-first filtering is missing."
    )
    Assert(
        InStr(source, "holeRegion: 0") > 0
            && InStr(source, '"OffsetRgn"') > 0,
        "Reusable hole-region cache is missing."
    )

    Assert(
        InStr(source, "static HoleLayerOrder := []") > 0
            && InStr(source, "static HandleSecondLevelPenetration(*)") > 0
            && InStr(source, "this.Targets[hwnd] := state") > 0
            && InStr(source, "this.HoleLayerOrder.Push(hwnd)") > 0
            && InStr(source, "layerHwnds := this.HoleLayerOrder.Clone()") > 0,
        "Region-stack secondary penetration state or safe layer iteration is missing."
    )
    secondaryStart := InStr(source, "static HandleSecondLevelPenetration(*)")
    secondaryEnd := InStr(source, "static IsEligible(hwnd) {", secondaryStart)
    secondarySource := SubStr(source, secondaryStart, secondaryEnd - secondaryStart)

    Assert(
        secondaryStart > 0
            && secondaryEnd > secondaryStart
            && InStr(secondarySource, 'foregroundHwnd := WinExist("A")') > 0
            && InStr(secondarySource, "this._GetPhysicalCursorPosition(&mx, &my)") > 0
            && InStr(secondarySource, "this._ApplyHole(") > 0
            && InStr(secondarySource, "mx") > 0
            && InStr(secondarySource, "my") > 0
            && InStr(secondarySource, "false") > 0,
        "Secondary penetration does not create a cursor-positioned region layer without fallback."
    )
    Assert(
        InStr(source, 'static _ApplyHole(hwnd, mouseX := "", mouseY := "", allowFallback := true)') > 0
            && InStr(source, "if allowFallback && AppState.WindowHoleFallbackToMinimize") > 0,
        "Minimize fallback is not isolated from normal secondary region penetration."
    )

    Assert(
        InStr(source, "static _UpdateChromiumMousePassthrough(targetHwnd, targetState, x, y)") > 0
            && InStr(source, "this._UpdateChromiumMousePassthrough(") > 0
            && InStr(source, "this._EnsureChromiumRenderSurfaces(layerHwnd, layerState)") > 0,
        "Chromium mouse passthrough is not applied independently to each hole layer."
    )
    Assert(
        InStr(source, "state.lastAppliedX") > 0
            && InStr(source, "state.lastAppliedY") > 0
            && InStr(source, "this._ApplyHole(") > 0
            && InStr(source, "isPrimary := layerHwnd == this.PrimaryHwnd") > 0
            && InStr(source, "result := this._ApplyHole(") > 0,
        "Hole layers do not retain or apply the cursor position needed for mouse-following updates."
    )

    Assert(
        InStr(source, "SecondaryHiddenWindows") == 0
            && InStr(source, "SecondaryRestoreQueue") == 0
            && InStr(source, "ShowWindowAsync") == 0
            && InStr(source, "SECONDARY_RESTORE_BATCH_SIZE") == 0
            && InStr(source, "_RestoreSecondaryHiddenWindows") == 0,
        "Obsolete secondary minimize/restore machinery remains."
    )
    Assert(
        InStr(source, "WinMinimize(") > 0
            && InStr(source, "static _MinimizeFallback(hwnd, state)") > 0,
        "Primary compatibility minimize fallback is missing."
    )
    Assert(
        InStr(secondarySource, "WinMinimize(") == 0
            && InStr(secondarySource, "WinRestore(") == 0
            && InStr(secondarySource, "WinMaximize(") == 0
            && InStr(secondarySource, "WinActivate(") == 0
            && InStr(secondarySource, "_FocusNextWindowAtPoint") == 0,
        "Secondary penetration still changes show state or forcibly activates the next layer."
    )
    Assert(
        InStr(source, "static _RestoreAll()") > 0
            && InStr(source, "index := this.HoleLayerOrder.Length") > 0
            && InStr(source, "this.Targets.Has(hwnd)") > 0
            && InStr(source, "this.HoleLayerOrder := []") > 0,
        "Window Hole teardown does not restore the stacked target regions."
    )

    Assert(
        InStr(source, "SecondLevelActive") == 0
            && InStr(source, "SecondaryHwnd") == 0
            && InStr(source, "WindowHoleSecondLevelEnabled") == 0
            && InStr(source, 'WinHide("ahk_id " foregroundHwnd)') == 0
            && InStr(source, 'WinShow("ahk_id " hwnd)') == 0
            && InStr(source, "static ToggleSecondLevel(*)") == 0
            && InStr(source, "_GetRootWindowAtPoint(mouseHwnd)") == 0
            && InStr(source, "MSG_WINDOW_HOLE_SECOND_DISABLED") == 0,
        "Obsolete secondary toggle/gate logic remains."
    )

    Assert(
        InStr(source, "static _MinimizeFallback(hwnd, state)") > 0
            && InStr(source, "static _RestoreFallback(hwnd, previousState)") > 0
            && InStr(source, "if allowFallback && AppState.WindowHoleFallbackToMinimize") > 0,
        "Compatibility fallback for region-incompatible primary windows is missing."
    )
    Assert(
        InStr(source, "static _IsTaskManagerWindow(hwnd)") > 0
            && InStr(source, "static _HideTaskManagerWindows()") > 0
            && InStr(source, "static _RestoreTaskManagerWindow()") > 0
            && InStr(source, "TaskManagerPreviousState") > 0,
        "Task Manager primary-window compatibility path is missing."
    )

    rootSource := ReadSource("CapsLock-.ahk")

    hotkeySource := ReadSource("Hotkeys\\HotkeyBindings.ahk")
    referenceSource := ReadSource("Hotkeys\\HotkeyReference.ahk")
    actionSource := ReadSource("Hotkeys\\HotkeyActions.ahk")
    switcherSource := ReadSource("UI\\WindowSwitcherGui.ahk")
    readmeSource := ReadSource("README.md")
    langSource := ReadSource("lang.csv")

    Assert(
        InStr(hotkeySource, "    Left:: Send") == 0
            && InStr(hotkeySource, "    Right:: Send") == 0
            && InStr(hotkeySource, "    Up:: Send") == 0
            && InStr(hotkeySource, "    Down:: Send") == 0,
        "Legacy CapsLock arrow navigation bindings remain."
    )

    Assert(
        InStr(hotkeySource, "    +Left:: Send") > 0
            && InStr(hotkeySource, "    +Right:: Send") > 0
            && InStr(hotkeySource, "    +Up:: Send") > 0
            && InStr(hotkeySource, "    +Down:: Send") > 0,
        "Shift-based CapsLock arrow selection bindings were removed."
    )

    Assert(
        InStr(hotkeySource, "    j:: JumpToLine()") > 0
            && InStr(hotkeySource, "    k:: TerminateProcessByPid()") > 0
            && InStr(hotkeySource, "    l:: WindowSwitcherGui.Show()") > 0,
        "J/K/L hotkeys are not registered in the canonical hotkey layer."
    )

    Assert(
        InStr(referenceSource, "CapsLock + ← / →") == 0
            && InStr(referenceSource, "CapsLock + ↑ / ↓") == 0
            && InStr(referenceSource, "CapsLock + J") > 0
            && InStr(referenceSource, "CapsLock + K") > 0
            && InStr(referenceSource, "CapsLock + L") > 0,
        "Hotkey reference still contains legacy navigation or misses J/K/L."
    )

    Assert(
        InStr(actionSource, "JumpToLine()") > 0
            && InStr(actionSource, 'Send("^g")') > 0
            && InStr(actionSource, "ParsePositiveInteger") > 0,
        "Line-jump workflow is missing or incomplete."
    )

    Assert(
        InStr(actionSource, "TerminateProcessByPid()") > 0
            && InStr(actionSource, "ProcessExist(pid)") > 0
            && InStr(actionSource, "ProcessClose(pid)") > 0
            && InStr(actionSource, "GetProcessIdentity(pid)") > 0,
        "PID-based process termination workflow is missing or incomplete."
    )

    Assert(
        InStr(switcherSource, "class WindowSwitcherGui") > 0
            && InStr(switcherSource, "WinGetList()") > 0
            && InStr(switcherSource, "WinGetPID") > 0
            && InStr(switcherSource, "WinGetProcessName") > 0
            && InStr(switcherSource, "IsWindowVisible") > 0
            && InStr(switcherSource, "0x00000080") > 0
            && InStr(switcherSource, "0x08000000") > 0
            && InStr(switcherSource, "GetCurrentProcessId") > 0
            && InStr(switcherSource, "WinActivate") > 0,
        "Window switcher filtering or activation path is incomplete."
    )

    Assert(
        InStr(rootSource, '#Include "UI\\WindowSwitcherGui.ahk"') > 0,
        "Window switcher GUI is not included by the application entry point."
    )

    Assert(
        InStr(readmeSource, "| Navigation | `Left / Right`") == 0
            && InStr(readmeSource, "| Navigation | `Up / Down`") == 0
            && InStr(readmeSource, "| Navigation | `J` |") > 0
            && InStr(readmeSource, "| Window | `K` |") > 0
            && InStr(readmeSource, "| Window | `L` |") > 0,
        "README shortcut documentation is stale or missing J/K/L."
    )

    Assert(
        InStr(langSource, "CHEAT_ACT_NAV_WORD,") == 0
            && InStr(langSource, "CHEAT_ACT_NAV_LINE,") == 0
            && InStr(langSource, "CHEAT_ACT_GOTO_LINE,") > 0
            && InStr(langSource, "CHEAT_ACT_KILL_PROCESS,") > 0
            && InStr(langSource, "CHEAT_ACT_WINDOW_SWITCH,") > 0
            && InStr(langSource, "GUI_WINDOW_SWITCHER_TITLE,") > 0,
        "Shortcut localization is stale or incomplete."
    )

    Assert(
        InStr(rootSource, "WindowHole.Stop()") > 0
            && InStr(rootSource, "WindowHole.Stop(true)") == 0,
        "Window Hole shutdown should not depend on an asynchronous restoration queue."
    )
    Assert(
        InStr(source, "the same timer must remain active") > 0
            && InStr(source, "SetTimer(") > 0
            && InStr(source, "this._Update(true)") > 0,
        "Task Manager compatibility mode must keep secondary layer tracking active."
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
