#Requires AutoHotkey v2.0
#SingleInstance Force

; Exercise history search, preview normalization, and incremental page bounds
; without constructing a native window.
#Include "..\Config\Globals.ahk"
#Include "..\History\HistoryQueries.ahk"

AppState.History := []
Loop 120 {
    AppState.History.Push(Map(
        "text", "Test Entry " A_Index "`nSecond Line",
        "time", "2026-10-03 10:00:00"
    ))
}

results := HistorySearch("Test Entry 1")
if results.Length < 1 {
    FileAppend("FAIL: history search did not find matching entries`n", "*")
    ExitApp(1)
}

allResults := HistorySearch("")
if allResults.Length != AppState.History.Length {
    FileAppend("FAIL: empty search did not return the full history`n", "*")
    ExitApp(1)
}

normalizedResults := HistorySearch("Entry 1 Second Line")
if normalizedResults.Length != 1 || normalizedResults[1] != 1 {
    FileAppend("FAIL: search did not match normalized preview text`n", "*")
    ExitApp(1)
}

preview := HistoryPreviewText("Line 1`nLine 2")
if InStr(preview, "`n") {
    FileAppend("FAIL: preview retained a line break`n", "*")
    ExitApp(1)
}

firstPage := HistoryPageRange(120, 0, 50)
secondPage := HistoryPageRange(120, firstPage.end, 100)
lastPage := HistoryPageRange(120, secondPage.end, 150)
if (
    firstPage.start != 1 || firstPage.end != 50
    || secondPage.start != 51 || secondPage.end != 100
    || lastPage.start != 101 || lastPage.end != 120
) {
    FileAppend("FAIL: incremental history page boundaries are incorrect`n", "*")
    ExitApp(1)
}

FileAppend("PASS: history search, preview, and paging checks succeeded`n", "*")
ExitApp(0)
