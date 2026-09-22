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
global AutomationValue := "Injected E2E value"

AutomateVariableDialog(*) {
    global AutomationDone
    global AutomationError
    global AutomationValue

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

        ControlSetText(
            AutomationValue,
            "ahk_id " editHwnd,
            "ahk_id " guiHwnd
        )
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

RunVariableEndToEndTest() {
    global AutomationDone
    global AutomationError
    global AutomationValue

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Variable E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")

    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Variable E2E target window did not become active.")

    AppState.TargetWindow := targetGui.Hwnd

    phrase := {
        content: "Prefix {{text}} Suffix"
    }

    AutomationDone := false
    AutomationError := ""
    AutomationValue := "Injected E2E value"

    SetTimer(
        AutomateVariableDialog,
        20
    )

    try {
        QuickPhraseExecutePhrase(
            phrase,
            targetGui.Hwnd
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

RunFixedPhraseEndToEndTest() {
    phraseText := "Fixed Quick Phrase regression"

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Fixed E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")

    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Fixed E2E target window did not become active.")

    AppState.TargetWindow := targetGui.Hwnd

    phrase := {
        content: phraseText
    }

    originalClipboard := ClipboardAll()

    try {
        QuickPhraseExecutePhrase(
            phrase,
            targetGui.Hwnd
        )

        Assert(
            targetEdit.Text == phraseText,
            "Fixed Quick Phrase flow did not paste into the original target. Actual: ["
                targetEdit.Text "]"
        )

        Sleep(AppState.QuickPhraseClipboardRestoreDelay + 50)
    } finally {
        A_Clipboard := originalClipboard
        targetGui.Destroy()
    }
}

RunSelectorFixedPhraseEndToEndTest() {
    phraseText := "Selector fixed phrase result"
    phrase := {
        id: 1,
        name: "Selector fixed phrase",
        category: "",
        order: 1,
        contentFile: "phrase-1.txt",
        content: phraseText
    }

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Fixed E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")
    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Selector fixed E2E target window did not become active.")

    originalPhrases := QuickPhraseStore._phrases
    originalTarget := AppState.TargetWindow
    originalTransaction := AppState.QuickPhraseTransactionActive

    try {
        AppState.TargetWindow := 0
        AppState.QuickPhraseTransactionActive := false
        QuickPhraseStore._phrases := [phrase]

        ; Enter through the same handler used by CapsLock + Shift + P.
        QuickPhraseHandleHotkey()

        selectorGui := AppState.QuickPhraseGui
        if !IsObject(selectorGui)
            throw Error("Quick Phrase selector was not created by the hotkey handler.")

        if !WinWaitActive("ahk_id " selectorGui.Hwnd, , 1)
            throw Error("Selector fixed E2E selector window did not become active.")

        ; Exercise the actual ListView DoubleClick event used by the GUI.
        ControlClick(
            "X20 Y10",
            "ahk_id " selectorGui.Hwnd,
            ,
            "Left",
            2,
            "Pos"
        )

        timeoutAt := A_TickCount + 3000
        while targetEdit.Text != phraseText {
            if A_TickCount >= timeoutAt
                break
            Sleep(20)
        }

        Assert(
            targetEdit.Text == phraseText,
            "Selector fixed Quick Phrase did not paste into the target captured by the hotkey entry. Actual: ["
                targetEdit.Text "]"
        )
    } finally {
        if IsObject(AppState.QuickPhraseGui) {
            try AppState.QuickPhraseGui.Destroy()
        }

        QuickPhraseStore._phrases := originalPhrases
        AppState.TargetWindow := originalTarget
        AppState.QuickPhraseTransactionActive := originalTransaction
        targetGui.Destroy()
    }
}

RunSelectorVariablePhraseEndToEndTest() {
    global AutomationDone
    global AutomationError
    global AutomationValue

    phrase := {
        id: 1,
        name: "Selector multiline YAML phrase",
        category: "",
        order: 1,
        contentFile: "phrase-1.txt",
        content: "你将接收一份 YAML 格式的“上下文交接包”，用于恢复此前会话的工作状态。`r`n`r`n现在准备接收 YAML，这是你的YAML信息：`r`n`r`n{{YAML转生信息}}"
    }

    expectedText := "你将接收一份 YAML 格式的“上下文交接包”，用于恢复此前会话的工作状态。`r`n`r`n现在准备接收 YAML，这是你的YAML信息：`r`n`r`ntitle: Context handoff`r`nstate:`r`n  - first line`r`n  - second line"

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Variable E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")
    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Selector variable E2E target window did not become active.")

    originalPhrases := QuickPhraseStore._phrases
    originalTarget := AppState.TargetWindow
    originalTransaction := AppState.QuickPhraseTransactionActive
    originalVariableGui := AppState.QuickPhraseVariableGui

    try {
        AppState.TargetWindow := 0
        AppState.QuickPhraseTransactionActive := false
        AppState.QuickPhraseVariableGui := ""
        QuickPhraseStore._phrases := [phrase]

        ; Enter through the real CapsLock + Shift + P handler so the test proves
        ; the destination is captured before the selector appears.
        QuickPhraseHandleHotkey()

        selectorGui := AppState.QuickPhraseGui
        if !IsObject(selectorGui)
            throw Error("Quick Phrase selector was not created by the hotkey handler.")

        if !WinWaitActive("ahk_id " selectorGui.Hwnd, , 1)
            throw Error("Selector variable E2E selector window did not become active.")

        AutomationDone := false
        AutomationError := ""
        AutomationValue := "title: Context handoff`r`nstate:`r`n  - first line`r`n  - second line"

        SetTimer(
            AutomateVariableDialog,
            20
        )

        ; Exercise the actual ListView DoubleClick event used by the GUI.
        ControlClick(
            "X20 Y10",
            "ahk_id " selectorGui.Hwnd,
            ,
            "Left",
            2,
            "Pos"
        )

        timeoutAt := A_TickCount + 3000
        while targetEdit.Text != expectedText {
            if A_TickCount >= timeoutAt
                break
            Sleep(20)
        }

        Assert(
            AutomationError == "",
            "Selector variable dialog automation failed: " AutomationError
        )

        Assert(
            AutomationDone,
            "Selector variable dialog was never confirmed."
        )

        Assert(
            targetEdit.Text == expectedText,
            "Selector multiline YAML Quick Phrase did not paste the assembled value into the target captured by the hotkey entry. Actual: ["
                targetEdit.Text "]"
        )
    } finally {
        SetTimer(AutomateVariableDialog, 0)

        if IsObject(AppState.QuickPhraseVariableGui) {
            try AppState.QuickPhraseVariableGui.Destroy()
        }

        if IsObject(AppState.QuickPhraseGui) {
            try AppState.QuickPhraseGui.Destroy()
        }

        QuickPhraseStore._phrases := originalPhrases
        AppState.TargetWindow := originalTarget
        AppState.QuickPhraseTransactionActive := originalTransaction
        AppState.QuickPhraseVariableGui := originalVariableGui
        targetGui.Destroy()
    }
}


try {
    RunVariableEndToEndTest()
    RunFixedPhraseEndToEndTest()
    RunSelectorFixedPhraseEndToEndTest()
    RunSelectorVariablePhraseEndToEndTest()
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
