#Requires AutoHotkey v2.0

Clamp(val, min, max) => val < min ? min : (val > max ? max : val)

ShowToolTip(msg, durationMs := 1500) {
    OSD.ShowNotification(msg, durationMs)
}

Join(arr, sep := " ") {
    if arr.Length == 0
        return ""

    s := ""
    for v in arr
        s .= v sep

    return SubStr(s, 1, -StrLen(sep))
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
