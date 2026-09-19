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
    trayMenu := FileRead(root "\Tray\TrayMenu.ahk", "UTF-8")
    customMenu := FileRead(root "\History\CustomMenu.ahk", "UTF-8")
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

    Assert(InStr(trayMenu, 'callback: (*) => SetWindowHoleShape("circle")') > 0, "Circle shape option is not directly actionable.")
    Assert(InStr(trayMenu, 'callback: (*) => SetWindowHoleShape("rounded")') > 0, "Rounded shape option is not directly actionable.")
    Assert(InStr(trayMenu, 'callback: (*) => SetWindowHoleShape("square")') > 0, "Square shape option is not directly actionable.")
    Assert(InStr(trayMenu, 'callback: (*) => SetWindowHoleActivation("hold")') > 0, "Hold activation option is not directly actionable.")
    Assert(InStr(trayMenu, 'callback: (*) => SetWindowHoleActivation("toggle")') > 0, "Toggle activation option is not directly actionable.")
    Assert(InStr(trayMenu, "children: shapeChildren") > 0, "Window Hole shape choices are not grouped behind a Hole shape submenu.")
    Assert(InStr(trayMenu, "children: activationChildren") > 0, "Window Hole activation choices are not grouped behind an Activation submenu.")
    Assert(InStr(trayMenu, 'Lang("MENU_WINDOW_HOLE_SHAPE", "Hole shape")') > 0, "Hole shape parent entry is missing.")
    Assert(InStr(trayMenu, 'Lang("MENU_WINDOW_HOLE_ACTIVATION", "Activation")') > 0, "Activation parent entry is missing.")

    Assert(InStr(customMenu, "static nestedSubMenuGui := " Chr(34) Chr(34)) > 0, "CustomMenu has no nested submenu state.")
    Assert(InStr(customMenu, "static ToggleNestedSubMenu(entry, *)") > 0, "CustomMenu has no nested submenu toggle handler.")
    Assert(InStr(customMenu, "static ShowNestedSubMenu(parentEntry)") > 0, "CustomMenu has no nested submenu renderer.")
    Assert(InStr(customMenu, "if hasChildren") > 0, "CustomMenu does not preserve children while normalizing submenu entries.")

    ; SetWindowRgn takes an explicit BOOL bRedraw argument before its return type.
    Assert(InStr(windowHole, '"PtInRegion"') > 0, "Window Hole does not validate hole-region exclusion.")
    Assert(InStr(windowHole, '"Ptr", region,`n                "Int", 1,`n                "Int"') > 0, "Window Hole does not explicitly request redraw after SetWindowRgn.")
    Assert(InStr(windowHole, '"Ptr", state.originalRegion,`n                        "Int", 1,`n                        "Int"') > 0, "Window Hole restoration does not explicitly request redraw.")
    Assert(InStr(windowHole, '"Ptr", hwnd, "Ptr", 0, "Int", 1, "Int"') > 0, "Window Hole clear-region path does not explicitly request redraw.")

    ; DWM presentation must not leave system backdrop/corner pixels in the carved area.
    Assert(InStr(windowHole, "static _DwmGetIntAttribute(hwnd, attribute, &value)") > 0, "Window Hole has no DWM attribute reader.")
    Assert(InStr(windowHole, "static _DwmSetIntAttribute(hwnd, attribute, value)") > 0, "Window Hole has no DWM attribute writer.")
    Assert(InStr(windowHole, '"dwmapi\DwmGetWindowAttribute"') > 0, "Window Hole DWM attribute reader has an invalid DLL entry point.")
    Assert(InStr(windowHole, '"dwmapi\DwmSetWindowAttribute"') > 0, "Window Hole DWM attribute writer has an invalid DLL entry point.")
    Assert(InStr(windowHole, "DWM_SYSTEMBACKDROP_TYPE := 38") > 0, "Window Hole system-backdrop constant is missing.")
    Assert(InStr(windowHole, "DWM_WINDOW_CORNER_PREFERENCE := 33") > 0, "Window Hole corner-preference constant is missing.")
    Assert(InStr(windowHole, "this._DwmSetIntAttribute(hwnd, this.DWM_SYSTEMBACKDROP_TYPE, this.DWMSBT_NONE)") > 0, "Window Hole does not disable the Windows 11 system backdrop while active.")
    Assert(InStr(windowHole, "this._DwmSetIntAttribute(hwnd, this.DWM_WINDOW_CORNER_PREFERENCE, this.DWMWCP_DONOTROUND)") > 0, "Window Hole does not disable Windows 11 rounded-corner rendering while active.")
    Assert(InStr(windowHole, "WinGetTransparent(\"ahk_id \" hwnd)") > 0, "Window Hole does not capture the target opacity before forcing an opaque source surface.")
    Assert(InStr(windowHole, "WinSetTransparent(255, \"ahk_id \" hwnd)") > 0, "Window Hole does not normalize target opacity while active.")
    Assert(InStr(windowHole, "state.originalSystemBackdropType") > 0, "Window Hole does not preserve the original DWM system backdrop type.")
    Assert(InStr(windowHole, "state.originalCornerPreference") > 0, "Window Hole does not preserve the original DWM corner preference.")
    Assert(InStr(windowHole, "this._RestoreWindowVisualState(hwnd, state)") > 0, "Window Hole does not restore temporary visual state.")

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