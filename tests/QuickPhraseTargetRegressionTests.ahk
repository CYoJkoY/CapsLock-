#Requires AutoHotkey v2.0

#Include "..ConfigGlobals.ahk"
#Include "..CoreQuickPhraseTarget.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

ReadSource(path) {
    return FileRead(A_WorkingDir "" path, "UTF-8")
}

RunCaptureTest() {
    gui := Gui("+AlwaysOnTop", "Quick Phrase Target Capture Test")
    edit := gui.Add("Edit", "w360 h90", "")
    gui.Show("w420 h160")

    edit.Focus()
    WinActivate("ahk_id " gui.Hwnd)

    if !WinWaitActive("ahk_id " gui.Hwnd, , 1)
        throw Error("Target-capture test window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        IsObject(target)
            && target.window == gui.Hwnd,
        "Quick Phrase target capture did not preserve the active window."
    )

    Assert(
        QuickPhraseTarget.IsWindowValid(target),
        "Captured Quick Phrase target failed window validation."
    )

    gui.Destroy()
}

RunInvalidTargetTest() {
    gui := Gui("+AlwaysOnTop", "Quick Phrase Invalid Target Test")
    gui.Add("Edit", "w240 h60", "")
    gui.Show("w300 h130")

    if !WinWaitActive("ahk_id " gui.Hwnd, , 1)
        throw Error("Invalid-target test window did not become active.")

    target := QuickPhraseTarget.Capture()
    gui.Destroy()

    Assert(
        !QuickPhraseTarget.IsWindowValid(target),
        "Destroyed Quick Phrase target window was still considered valid."
    )
}

RunTests() {
    source := ReadSource("UIQuickPhraseGui.ahk")
    rootSource := ReadSource("CapsLock-.ahk")
    targetSource := ReadSource("CoreQuickPhraseTarget.ahk")

    Assert(
        InStr(rootSource, '#Include "CoreQuickPhraseTarget.ahk"') > 0,
        "Quick Phrase target module is not included by the application entry point."
    )

    Assert(
        InStr(source, "QuickPhraseTarget.Capture()") > 0
            && InStr(source, "QuickPhrasePasteText(") > 0
            && InStr(source, "ActivateAndPaste()") > 0
            && InStr(source, "QuickPhraseTarget.DeliverPaste(") == 0,
        "Quick Phrase must capture the target but use the shared application paste path for final delivery."
    )

    Assert(
        InStr(source, "AppState.TargetWindow := targetHwnd") > 0
            && InStr(source, "AppState.TargetWindow := previousTarget") > 0
            && InStr(source, "ControlSend(") == 0,
        "Quick Phrase must temporarily reuse the shared TargetWindow paste mechanism and restore it afterwards."
    )

    Assert(
        InStr(targetSource, "static Capture()") > 0
            && InStr(targetSource, "static IsWindowValid(") > 0
            && InStr(targetSource, "static DeliverPaste(") == 0
            && InStr(targetSource, "ControlFocus(") == 0
            && InStr(targetSource, "ControlSend(") == 0,
        "Quick Phrase target module must remain a window-only capture/validation component."
    )

    Assert(
        InStr(source, "if variables.Length == 0") > 0
            && InStr(source, "result.text := QuickPhraseApplyVariables(") > 0
            && InStr(source, "QuickPhrasePasteText(") > 0,
        "Fixed and variable Quick Phrases must both reach the shared final paste path."
    )

    Assert(
        InStr(source, 'normalEditOptions := "Multi WantReturn VScroll " ThemeHelper.GetEditOptions()') > 0
            && InStr(source, '" r3 " normalEditOptions') > 0
            && InStr(source, 'values[item.name] := item.edit.Text') > 0
            && InStr(source, "QuickPhraseNormalizeClipboardText(text)") > 0,
        "Quick Phrase variables must support multiline structured input and preserve/normalize line endings for clipboard paste."
    )

    RunCaptureTest()
    RunInvalidTargetTest()

    return true
}

WriteTestResult(status, message := "") {
    path := A_Args.Length > 0 ? A_Args[1] : A_WorkingDir "	estsTestResult.txt"

    try FileDelete(path)

    payload := status
    if message != ""
        payload .= Chr(10) message

    FileAppend(payload, path, "UTF-8")
}

try {
    RunTests()
    WriteTestResult("PASS")
    ExitApp(0)
} catch as err {
    WriteTestResult("FAIL", err.Message)
    FileAppend(
        "Quick Phrase target regression test failure: " err.Message Chr(10),
        A_WorkingDir "	estsQuickPhraseTargetRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
