#Requires AutoHotkey v2.0

#Include "..\Core\QuickPhraseTarget.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

CreateTargetGui(title) {
    gui := Gui("+AlwaysOnTop", title)
    edit := gui.Add("Edit", "w320 h80", "")
    gui.Show("w360 h140")
    edit.Focus()

    return {
        gui: gui,
        edit: edit
    }
}

RunTests() {
    source := CreateTargetGui("Quick Phrase Target Source")
    other := CreateTargetGui("Quick Phrase Target Other")

    try {
        source.edit.Focus()
        target := QuickPhraseTarget.Capture()

        Assert(
            IsObject(target)
                && target.window == source.gui.Hwnd
                && target.control == source.edit.Hwnd,
            "Capture must retain the original window and focused control."
        )

        other.gui.Show()
        other.edit.Focus()

        Assert(
            WinExist("A") == other.gui.Hwnd,
            "The secondary GUI must own foreground focus before restoration."
        )

        Assert(
            QuickPhraseTarget.Activate(target, 2),
            "Captured target window could not be activated."
        )

        Assert(
            WinWaitActive("ahk_id " source.gui.Hwnd, , 0.5) == source.gui.Hwnd,
            "Captured target window did not become active."
        )

        Assert(
            QuickPhraseTarget.RestoreControlFocus(target),
            "Captured focused control could not be restored."
        )

        Assert(
            ControlGetFocus("ahk_id " source.gui.Hwnd) == source.edit.Hwnd,
            "The original Edit control did not regain keyboard focus."
        )

        invalidControlTarget := {
            window: other.gui.Hwnd,
            control: source.edit.Hwnd
        }

        Assert(
            !QuickPhraseTarget.IsControlValid(invalidControlTarget),
            "A control belonging to another window must not be accepted."
        )

        source.gui.Destroy()

        Assert(
            !QuickPhraseTarget.IsWindowValid(target),
            "A destroyed original target window must be rejected."
        )
    } finally {
        try other.gui.Destroy()
        try source.gui.Destroy()
    }

    return true
}

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend(
        "Quick Phrase target regression test failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseTargetRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
