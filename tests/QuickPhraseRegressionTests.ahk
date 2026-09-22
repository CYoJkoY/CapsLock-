#Requires AutoHotkey v2.0

Assert(condition, message) {
    if !condition
        throw Error(message)
}

ReadSource(path) {
    return FileRead(A_WorkingDir "\" path, "UTF-8")
}

RunTests() {
    source := ReadSource("UI\QuickPhraseGui.ahk")
    rootSource := ReadSource("CapsLock-.ahk")
    targetSource := ReadSource("Core\QuickPhraseTarget.ahk")

    Assert(
        InStr(source, "QuickPhraseTransactionActive") > 0
            && InStr(source, "QuickPhraseDestroySelector(selectorGui)") > 0
            && InStr(source, "QuickPhraseExecutePhrase") > 0
            && InStr(source, "SetTimer(") > 0,
        "Quick Phrase transaction lifecycle is incomplete."
    )

    Assert(
        InStr(source, "QuickPhraseCaptureFocusTarget()") > 0
            && InStr(source, "QuickPhraseTarget.Capture()") > 0
            && InStr(source, "window: windowHwnd") == 0
            && InStr(source, "control: controlHwnd") == 0,
        "Quick Phrase must capture its destination through the isolated target component."
    )

    Assert(
        InStr(source, "QuickPhrasePasteText(") > 0
            && InStr(source, "ActivateAndPaste()") > 0
            && InStr(source, "AppState.TargetWindow := targetHwnd") > 0
            && InStr(source, "AppState.TargetWindow := previousTarget") > 0
            && InStr(source, "ControlSend(") == 0,
        "Quick Phrase must use the application's shared foreground paste path and restore the previous TargetWindow."
    )

    Assert(
        InStr(rootSource, '#Include "Core\QuickPhraseTarget.ahk"') > 0,
        "Quick Phrase target module is not included by the application entry point."
    )

    Assert(
        InStr(targetSource, "static Capture()") > 0
            && InStr(targetSource, "static IsWindowValid(") > 0
            && InStr(targetSource, "ControlFocus(") == 0
            && InStr(targetSource, "ControlSend(") == 0,
        "Quick Phrase target module must remain a window-only capture/validation component."
    )

    Assert(
        InStr(source, "if variables.Length == 0") > 0
            && InStr(source, "QuickPhrasePasteText(") > 0
            && InStr(source, "ActivateAndPaste()") > 0
            && InStr(source, "result.text := QuickPhraseApplyVariables(") > 0
            && InStr(source, "SetTimer(") > 0,
        "Fixed and variable Quick Phrases must both reach the shared final paste path."
    )

    Assert(
        InStr(source, "WinWaitClose(") > 0
            && InStr(source, "QuickPhraseDestroyVariableDialog(myGui)") > 0,
        "Variable dialog completion lifecycle is incomplete."
    )

    Assert(
        InStr(source, "QuickPhraseNormalizeClipboardText(text)") > 0
            && InStr(source, "Sleep(120)") > 0
            && InStr(source, "ClipboardAll()") > 0,
        "Quick Phrase must normalize multiline clipboard text and keep the clipboard stable during the established paste delay."
    )

    Assert(
        InStr(source, 'normalEditOptions := "Multi WantReturn VScroll " ThemeHelper.GetEditOptions()') > 0
            && InStr(source, '" r3 " normalEditOptions') > 0
            && InStr(source, 'values[item.name] := item.edit.Text') > 0
            && InStr(source, "QuickPhraseNormalizeClipboardText(text)") > 0,
        "Quick Phrase variables must support multiline structured input and preserve/normalize line endings for clipboard paste."
    )

    return true
}

WriteTestResult(status, message := "") {
    path := A_Args.Length > 0 ? A_Args[1] : A_WorkingDir "\tests\TestResult.txt"

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
        "Quick Phrase regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
