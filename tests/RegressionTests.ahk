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

        for columnIndex, value in fields {
            if columnIndex == 1
                continue
            Assert(
                Trim(value) != "",
                "CSV record " index " has a blank translation in column " columnIndex "."
            )
        }
    }

    quote := Chr(34)
    fixture := "key,en,fr`r`n"
        . "MULTI," . quote . "first line`nsecond line" . quote . "," . quote
        . "première ligne`ndeuxième ligne" . quote . "`r`n"
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
    Assert(malformed == false, "Unterminated quoted CSV input must be rejected.")

    hotkeys := FileRead(root "\Hotkeys\HotkeyBindings.ahk", "UTF-8")
    windowHole := FileRead(root "\Core\WindowHole.ahk", "UTF-8")
    lang := FileRead(root "\lang.csv", "UTF-8")

    expectedHotIf := "#HotIf GetKeyState( " Chr(34) "CapsLock" Chr(34) ", " Chr(34) "P" Chr(34) " ) && !WindowHole.IsActive()"
    Assert(InStr(hotkeys, expectedHotIf) > 0, "Mouse opacity handlers are not disabled during Window Hole.")

    Assert(InStr(windowHole, "static SecondaryHwnd := 0") > 0, "Window Hole has no explicit secondary target state.")
    Assert(InStr(windowHole, "this.SecondaryHwnd := secondaryHwnd") > 0, "Layer 2 does not lock the selected secondary target.")
    Assert(InStr(windowHole, "if !this.SecondLevelActive || !this.SecondaryHwnd") > 0, "Window Hole update path does not use the locked secondary target.")
    Assert(InStr(windowHole, "this.SecondaryHwnd := 0") > 0, "Window Hole never clears the secondary target.")
    Assert(InStr(windowHole, "if this._IsPointInsideWindow(this.PrimaryHwnd, mx, my) {") > 0, "Primary hole still follows the cursor outside the primary window.")
    Assert(InStr(windowHole, "if !this._ApplyHole(this.PrimaryHwnd, true, mx, my) {") > 0, "Primary Window Hole failure path is not explicitly scoped.")
    Assert(InStr(windowHole, "if !this._IsPointInsideWindow(this.SecondaryHwnd, mx, my)") > 0, "Secondary hole does not freeze after penetrating its target.")

    Assert(InStr(windowHole, 'callback: (*) => SetWindowHoleShape("circle")') > 0, "Circle shape option is not directly actionable.")
    Assert(InStr(windowHole, 'callback: (*) => SetWindowHoleShape("rounded")') > 0, "Rounded shape option is not directly actionable.")
    Assert(InStr(windowHole, 'callback: (*) => SetWindowHoleShape("square")') > 0, "Square shape option is not directly actionable.")
    Assert(InStr(windowHole, 'callback: (*) => SetWindowHoleActivation("hold")') > 0, "Hold activation option is not directly actionable.")
    Assert(InStr(windowHole, 'callback: (*) => SetWindowHoleActivation("toggle")') > 0, "Toggle activation option is not directly actionable.")
    Assert(InStr(windowHole, "children: shapeChildren") == 0, "Window Hole shape options are still nested one level too deep.")
    Assert(InStr(windowHole, "children: activationChildren") == 0, "Window Hole activation options are still nested one level too deep.")

    Assert(InStr(lang, "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE") > 0, "Missing localized second-level unavailable message.")

    ; The generated locale cache must be tied to the current CSV source.
    Assert(LanguagePack.BuildAllFromCSV(root "\lang.csv"), "Language cache rebuild failed.")
    Assert(LanguagePack._IsCacheCurrent(), "Fresh language cache is not recognized as current.")
    Assert(LanguagePack.Load("en"), "English locale failed to load after cache rebuild.")
    Assert(LanguagePack.GetLoaded() == "en", "Loaded locale code was not updated after cache rebuild.")
    Assert(LanguagePack.BuildAllFromCSV(root "\lang.csv"), "Second language cache rebuild failed.")
    Assert(LanguagePack.GetLoaded() == "", "Loaded locale cache was not invalidated after regeneration.")

    stampPath := LanguagePack.CacheStampFile
    FileDelete(stampPath)
    Assert(!LanguagePack._IsCacheCurrent(), "Missing language cache stamp was not detected.")
    LanguagePack.Init()
    Assert(FileExist(stampPath), "Language cache stamp was not recreated.")
    Assert(LanguagePack._IsCacheCurrent(), "Language cache was not rebuilt after a stale stamp.")

    sourceFingerprint := LanguagePack._Fingerprint(raw)
    changedRaw := StrReplace(raw, "MENU_WINDOW_HOLE,Window Hole", "MENU_WINDOW_HOLE,Window Hole Test", , 1)
    changedFingerprint := LanguagePack._Fingerprint(changedRaw)
    Assert(sourceFingerprint != changedFingerprint, "Language source fingerprint did not change after a translation update.")

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