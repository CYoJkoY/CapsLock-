#Requires AutoHotkey v2.0
#Include ..\Utils\Language.ahk

Assert(condition, message) {
    if !condition
        throw Error(message)
}

RunTests() {
    root := A_WorkingDir

    raw := FileRead(root "\lang.csv", "UTF-8")
    if SubStr(raw, 1, 1) == Chr(0xFEFF)
        raw := SubStr(raw, 2)

    records := LanguagePack._ParseCSVRecords(raw)
    Assert(IsObject(records), "CSV parser did not return a record array.")
    Assert(records.Length > 20, "CSV record count is unexpectedly small.")

    header := LanguagePack._ParseCSVLine(records[1])
    expectedColumns := header.Length
    Assert(expectedColumns == 14, "Unexpected language column count: " expectedColumns)

    for index, record in records {
        if Trim(record) == ""
            continue

        fields := LanguagePack._ParseCSVLine(record)
        Assert(
            fields.Length == expectedColumns,
            "CSV record " index " has " fields.Length
            " columns; expected " expectedColumns "."
        )
    }

    quote := Chr(34)
    fixture := "key,en,fr`r`n"
        . "MULTI," quote "first line`nsecond line" quote "," quote
        . "première ligne`ndeuxième ligne" quote "`r`n"
        . "NEXT,value,suite`r`n"

    fixtureRecords := LanguagePack._ParseCSVRecords(fixture)
    Assert(IsObject(fixtureRecords), "Multiline CSV fixture did not parse.")
    Assert(fixtureRecords.Length == 3, "Multiline CSV fixture split into the wrong number of records.")

    multiFields := LanguagePack._ParseCSVLine(fixtureRecords[2])
    Assert(multiFields.Length == 3, "Multiline CSV record lost columns.")
    Assert(InStr(multiFields[2], "`n") > 0, "Quoted multiline field lost its newline.")
    Assert(InStr(multiFields[3], "`n") > 0, "Second quoted multiline field lost its newline.")

    malformed := LanguagePack._ParseCSVRecords(
        "key,en`r`nBROKEN," quote "unterminated`r`n"
    )
    Assert(malformed === false, "Unterminated quoted CSV input must be rejected.")

    hotkeys := FileRead(root "\Hotkeys\HotkeyBindings.ahk", "UTF-8")
    windowHole := FileRead(root "\Core\WindowHole.ahk", "UTF-8")
    lang := FileRead(root "\lang.csv", "UTF-8")

    expectedHotIf := "#HotIf GetKeyState( " Chr(34) "CapsLock" Chr(34) " , " Chr(34) "P" Chr(34) " ) && !WindowHole.IsActive()"
    Assert(InStr(hotkeys, expectedHotIf) > 0, "Mouse opacity handlers are not disabled during Window Hole.")

    Assert(InStr(windowHole, "static SecondaryHwnd := 0") > 0, "Window Hole has no explicit secondary target state.")
    Assert(InStr(windowHole, "this.SecondaryHwnd := secondaryHwnd") > 0, "Layer 2 does not lock the selected secondary target.")
    Assert(InStr(windowHole, "if !this.SecondLevelActive || !this.SecondaryHwnd") > 0, "Window Hole update path does not use the locked secondary target.")
    Assert(InStr(windowHole, "this.SecondaryHwnd := 0") > 0, "Window Hole never clears the secondary target.")

    Assert(InStr(lang, "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE") > 0, "Missing localized second-level unavailable message.")

    return true
}

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend(
        "Regression test failure: " err.Message "`n",
        A_WorkingDir "\tests\RegressionTests.log",
        "UTF-8"
    )
    ExitApp(1)
}