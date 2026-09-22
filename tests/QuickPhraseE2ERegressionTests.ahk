#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

#Include "..\Config\Globals.ahk"
#Include "..\Utils\Language.ahk"
#Include "..\UI\ThemeHelper.ahk"
#Include "..\Core\QuickPhraseStore.ahk"
#Include "..\Core\QuickPhraseTarget.ahk"
#Include "..\UI\QuickPhraseGui.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

WriteTestResult(status, message := "") {
    path := A_Args.Length > 0 ? A_Args[1] : A_WorkingDir "\tests\QuickPhraseE2ERegressionTests.result"
    try FileDelete(path)

    payload := status
    if message != ""
        payload .= Chr(10) message

    FileAppend(payload, path, "UTF-8")
}

global AutomationDone := false
global AutomationError := ""

AutomateVariableDialog(*) {
    global AutomationDone
    global AutomationError

    if AutomationDone
        return

    if !IsObject(AppState.QuickPhraseVariableGui)
        return

    guiHwnd := AppState.QuickPhraseVariableGui.Hwnd

    try {
        editHwnd := ControlGetHwnd("Edit1", "ahk_id " guiHwnd)
        buttonHwnd := ControlGetHwnd("Button1", "ahk_id " guiHwnd)

        if !editHwnd || !buttonHwnd
            return

        ControlFocus(
            "ahk_id " editHwnd,
            "ahk_id " guiHwnd
        )

        SendText("Injected E2E value")
        Sleep(60)

        ControlClick(
            "ahk_id " buttonHwnd,
            "ahk_id " guiHwnd
        )

        AutomationDone := true
        SetTimer(AutomateVariableDialog, 0)
    } catch as err {
        AutomationError := err.Message
        AutomationDone := true
        SetTimer(AutomateVariableDialog, 0)
    }
}

RunEndToEndTest() {
    global AutomationDone
    global AutomationError

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")

    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("E2E target window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        target.window == targetGui.Hwnd
            && target.control == targetEdit.Hwnd,
        "E2E target capture did not preserve the original Edit control."
    )

    phrase := {
        content: "Prefix {{text}} Suffix"
    }

    AutomationDone := false
    AutomationError := ""

    SetTimer(
        AutomateVariableDialog,
        20
    )

    try {
        QuickPhraseExecutePhrase(
            phrase,
            target
        )
    } finally {
        SetTimer(
            AutomateVariableDialog,
            0
        )
    }

    Assert(
        AutomationError == "",
        "Variable dialog automation failed: " AutomationError
    )

    Assert(
        AutomationDone,
        "Variable dialog was never confirmed."
    )

    Assert(
        targetEdit.Text == "Prefix Injected E2E value Suffix",
        "Complete Quick Phrase flow did not paste the assembled value into the original target. Actual: ["
            targetEdit.Text "]"
    )

    targetGui.Destroy()
}

try {
    RunEndToEndTest()
    WriteTestResult("PASS")
    ExitApp(0)
} catch as err {
    WriteTestResult("FAIL", err.Message)
    FileAppend(
        "Quick Phrase E2E regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseE2ERegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
