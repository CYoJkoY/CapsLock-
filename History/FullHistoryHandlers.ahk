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
    myMenu.Add("📄 " Lang("CONTEXT_PASTE_FILE"), (*) => PasteAsMultipleFiles([item]))
    myMenu.Add("📋 " Lang("CONTEXT_COPY"), (*) => CopyHistoryEntryToClipboard(item))
    myMenu.Add("🔍 " Lang("CONTEXT_PREVIEW"), (*) => ShowPreviewGui(item["text"]))
    myMenu.Add("❌ " Lang("CONTEXT_DELETE"), (*) => DeleteFromFullHistory(Integer(realIdx)))
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

    if !EnsureFullHistoryTargetWindow(myGui)
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

    if !EnsureFullHistoryTargetWindow(myGui)
        return

    PasteAsPlainText(combined, Lang("MSG_PASTE_MULTI_COMPLETE", "", textList.Length))
}

OnSelectAllClicked(chk, info) {
    lv := chk.Gui.ListView
    totalRows := lv.GetCount()
    if totalRows == 0
        return

    newState := chk.Value ? "Check" : "-Check"

    ; 暂停重绘以提高大量历史记录勾选时的性能
    SendMessage(0x000B, 0, 0, lv.Hwnd) ; WM_SETREDRAW = 0
    loop totalRows {
        lv.Modify(A_Index, newState)
    }
    SendMessage(0x000B, 1, 0, lv.Hwnd) ; WM_SETREDRAW = 1
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)
}

OnDeleteSelected(*) {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView

    indicesToDelete := []

    row := 0
    while row := lv.GetNext(row, "Checked") {
        realIdx := lv.GetText(row, 1)
        if realIdx ~= "^\d+$"
            indicesToDelete.Push(Integer(realIdx))
    }

    if indicesToDelete.Length == 0 {
        ShowToolTip(Lang("MSG_SELECT_ITEM"), 1500)
        return
    }

    while indicesToDelete.Length {
        maxPos := 1

        loop indicesToDelete.Length {
            if indicesToDelete[A_Index] > indicesToDelete[maxPos]
                maxPos := A_Index
        }

        HistoryManager.Delete(indicesToDelete[maxPos])
        indicesToDelete.RemoveAt(maxPos)
    }

    RefreshFullHistoryList()
}

OnItemCheck(lv, row, checked) {
    ; 当用户手动单选时，若全部勾选则同步勾选全选框，反之取消全选框勾选
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

UpdateSelectAllCheckbox() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView

    realRows := GetRealListViewRows(lv)
    checkedRows := GetCheckedRealListViewRows(lv)

    myGui.chkSelectAll.Value := (realRows.Length > 0 && checkedRows.Length == realRows.Length) ? 1 : 0
}

EnsureFullHistoryTargetWindow(myGui) {
    if AppState.TargetWindow && WinExist("ahk_id " AppState.TargetWindow)
        return true

    current := WinExist("A")
    if current && current != myGui.Hwnd {
        AppState.TargetWindow := current
        return true
    }

    ShowToolTip(Lang("MSG_TARGET_CLOSED"), 2500)

    loop 20 {
        Sleep(100)

        current := WinExist("A")
        if current && current != myGui.Hwnd {
            AppState.TargetWindow := current
            return true
        }
    }

    ShowToolTip(Lang("MSG_NO_TARGET"), 2000)
    return false
}

GetRealListViewRows(lv) {
    rows := []

    loop lv.GetCount() {
        if lv.GetText(A_Index, 1) ~= "^\d+$"
            rows.Push(A_Index)
    }

    return rows
}

GetCheckedRealListViewRows(lv) {
    rows := []

    row := 0
    while row := lv.GetNext(row, "Checked") {
        if lv.GetText(row, 1) ~= "^\d+$"
            rows.Push(row)
    }

    return rows
}
