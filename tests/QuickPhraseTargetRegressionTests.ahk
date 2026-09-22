#Requires AutoHotkey v2.0

#Include "..\Core\QuickPhraseTarget.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

ReadSource(path) {
    return FileRead(A_WorkingDir "\" path, "UTF-8")
}

RunTargetDeliveryTest() {
    payload := "Quick Phrase target delivery test"

    firstGui := Gui("+AlwaysOnTop", "Quick Phrase Target Test")
    firstEdit := firstGui.Add("Edit", "w360 h90", "")
    firstGui.Show("w420 h160")

    firstEdit.Focus()
    WinActivate("ahk_id " firstGui.Hwnd)

    if !WinWaitActive("ahk_id " firstGui.Hwnd, , 1)
        throw Error("First test window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        IsObject(target)
            && target.window == firstGui.Hwnd,
        "Quick Phrase target capture did not preserve the active window."
    )
    Assert(
        target.control == firstEdit.Hwnd,
        "Quick Phrase target capture did not preserve the focused control."
    )
    Assert(
        QuickPhraseTarget.IsWindowValid(target)
            && QuickPhraseTarget.IsControlValid(target),
        "Captured Quick Phrase target failed validation."
    )

    secondGui := Gui("+AlwaysOnTop", "Quick Phrase Target Interference")
    secondEdit := secondGui.Add("Edit", "w360 h90", "")
    secondGui.Show("w420 h160")
    secondEdit.Focus()

    if !WinWaitActive("ahk_id " secondGui.Hwnd, , 1)
        throw Error("Second test window did not become active.")

    originalClipboard := ClipboardAll()

    try {
        A_Clipboard := payload

        if !ClipWait(1)
            throw Error("Test clipboard did not become ready.")

        delivery := QuickPhraseTarget.DeliverPaste(target)

        Assert(
            delivery.ok,
            "Quick Phrase target delivery returned failure."
        )
        Assert(
            WinExist("A") == firstGui.Hwnd,
            "Quick Phrase delivery did not reactivate the original window."
        )
        Assert(
            ControlGetFocus("ahk_id " firstGui.Hwnd) == firstEdit.Hwnd,
            "Quick Phrase delivery did not restore the original focused control."
        )
        Assert(
            firstEdit.Text == payload,
            "Quick Phrase delivery did not paste into the original control."
        )
    } finally {
        A_Clipboard := originalClipboard
        secondGui.Destroy()
        firstGui.Destroy()
    }
}

RunInvalidTargetTest() {
    gui := Gui("+AlwaysOnTop", "Quick Phrase Invalid Target Test")
    edit := gui.Add("Edit", "w240 h60", "")
    gui.Show("w300 h130")
    edit.Focus()

    if !WinWaitActive("ahk_id " gui.Hwnd, , 1)
        throw Error("Invalid-target test window did not become active.")

    target := QuickPhraseTarget.Capture()
    gui.Destroy()

    Assert(
        !QuickPhraseTarget.IsWindowValid(target),
        "Destroyed Quick Phrase target window was still considered valid."
    )
    Assert(
        !QuickPhraseTarget.Activate(target),
        "Destroyed Quick Phrase target window was activated unexpectedly."
    )
}

RunTests() {
    source := ReadSource("UI\QuickPhraseGui.ahk")
    rootSource := ReadSource("CapsLock-.ahk")

    Assert(
        InStr(rootSource, '#Include "Core\QuickPhraseTarget.ahk"') > 0,
        "Quick Phrase target module is not included by the application entry point."
    )

    Assert(
        InStr(source, "QuickPhraseTarget.Capture()") > 0
            && InStr(source, "QuickPhraseTarget.DeliverPaste(") > 0
            && InStr(source, "QuickPhraseTarget.RestoreControlFocus(") == 0,
        "Quick Phrase UI is not routed through the isolated target component."
    )

    Assert(
        InStr(source, "AppState.TargetWindow :=") == 0
            && InStr(source, "ControlSend(") == 0,
        "Quick Phrase must not mutate the global paste target or use ControlSend directly."
    )

    Assert(
        InStr(source, "if variables.Length == 0") > 0
            && InStr(source, "ok := QuickPhrasePasteText(") > 0
            && InStr(source, "result.text := QuickPhraseApplyVariables(") > 0,
        "Fixed and variable Quick Phrases must both reach the shared final paste path."
    )

    RunTargetDeliveryTest()
    RunInvalidTargetTest()

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
        "Quick Phrase target regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseTargetRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
