#Requires AutoHotkey v2.0

WriteTestResult(status, message := "") {
    path := A_Args.Length > 0 ? A_Args[1] : A_WorkingDir "\tests\AhkExitSmoke.result"
    try FileDelete(path)

    payload := status
    if message != ""
        payload .= Chr(10) message

    FileAppend(payload, path, "UTF-8")
}

try {
    WriteTestResult("PASS")
    ExitApp(0)
} catch as err {
    WriteTestResult("FAIL", err.Message)
    ExitApp(1)
}
