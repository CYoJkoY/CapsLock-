#Requires AutoHotkey v2.0

Clamp(val, min, max) => val < min ? min : (val > max ? max : val)

ShowToolTip(msg, durationMs := 1500) {
    OSD.ShowNotification(msg, durationMs)
}

Join(arr, sep := " ") {
    len := arr.Length
    if len == 0
        return ""
    if len == 1
        return arr[1]

    ; Pre-calculate total length and pre-allocate string buffer
    ; This eliminates repeated memory reallocations during concatenation
    sepLen := StrLen(sep)
    totalLen := sepLen * (len - 1)
    for v in arr
        totalLen += StrLen(v)

    result := ""
    VarSetStrCapacity(&result, totalLen)

    result := arr[1]
    Loop len - 1 {
        result .= sep . arr[A_Index + 1]
    }
    return result
}

PasteTempText(content, tooltipMsg := "") {
    tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_MSec ".txt"
    FileAppend(content, tempFile, "UTF-8")

    ClipboardHelper.SetClipboardFile(tempFile)
    ActivateAndPaste()
    CleanupManager.ScheduleDeletion(tempFile)

    if tooltipMsg
        ShowToolTip(tooltipMsg, 2000)
}

CapturePasteTarget() {
    activeHwnd := WinExist("A")
    if !activeHwnd
        return

    if IsSet(CustomMenu) && activeHwnd == CustomMenu.menuHwnd
        return

    if IsObject(AppState.FullHistoryGui) && activeHwnd == AppState.FullHistoryGui.Hwnd
        return

    ; Skip redundant assignment if target hasn't changed
    if AppState.TargetWindow == activeHwnd
        return

    AppState.TargetWindow := activeHwnd
}

AutoCleanHistory() {
    if !AppState.AutoCleanEnabled
        return

    maxItems := AppState.MaxHistoryItems
    if (maxItems <= 0)
        return

    if (AppState.History.Length > maxItems) {
        while (AppState.History.Length > maxItems)
            AppState.History.Pop()

        HistoryManager.ScheduleSave()
    }
}
