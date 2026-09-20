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
        InStr(source, 'WinMinimize("ahk_id " hwnd)') > 0
            && InStr(source, 'WinRestore("ahk_id " hwnd)') > 0,
        "Task Manager minimize/restore API calls are missing."
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
