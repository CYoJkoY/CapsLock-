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
    path := A_Args.Length > 0 ? A_Args[1] : A_WorkingDir "\tests\QuickPhraseVariableDialogRegressionTests.result"
    try FileDelete(path)

    payload := status
    if message != ""
        payload .= Chr(10) message

    FileAppend(payload, path, "UTF-8")
}

global VariableDialogAutomationDone := false
global VariableDialogAutomationError := ""

AutomateVariableDialog(*) {
    if VariableDialogAutomationDone
        return

    if !IsObject(AppState.QuickPhraseVariableGui)
        return

    guiHwnd := AppState.QuickPhraseVariableGui.Hwnd

    try {
        editHwnd := ControlGetHwnd("Edit1", "ahk_id " guiHwnd)
        buttonHwnd := ControlGetHwnd("Button1", "ahk_id " guiHwnd)

        if !editHwnd || !buttonHwnd
            return

        ControlSetText(
            "Injected value",
            "ahk_id " editHwnd,
            "ahk_id " guiHwnd
        )

        ; Ensure the native Edit has processed the text update before
        ; invoking the same OK button the user would click.
        Sleep(40)
        ControlClick(
            "ahk_id " buttonHwnd,
            "ahk_id " guiHwnd
        )

        VariableDialogAutomationDone := true
        SetTimer(AutomateVariableDialog, 0)
    } catch as err {
        VariableDialogAutomationError := err.Message
        VariableDialogAutomationDone := true
        SetTimer(AutomateVariableDialog, 0)
    }
}

RunVariableDialogTest() {
    global VariableDialogAutomationDone
    global VariableDialogAutomationError

    phrase := {
        content: "Hello {{text}}!"
    }

    VariableDialogAutomationDone := false
    VariableDialogAutomationError := ""
    AppState.QuickPhraseVariableGui := ""

    SetTimer(
        AutomateVariableDialog,
        20
    )

    result := ShowQuickPhraseVariableDialog(
        phrase,
        ["text"]
    )

    SetTimer(
        AutomateVariableDialog,
        0
    )

    Assert(
        VariableDialogAutomationError == "",
        "Variable dialog automation failed: " VariableDialogAutomationError
    )

    Assert(
        VariableDialogAutomationDone,
        "Variable dialog was not automatically confirmed."
    )

    Assert(
        result.ok,
        "Variable dialog did not report OK after confirmation."
    )

    Assert(
        result.text == "Hello Injected value!",
        "Variable dialog returned incorrect assembled text: [" result.text "]"
    )
}

try {
    RunVariableDialogTest()
    WriteTestResult("PASS")
    ExitApp(0)
} catch as err {
    WriteTestResult("FAIL", err.Message)
    FileAppend(
        "Quick Phrase variable dialog regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseVariableDialogRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
