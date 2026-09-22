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
    trackerSource := ReadSource("Core\QuickPhraseFocusTracker.ahk")
    entrySource := ReadSource("CapsLock-.ahk")

    Assert(
        InStr(source, "QuickPhraseTransactionActive") > 0
            && InStr(source, "QuickPhraseDestroySelector(selectorGui)") > 0
            && InStr(source, "QuickPhraseExecutePhrase") > 0
            && InStr(source, "SetTimer(") > 0,
        "Quick Phrase transaction lifecycle is incomplete."
    )

    Assert(
        InStr(source, "ControlGetFocus(") > 0
            && InStr(source, "control: controlHwnd") > 0,
        "Quick Phrase does not capture the initial focused control."
    )

    Assert(
        InStr(trackerSource, "class QuickPhraseFocusTracker") > 0
            && InStr(trackerSource, "QuickPhraseFocusTrackerUpdate()") > 0
            && InStr(trackerSource, "target := AppState.QuickPhrasePasteTarget") > 0
            && InStr(trackerSource, "target.window := currentWindow") > 0
            && InStr(trackerSource, "target.control := currentControl") > 0
            && InStr(trackerSource, "QuickPhraseIsInternalWindow") > 0,
        "Quick Phrase does not continuously refresh the latest external focus target."
    )

    Assert(
        InStr(entrySource, '#Include "Core\QuickPhraseFocusTracker.ahk"') > 0
            && InStr(entrySource, "QuickPhraseFocusTracker.Initialize()") > 0,
        "Quick Phrase focus tracker is not registered at application startup."
    )

    Assert(
        InStr(source, "QuickPhraseRestorePasteFocus(") > 0
            && InStr(source, "ControlFocus(") > 0
            && InStr(source, 'WinActivate("ahk_id " targetHwnd)') > 0
            && InStr(source, 'Send("^v")') > 0,
        "Quick Phrase final insertion does not restore focus and send the completed phrase."
    )

    Assert(
        InStr(source, "result.text := QuickPhraseApplyVariables(") > 0
            && InStr(source, "QuickPhrasePasteText(") > 0,
        "Variable substitution is not connected to final phrase insertion."
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
