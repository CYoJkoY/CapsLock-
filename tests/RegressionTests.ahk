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
        InStr(source, "static _UpdateChromiumRenderSurfaces") > 0,
        "Chromium rendering-surface update path is missing."
    )
    Assert(
        InStr(source, "static _EnsureChromiumRenderSurfaces(primaryState := "")") > 0,
        "Chromium surface discovery does not reuse cached primary state."
    )
    Assert(
        InStr(source, "className := WinGetClass("ahk_id " hwnd)") > 0,
        "Chromium surface class-first filtering is missing."
    )
    Assert(
        InStr(source, "baseRegion,\n            state\n        )") > 0,
        "Chromium surface updates do not reuse the per-surface hole-region state."
    )
    Assert(
        InStr(source, "holeRegion: 0") > 0
            && InStr(source, '"OffsetRgn"') > 0,
        "Reusable hole-region cache is missing."
    )
    Assert(
        InStr(source, "static _HideTaskManagerWindows()") > 0
            && InStr(source, "static _RestoreTaskManagerWindow()") > 0,
        "Task Manager minimize/restore strategy is missing."
    )

    Assert(
        InStr(source, "static SecondaryHiddenWindows := Map()") > 0
            && InStr(source, "static HandleSecondLevelPenetration(*)") > 0,
        "Focus-driven secondary penetration state is missing."
    )
    Assert(
        InStr(source, 'foregroundHwnd := WinExist("A")') > 0
            && InStr(source, 'WinMinimize("ahk_id " foregroundHwnd)') > 0,
        "Secondary penetration does not target and minimize the current foreground window."
    )
    Assert(
        InStr(source, "static _GetTopLevelWindowAtPoint(x, y)") > 0
            && InStr(source, '"WindowFromPoint"') > 0
            && InStr(source, '"GetAncestor"') > 0,
        "Fallback penetration does not resolve the actual top-level window under the cursor."
    )
    Assert(
        InStr(source, "static _FocusNextWindowAtPoint(x, y)") > 0
            && InStr(source, "static _FocusNextWindowUnderCursor()") > 0
            && InStr(source, "this._FocusNextWindowAtPoint(mx, my)") > 0,
        "Revealed layers are not explicitly focused after minimize."
    )
    Assert(
        InStr(source, "static ChromiumMousePassthroughWindows := Map()") > 0
            && InStr(source, "static _UpdateChromiumMousePassthrough(primaryState, x, y)") > 0
            && InStr(source, '0x00000020 ; WS_EX_TRANSPARENT') > 0
            && InStr(source, '0x00080000 ; WS_EX_LAYERED') > 0,
        "Chromium primary-window mouse passthrough is missing."
    )
    Assert(
        InStr(source, "if this.ChromiumMousePassthroughWindows.Count > 0") > 0
            && InStr(source, "return") > 0
            && InStr(source, "static _RestoreChromiumMousePassthrough()") > 0,
        "Chromium passthrough state is not kept stable after WindowFromPoint resolves the underlying window."
    )
    Assert(
        InStr(source, 'static _RestoreSecondaryHiddenWindows()') > 0
            && InStr(source, 'WinRestore("ahk_id " hwnd)') > 0
            && InStr(source, 'state.previousState') > 0,
        "Temporarily minimized secondary windows are not restored with their original state."
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
        InStr(source, 'WinMinimize("ahk_id " hwnd)') > 0
            && InStr(source, 'WinRestore("ahk_id " hwnd)') > 0,
        "Task Manager minimize/restore API calls are missing."
    )
    Assert(
        InStr(source, "; After minimizing it, continue the same layer traversal mode") > 0
            && InStr(source, "if !this._SetSecondLevelHotkeyEnabled(true)") > 0
            && InStr(source, "this._FocusNextWindowUnderCursor()") > 0,
        "Task Manager fallback does not continue into and focus the revealed layer."
    )
    Assert(
        InStr(source, "_UpdateTaskManagerSurfaces") == 0
            && InStr(source, "_EnsureTaskManagerCompanions") == 0
            && InStr(source, "_IsTaskManagerChildSurface") == 0,
        "Obsolete Task Manager surface compatibility path remains."
    )
    Assert(
        InStr(source, "TaskManagerCompanion") == 0
            && InStr(source, "taskManagerSurfaceTargets") == 0
            && InStr(source, "TASK_MANAGER_CHILD_SURFACE") == 0,
        "Obsolete Task Manager compatibility state remains."
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
