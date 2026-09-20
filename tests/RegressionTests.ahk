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
        InStr(source, 'DllCall("SetWindowRgn",') > 0,
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
