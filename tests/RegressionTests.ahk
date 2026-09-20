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
        InStr(source, "static CHROMIUM_RENDER_SURFACE_SCAN_INTERVAL := 400") > 0,
        "Chromium rendering-surface scan interval is missing."
    )
    Assert(
        InStr(source, "static CHROMIUM_MIN_UPDATE_INTERVAL := 40") > 0,
        "Chromium movement update interval is not using the smoother target."
    )
    Assert(
        InStr(source, "static RENDER_SURFACE_MIN_REGION_COMMIT_INTERVAL := 40") > 0,
        "Chromium rendering-surface commit interval is missing."
    )
    Assert(
        InStr(source, "static TASK_MANAGER_SURFACE_MIN_REGION_COMMIT_INTERVAL := 80") > 0,
        "Task Manager surface commit pacing is not separated from Chromium."
    )
    Assert(
        InStr(source, 'taskManagerSurface: taskManagerSurface') > 0,
        "Task Manager surface state flag is missing."
    )
    Assert(
        InStr(source, 'redraw := state.HasProp("taskManagerSurface")') > 0,
        "Task Manager surface redraw selection is missing."
    )
    Assert(
        InStr(source, "if taskManagerSurface" Chr(10) "                this._PrepareWindowForHole(hwnd, state)") > 0,
        "Task Manager surfaces are not prepared through the visual compatibility path."
    )
    Assert(
        InStr(source, 'className == "Intermediate D3D Window"') > 0,
        "Intermediate D3D Window is not recognized as a Chromium rendering surface."
    )
    Assert(
        InStr(source, 'className == "Chrome_RenderWidgetHostHWND"') > 0,
        "Chrome_RenderWidgetHostHWND is not recognized as a Chromium rendering surface."
    )
    Assert(
        InStr(source, '"EnumChildWindows",') > 0,
        "Child-window enumeration is missing."
    )
    Assert(
        InStr(source, "CallbackCreate(") > 0,
        "EnumChildWindows callback is not created through CallbackCreate."
    )
    Assert(
        InStr(source, "CallbackFree(callback)") > 0,
        "EnumChildWindows callback is not released with CallbackFree."
    )
    Assert(
        InStr(source, "chromiumRenderSurfaces: Map()") > 0,
        "Chromium rendering-surface state map is missing."
    )
    Assert(
        InStr(source, "static _UpdateChromiumRenderSurfaces") > 0,
        "Chromium rendering-surface update path is missing."
    )
    Assert(
        InStr(source, "TASK_MANAGER_CHILD_SURFACE_MIN_WIDTH") > 0,
        "Task Manager child surface size guard is missing."
    )
    Assert(
        InStr(source, "static _IsTaskManagerChildSurface(hwnd)") > 0,
        "Task Manager child-surface detection helper is missing."
    )
    Assert(
        InStr(source, '"GetWindow",') > 0 && InStr(source, '"UInt", 4') > 0,
        "Task Manager owner-window filtering is missing."
    )
    Assert(
        InStr(source, "overlapW >= Floor(helperW * 0.8)") > 0,
        "Task Manager generic companion overlap guard is missing."
    )
    Assert(
        InStr(source, "Windows.UI.Composition.DesktopWindowContentBridge") > 0
            && InStr(source, "Microsoft.UI.Content.DesktopChildSiteBridge") > 0,
        "Known WinUI composition bridge classes are not recognized."
    )
    Assert(
        InStr(source, "taskManagerSurfaceTargets: Map()") > 0,
        "Task Manager child-surface state map is missing."
    )
    Assert(
        InStr(source, "static _UpdateTaskManagerSurfaces") > 0,
        "Task Manager surface update path is missing."
    )
    Assert(
        InStr(source, "static _RestoreSurfaceTargets(state)") > 0,
        "Rendering-surface cleanup path is missing."
    )
    Assert(
        InStr(source, 'state.regionActive := false') > 0
            && InStr(source, 'state.hasAppliedPosition := false') > 0,
        "Surface-region restore does not reset movement state."
    )
    Assert(
        InStr(source, '"SetWindowRgn",') > 0,
        "Native region application is missing."
    )
    Assert(
        InStr(source, '"Int", 0,') > 0,
        "Surface region updates are not using the no-redraw path."
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
