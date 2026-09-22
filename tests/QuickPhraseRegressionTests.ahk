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

    Assert(
        InStr(source, "QuickPhraseTransactionActive") > 0
            && InStr(source, "QuickPhraseDestroySelector(selectorGui)") > 0
            && InStr(source, "QuickPhraseExecutePhrase") > 0
            && InStr(source, "SetTimer(") > 0,
        "Quick Phrase transaction lifecycle is incomplete."
    )

    Assert(
        InStr(source, "QuickPhraseCaptureFocusTarget()") > 0
            && InStr(source, "return {") > 0
            && InStr(source, "window: windowHwnd") > 0
            && InStr(source, "control: controlHwnd") == 0,
        "Quick Phrase must capture the original foreground window without retaining an unused control target."
    )

    Assert(
        InStr(source, "previousTarget := AppState.TargetWindow") > 0
            && InStr(source, "AppState.TargetWindow := targetHwnd") > 0
            && InStr(source, "ActivateAndPaste()") > 0
            && InStr(source, "ControlSend(") == 0,
        "Quick Phrase final insertion must reuse the established activate-and-paste path without ControlSend."
    )

    Assert(
        InStr(source, "if variables.Length == 0") > 0
            && InStr(source, "ok := QuickPhrasePasteText(") > 0
            && InStr(source, "result.text := QuickPhraseApplyVariables(") > 0,
        "Fixed and variable Quick Phrases must both reach the shared final paste path."
    )

    Assert(
        InStr(source, "WinWaitClose(") > 0
            && InStr(source, "QuickPhraseDestroyVariableDialog(myGui)") > 0,
        "Variable dialog completion lifecycle is incomplete."
    )

    return true
}

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend(
        "Quick Phrase regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
