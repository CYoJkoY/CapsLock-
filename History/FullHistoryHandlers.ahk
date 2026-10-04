#Requires AutoHotkey v2.0

OnFullHistoryDoubleClick(lv, row) {
    if row == 0
        return

    realIndex := lv.GetText(row, 1)
    if !(realIndex ~= "^\d+$")
        return

    PasteSingleFile(AppState.History[Integer(realIndex)], false)
}

OnFullHistoryContextMenu(lv, row, isRightClick, x, y) {
    if row == 0
        return

    realIdx := lv.GetText(row, 1)
    if !(realIdx ~= "^\d+$")
        return

    item := AppState.History[Integer(realIdx)]

    myMenu := Menu()
    myMenu.Add(Lang("CONTEXT_PASTE_FILE"), (*) => PasteAsMultipleFiles([item]))
    myMenu.Add(Lang("CONTEXT_COPY"), (*) => CopyHistoryEntryToClipboard(item))
    myMenu.Add(Lang("CONTEXT_PREVIEW"), (*) => ShowPreviewGui(item["text"]))
    myMenu.Add("× " Lang("CONTEXT_DELETE"), (*) => DeleteFromFullHistory(Integer(realIdx)))
    myMenu.Show(x, y)
}

; Copy an entry back to the clipboard without opening the preview.
; The next clipboard change is ignored so the copy is not duplicated in history.
CopyHistoryEntryToClipboard(historyItem) {
    if !IsObject(historyItem) || historyItem["text"] == "" {
        ShowToolTip(Lang("MSG_SELECT_ITEM"), 1200)
        return
    }

    AppState.IgnoreNextClipChange := true
    A_Clipboard := historyItem["text"]
    ShowToolTip(Lang("MSG_COPIED", , "Copied!"), 1200)
}

PasteSelectedFromFullHistory() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    fileList := []

    row := 0
    while row := lv.GetNext(row, "Checked") {
        realIdx := lv.GetText(row, 1)
        if realIdx ~= "^\d+$"
            fileList.Push(AppState.History[Integer(realIdx)])
    }

    if fileList.Length == 0 {
        ShowToolTip(Lang("MSG_SELECT_ITEM"), 1500)
        return
    }

    if !EnsureFullHistoryTargetWindow()
        return

    WinActivate("ahk_id " AppState.TargetWindow)
    Sleep(100)

    for item in fileList {
        PasteSingleFile(item, false)
        Sleep(200)
    }

    ShowToolTip(Lang("MSG_PASTE_COMPLETE"), 1500)
}

PasteSelectedFromFullHistoryText() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    textList := []

    row := 0
    while row := lv.GetNext(row, "Checked") {
        realIdx := lv.GetText(row, 1)
        if realIdx ~= "^\d+$"
            textList.Push(AppState.History[Integer(realIdx)]["text"])
    }

    if textList.Length == 0 {
        ShowToolTip(Lang("MSG_SELECT_ITEM"), 1500)
        return
    }

    combined := Join(textList, "`n")

    if !EnsureFullHistoryTargetWindow()
        return

    PasteAsPlainText(combined, Lang("MSG_PASTE_MULTI_COMPLETE", "", textList.Length))
}

OnSelectAllClicked(chk, info) {
    lv := chk.Gui.ListView
    totalRows := lv.GetCount()
    if totalRows == 0
        return

    newState := chk.Value ? "Check" : "-Check"

    SendMessage(0x000B, 0, 0, lv.Hwnd) ; WM_SETREDRAW = 0
    loop totalRows {
        lv.Modify(A_Index, newState)
    }
    SendMessage(0x000B, 1, 0, lv.Hwnd) ; WM_SETREDRAW = 1
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)
}

OnItemCheck(lv, row, checked) {
    guiObj := lv.Gui
    if !guiObj.HasProp("chkSelectAll")
        return

    totalRows := lv.GetCount()
    if totalRows == 0
        return

    checkedCount := 0
    currentRow := 0
    while currentRow := lv.GetNext(currentRow, "Checked") {
        checkedCount++
    }

    guiObj.chkSelectAll.Value := (checkedCount == totalRows) ? 1 : 0
}

EnsureFullHistoryTargetWindow() {
    targetHwnd := AppState.TargetWindow
    if targetHwnd && WinExist("ahk_id " targetHwnd)
        return true

    activeHwnd := WinExist("A")
    if activeHwnd && !WindowIsOwnProcess(activeHwnd) {
        AppState.TargetWindow := activeHwnd
        return true
    }

    ShowToolTip(Lang("MSG_TARGET_WINDOW_GONE", "", "Target window is no longer available."), 1800)
    return false
}

OnDeleteSelected(btn, info) {
    myGui := btn.Gui
    lv := myGui.ListView
    indices := []

    row := 0
    while row := lv.GetNext(row, "Checked") {
        realIdx := lv.GetText(row, 1)
        if realIdx ~= "^\d+$"
            indices.Push(Integer(realIdx))
    }

    if indices.Length == 0 {
        ShowToolTip(Lang("MSG_SELECT_ITEM", "", "Please select an item."), 1500)
        return
    }

    indices := StrSplit(Sort(Join(indices, "`n"), "N R"), "`n")
    for idx in indices {
        idx := Integer(idx)
        if idx >= 1 && idx <= AppState.History.Length
            AppState.History.RemoveAt(idx)
    }

    HistoryManager.revision++

    RefreshFullHistoryList()
    ShowToolTip(Lang("MSG_DELETED", "", "Deleted!"), 1200)
}
