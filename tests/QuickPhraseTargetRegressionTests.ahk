#Requires AutoHotkey v2.0

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
    Assert(
        !FileExist(A_WorkingDir "\Core\QuickPhraseTarget.ahk"),
        "The TDD red phase requires the QuickPhraseTarget module to be absent before implementation."
    )

    source := FileExist(A_WorkingDir "\Core\QuickPhraseTarget.ahk")
        ? FileRead(A_WorkingDir "\Core\QuickPhraseTarget.ahk", "UTF-8")
        : ""

    Assert(
        source == "",
        "QuickPhraseTarget implementation unexpectedly exists during the red phase."
    )

    return true
}

try {
    RunTests()
    ExitApp(1)
} catch as err {
    FileAppend(
        "Quick Phrase target regression red-phase failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseTargetRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
