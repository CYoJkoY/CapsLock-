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

    ; Checked rows define a batch. With no checks, treat the highlighted
    ; row as a single-item paste so Enter and the primary button work naturally.
    if fileList.Length == 0 {
        selectedRow := lv.GetNext(0, "Focused")
        if !selectedRow
            selectedRow := lv.GetNext(0)
        if !selectedRow && lv.GetCount() > 0
            selectedRow := 1

        if selectedRow {
            realIdx := lv.GetText(selectedRow, 1)
            if realIdx ~= "^\d+$"
                fileList.Push(AppState.History[Integer(realIdx)])
        }
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
    SetFullHistoryRowsChecked(chk.Gui, chk.Value ? true : false)
}

SetFullHistoryRowsChecked(guiObj, shouldCheck) {
    if !IsObject(guiObj) || !guiObj.HasProp("ListView")
        return

    lv := guiObj.ListView
    totalRows := lv.GetCount()
    if totalRows == 0 {
        UpdateFullHistorySelectAll(guiObj)
        return
    }

    newState := shouldCheck ? "Check" : "-Check"

    SendMessage(0x000B, 0, 0, lv.Hwnd) ; WM_SETREDRAW = 0
    loop totalRows
        lv.Modify(A_Index, newState)
    SendMessage(0x000B, 1, 0, lv.Hwnd) ; WM_SETREDRAW = 1
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)

    UpdateFullHistorySelectAll(guiObj)
}

; Space toggles only the focused row's checkbox. It is bound exclusively to
; the focused ListView, so Space remains ordinary text in the search field.
ToggleFullHistoryFocusedCheck() {
    myGui := AppState.FullHistoryGui
    if !IsObject(myGui) || !myGui.HasProp("ListView")
        return

    lv := myGui.ListView
    row := lv.GetNext(0, "Focused")
    if !row
        row := lv.GetNext(0)
    if !row
        return

    isChecked := lv.GetNext(row - 1, "Checked") == row
    lv.Modify(row, isChecked ? "-Check" : "Check")
    UpdateFullHistorySelectAll(myGui)
}

; Ctrl+A follows the visible ListView scope: check every row, or clear all
; checks when every visible row is already checked.
ToggleFullHistorySelectAll() {
    myGui := AppState.FullHistoryGui
    if !IsObject(myGui) || !myGui.HasProp("ListView")
        return

    lv := myGui.ListView
    totalRows := lv.GetCount()
    if totalRows == 0
        return

    checkedCount := 0
    currentRow := 0
    while currentRow := lv.GetNext(currentRow, "Checked")
        checkedCount++

    SetFullHistoryRowsChecked(myGui, checkedCount != totalRows)
}

UpdateFullHistorySelectAll(guiObj) {
    if !IsObject(guiObj) || !guiObj.HasProp("chkSelectAll") || !guiObj.HasProp("ListView")
        return

    lv := guiObj.ListView
    totalRows := lv.GetCount()
    checkedCount := 0
    currentRow := 0
    while currentRow := lv.GetNext(currentRow, "Checked")
        checkedCount++

    guiObj.chkSelectAll.Value := (totalRows > 0 && checkedCount == totalRows) ? 1 : 0
}

OnItemCheck(lv, row, checked) {
    UpdateFullHistorySelectAll(lv.Gui)
}

; Move the highlighted result without transferring keyboard focus from the
; search Edit control. The existing Enter binding can then paste the result.
MoveFullHistorySelection(delta) {
    myGui := AppState.FullHistoryGui
    if !IsObject(myGui) || !myGui.HasProp("ListView")
        return

    lv := myGui.ListView
    rowCount := lv.GetCount()
    if rowCount < 1
        return

    row := lv.GetNext(0, "Focused")
    if !row
        row := lv.GetNext(0)

    row += delta
    row := Max(1, Min(row, rowCount))

    lv.Modify(row, "Select Focus")
    try lv.Modify(row, "Vis")
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
