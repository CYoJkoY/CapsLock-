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
            && InStr(source, "this._EnsureChromiumRenderSurfaces(this.PrimaryHwnd, primaryState)") > 0,
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
            && InStr(source, "this.HoleLayerOrder.Push(hwnd)") > 0,
        "Region-stack secondary penetration state is missing."
    )
    secondaryStart := InStr(source, "static HandleSecondLevelPenetration(*)")
    secondaryEnd := InStr(source, "static IsEligible(hwnd) {", secondaryStart)
    secondarySource := SubStr(source, secondaryStart, secondaryEnd - secondaryStart)

    Assert(
        secondaryStart > 0
            && secondaryEnd > secondaryStart
            && InStr(secondarySource, 'foregroundHwnd := WinExist("A")') > 0
            && InStr(secondarySource, "this._ApplyHole(") > 0
            && InStr(secondarySource, "false") > 0,
        "Secondary penetration does not create a fixed region layer without fallback."
    )
    Assert(
        InStr(source, 'static _ApplyHole(hwnd, mouseX := "", mouseY := "", allowFallback := true)') > 0
            && InStr(source, "if allowFallback && AppState.WindowHoleFallbackToMinimize") > 0,
        "Minimize fallback is not isolated from normal secondary region penetration."
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

    Assert(
        InStr(rootSource, "WindowHole.Stop()") > 0
            && InStr(rootSource, "WindowHole.Stop(true)") == 0,
        "Window Hole shutdown should not depend on an asynchronous restoration queue."
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
