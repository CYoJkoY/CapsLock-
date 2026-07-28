#Requires AutoHotkey v2.0

ShowFullHistoryGui(ItemName?, ItemPos?, MyMenu?) {
    AppState.TargetWindow := WinExist("A")
    AppState.MAX_FULL_HISTORY_DISPLAY := 50

    if IsObject(AppState.FullHistoryGui) {
        try {
            if WinExist("ahk_id " AppState.FullHistoryGui.Hwnd) {
                WinActivate("ahk_id " AppState.FullHistoryGui.Hwnd)
                RefreshFullHistoryList()
                return
            }
        } catch {
            AppState.FullHistoryGui := ""
        }
    }

    ; Modern Dark Theme GUI
    myGui := Gui("+Resize +AlwaysOnTop", Lang("GUI_FULL_TITLE"))
    ThemeHelper.StyleGui(myGui)

    myGui.OnEvent(
        "Close", (*) => (
            AppState.MAX_FULL_HISTORY_DISPLAY := 50,
            myGui.Destroy(),
            AppState.FullHistoryGui := "",
            AppState.TargetWindow := 0
        )
    )

    myGui.OnEvent(
        "Escape", (*) => (
            AppState.MAX_FULL_HISTORY_DISPLAY := 50,
            myGui.Destroy(),
            AppState.FullHistoryGui := "",
            AppState.TargetWindow := 0
        )
    )

    myGui.OnEvent("Size", ResizeFullHistoryGui)

    ; Search Bar - Styled
    searchBox := myGui.Add(
        "Edit",
        "w600 " ThemeHelper.GetEditOptions()
    )
    searchBox.OnEvent(
        "Change", (*) => (
            AppState.MAX_FULL_HISTORY_DISPLAY := 50,
            RefreshFullHistoryList()
        )
    )
    myGui.SearchBox := searchBox

    ; ListView (removed conflicting -Multi from GetLVOptions, keep Multi here)
    lv := myGui.Add(
        "ListView",
        "r20 w600 Checked Multi " ThemeHelper.GetLVOptions(),
        ["#", "Content"]
    )
    lv.ModifyCol(1, "Integer")
    lv.ModifyCol(1, 60)

    lv.OnEvent("DoubleClick", OnFullHistoryDoubleClick)
    lv.OnEvent("ContextMenu", OnFullHistoryContextMenu)
    lv.OnEvent("ItemCheck", OnItemCheck)
    myGui.ListView := lv

    ; Buttons
    btnPaste := myGui.Add(
        "Button",
        "Default " ThemeHelper.GetButtonOptions(),
        Lang("GUI_FULL_PASTE_FILE")
    )
    btnPaste.OnEvent("Click", (*) => PasteSelectedFromFullHistory())
    myGui.btnPaste := btnPaste

    btnPasteText := myGui.Add(
        "Button",
        "x+10 yp " ThemeHelper.GetButtonOptions(),
        Lang("GUI_FULL_PASTE_TEXT")
    )
    btnPasteText.OnEvent("Click", (*) => PasteSelectedFromFullHistoryText())
    myGui.btnPasteText := btnPasteText

    btnClose := myGui.Add(
        "Button",
        "x+10 yp " ThemeHelper.GetButtonOptions(),
        Lang("GUI_FULL_CLOSE")
    )
    btnClose.OnEvent("Click", (*) => (
        AppState.MAX_FULL_HISTORY_DISPLAY := 50,
        myGui.Destroy(),
        AppState.FullHistoryGui := "",
        AppState.TargetWindow := 0
    ))
    myGui.btnClose := btnClose

    ; Bottom Controls
    chkSelectAll := myGui.Add(
        "CheckBox",
        "x10 y+20 " ThemeHelper.GetCheckBoxOptions(),
        Lang("GUI_FULL_SELECT_ALL")
    )
    chkSelectAll.OnEvent("Click", OnSelectAllClicked)
    myGui.chkSelectAll := chkSelectAll

    btnDelete := myGui.Add(
        "Button",
        "x+10 yp " ThemeHelper.GetButtonOptions(),
        Lang("GUI_FULL_DELETE_SELECTED")
    )
    btnDelete.OnEvent("Click", OnDeleteSelected)
    myGui.btnDeleteSelected := btnDelete

    btnLoadMore := myGui.Add(
        "Button",
        "x+10 yp " ThemeHelper.GetButtonOptions(),
        Lang("GUI_FULL_LOAD_MORE", , "Load More")
    )
    btnLoadMore.OnEvent("Click", OnLoadMoreClicked)
    myGui.btnLoadMore := btnLoadMore

    AppState.FullHistoryGui := myGui

    myGui.Show()
    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

    RefreshFullHistoryList()
}

OnLoadMoreClicked(btn, info) {
    AppState.MAX_FULL_HISTORY_DISPLAY += 50
    RefreshFullHistoryList()
}

RefreshFullHistoryList() {
    myGui := AppState.FullHistoryGui
    if !IsObject(myGui)
        return

    lv := myGui.ListView
    lv.Delete()

    filter := Trim(myGui.SearchBox.Text)
    maxDisplay := AppState.MAX_FULL_HISTORY_DISPLAY
    matching := []

    for i, item in AppState.History {
        display := StrReplace(SubStr(item["text"], 1, 80), "`n", " ")
        if StrLen(item["text"]) > 80
            display .= "..."

        if filter != "" && !InStr(display, filter) && !InStr(item["text"], filter)
            continue

        matching.Push({index: i, display: display})
    }

    totalMatching := matching.Length
    loop Min(maxDisplay, totalMatching) {
        entry := matching[A_Index]
        lv.Add(, entry.index, entry.display)
    }

    if totalMatching > maxDisplay {
        lv.Add(, "...", "... (" . (totalMatching - maxDisplay) . " more items)")
    }

    lv.ModifyCol(2, "AutoHdr")
    myGui.chkSelectAll.Value := 0
}

ResizeFullHistoryGui(guiObj, minmax, width, height) {
    if !IsObject(guiObj) || !IsObject(guiObj.ListView)
        return

    lv := guiObj.ListView
    lv.Move(10, 40, width - 20, height - 130)

    ; Reposition Top Buttons
    btnPaste := guiObj.btnPaste
    btnPasteText := guiObj.btnPasteText
    btnClose := guiObj.btnClose

    if !IsObject(btnPaste) || !IsObject(btnPasteText) || !IsObject(btnClose)
        return

    btnPaste.GetPos(, , &w1)
    btnPasteText.GetPos(, , &w2)
    btnClose.GetPos(, , &w3)
    spacing := 10
    totalBtnWidth := w1 + w2 + w3 + spacing * 2
    startX := width - totalBtnWidth - 10

    btnPaste.Move(startX, height - 90)
    btnPasteText.Move(startX + w1 + spacing, height - 90)
    btnClose.Move(startX + w1 + spacing + w2 + spacing, height - 90)

    ; Reposition Bottom Controls
    chkSelectAll := guiObj.chkSelectAll
    btnDelete := guiObj.btnDeleteSelected
    btnLoadMore := guiObj.btnLoadMore

    if !IsObject(chkSelectAll) || !IsObject(btnDelete) || !IsObject(btnLoadMore)
        return

    chkSelectAll.GetPos(, , &w4)
    btnDelete.GetPos(, , &w5)
    btnLoadMore.GetPos(, , &w6)
    totalWidth2 := w4 + w5 + w6 + spacing * 2
    startX2 := width - totalWidth2 - 10

    chkSelectAll.Move(startX2, height - 50)
    btnDelete.Move(startX2 + w4 + spacing, height - 50)
    btnLoadMore.Move(startX2 + w4 + spacing + w5 + spacing, height - 50)
}
