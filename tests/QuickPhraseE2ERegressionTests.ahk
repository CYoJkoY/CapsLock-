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

    target := QuickPhraseTarget.Capture()

    Assert(
        target.window == targetGui.Hwnd
            && target.control == targetEdit.Hwnd,
        "Variable E2E target capture did not preserve the original Edit control."
    )

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

RunFixedPhraseEndToEndTest() {
    phraseText := "Fixed Quick Phrase regression"

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Fixed E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")

    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Fixed E2E target window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        target.window == targetGui.Hwnd
            && target.control == targetEdit.Hwnd,
        "Fixed E2E target capture did not preserve the original Edit control."
    )

    phrase := {
        content: phraseText
    }

    originalClipboard := ClipboardAll()

    try {
        QuickPhraseExecutePhrase(
            phrase,
            target
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
    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Fixed E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")
    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Selector fixed E2E target window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        target.window == targetGui.Hwnd
            && target.control == targetEdit.Hwnd,
        "Selector fixed E2E target capture did not preserve the original Edit control."
    )

    originalPhrases := QuickPhraseStore._phrases
    originalTarget := AppState.QuickPhrasePasteTarget
    originalTransaction := AppState.QuickPhraseTransactionActive

    phrase := {
        id: 1,
        name: "Selector fixed phrase",
        category: "",
        order: 1,
        contentFile: "phrase-1.txt",
        content: "Selector fixed phrase result"
    }

    AppState.QuickPhrasePasteTarget := target
    AppState.QuickPhraseTransactionActive := false
    QuickPhraseStore._phrases := [phrase]

    selectorGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Fixed E2E")
    list := selectorGui.Add(
        "ListView",
        "w420 r3 -Multi",
        ["ID", "Name", "Category", "Preview"]
    )
    list.Add(, phrase.id, phrase.name, phrase.category, phrase.content)
    list.Modify(1, "Select")
    list.Modify(1, "Focus")
    selectorGui.ListView := list
    selectorGui.Show("w460 h180")
    WinActivate("ahk_id " selectorGui.Hwnd)

    if !WinWaitActive("ahk_id " selectorGui.Hwnd, , 1)
        throw Error("Selector fixed E2E selector window did not become active.")

    try {
        QuickPhraseUseSelected(selectorGui)

        timeoutAt := A_TickCount + 2000
        while targetEdit.Text != phrase.content {
            if A_TickCount >= timeoutAt
                break
            Sleep(20)
        }

        Assert(
            targetEdit.Text == phrase.content,
            "Selecting a normal fixed Quick Phrase from the selector did not paste into the original target. Actual: ["
                targetEdit.Text "]"
        )
    } finally {
        if IsObject(selectorGui) {
            try selectorGui.Destroy()
        }

        QuickPhraseStore._phrases := originalPhrases
        AppState.QuickPhrasePasteTarget := originalTarget
        AppState.QuickPhraseTransactionActive := originalTransaction
        targetGui.Destroy()
    }
}

RunSelectorVariablePhraseEndToEndTest() {
    global AutomationDone
    global AutomationError
    global AutomationValue

    targetGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Variable E2E Target")
    targetEdit := targetGui.Add("Edit", "w420 h100", "")
    targetGui.Show("w480 h170")
    targetEdit.Focus()
    WinActivate("ahk_id " targetGui.Hwnd)

    if !WinWaitActive("ahk_id " targetGui.Hwnd, , 1)
        throw Error("Selector variable E2E target window did not become active.")

    target := QuickPhraseTarget.Capture()

    Assert(
        target.window == targetGui.Hwnd
            && target.control == targetEdit.Hwnd,
        "Selector variable E2E target capture did not preserve the original Edit control."
    )

    originalPhrases := QuickPhraseStore._phrases
    originalTarget := AppState.QuickPhrasePasteTarget
    originalTransaction := AppState.QuickPhraseTransactionActive
    originalVariableGui := AppState.QuickPhraseVariableGui

    phrase := {
        id: 1,
        name: "Selector multiline YAML phrase",
        category: "",
        order: 1,
        contentFile: "phrase-1.txt",
        content: "你将接收一份 YAML 格式的“上下文交接包”，用于恢复此前会话的工作状态。`r`n`r`n现在准备接收 YAML，这是你的YAML信息：`r`n`r`n{{YAML转生信息}}"
    }

    expectedText := "你将接收一份 YAML 格式的“上下文交接包”，用于恢复此前会话的工作状态。`r`n`r`n现在准备接收 YAML，这是你的YAML信息：`r`n`r`ntitle: Context handoff`r`nstate:`r`n  - first line`r`n  - second line"

    AppState.QuickPhrasePasteTarget := target
    AppState.QuickPhraseTransactionActive := false
    AppState.QuickPhraseVariableGui := ""
    QuickPhraseStore._phrases := [phrase]

    selectorGui := Gui("+AlwaysOnTop", "Quick Phrase Selector Variable E2E")
    list := selectorGui.Add(
        "ListView",
        "w420 r3 -Multi",
        ["ID", "Name", "Category", "Preview"]
    )
    list.Add(, phrase.id, phrase.name, phrase.category, phrase.content)
    list.Modify(1, "Select")
    list.Modify(1, "Focus")
    selectorGui.ListView := list
    selectorGui.Show("w460 h180")
    WinActivate("ahk_id " selectorGui.Hwnd)

    if !WinWaitActive("ahk_id " selectorGui.Hwnd, , 1)
        throw Error("Selector variable E2E selector window did not become active.")

    AutomationDone := false
    AutomationError := ""
    AutomationValue := "title: Context handoff`r`nstate:`r`n  - first line`r`n  - second line"

    SetTimer(
        AutomateVariableDialog,
        20
    )

    try {
        QuickPhraseUseSelected(selectorGui)

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
            "Selector multiline YAML Quick Phrase did not paste the assembled value into the original target. Actual: ["
                targetEdit.Text "]"
        )
    } finally {
        SetTimer(AutomateVariableDialog, 0)

        if IsObject(AppState.QuickPhraseVariableGui) {
            try AppState.QuickPhraseVariableGui.Destroy()
        }

        if IsObject(selectorGui) {
            try selectorGui.Destroy()
        }

        QuickPhraseStore._phrases := originalPhrases
        AppState.QuickPhrasePasteTarget := originalTarget
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
