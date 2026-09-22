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
    ExitApp(1)
} catch as err {
    WriteTestResult("FAIL", err.Message)
    FileAppend(
        "Quick Phrase target regression failure: " err.Message Chr(10),
        A_WorkingDir "\tests\QuickPhraseTargetRegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}
