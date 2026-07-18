#Requires AutoHotkey v2.0

ShowFullHistoryGui( ItemName?, ItemPos?, MyMenu? ) {
    AppState.TargetWindow := WinExist( "A" )
    AppState.MAX_FULL_HISTORY_DISPLAY := 50

    if IsObject( AppState.FullHistoryGui ) {
        try {
            if WinExist( "ahk_id " AppState.FullHistoryGui.Hwnd ) {
                WinActivate( "ahk_id " AppState.FullHistoryGui.Hwnd )
                RefreshFullHistoryList()
                return
            }
        } catch {
            AppState.FullHistoryGui := ""
        }
    }

    myGui := Gui( "+Resize +AlwaysOnTop", Lang( "GUI_FULL_TITLE" ) )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myGui.OnEvent( "Close", ( * ) => (
        AppState.MAX_FULL_HISTORY_DISPLAY := 50,
        myGui.Destroy(),
        AppState.FullHistoryGui := "",
        AppState.TargetWindow := 0
    ) )
    myGui.OnEvent( "Escape", ( * ) => (
        AppState.MAX_FULL_HISTORY_DISPLAY := 50,
        myGui.Destroy(),
        AppState.FullHistoryGui := "",
        AppState.TargetWindow := 0
    ) )
    myGui.OnEvent( "Size", ResizeFullHistoryGui )

    searchBox := myGui.Add( "Edit", "w600", "" )
    searchBox.OnEvent( "Change", ( * ) => (
        AppState.MAX_FULL_HISTORY_DISPLAY := 50,
        RefreshFullHistoryList()
    ) )
    myGui.SearchBox := searchBox

    lv := myGui.Add( "ListView", "r20 w600 Checked Multi Grid", [ "#", "Content (first 100 chars)" ] )
    lv.OnEvent( "DoubleClick", OnFullHistoryDoubleClick )
    lv.OnEvent( "ContextMenu", OnFullHistoryContextMenu )
    lv.OnEvent( "ItemCheck", OnItemCheck )
    myGui.ListView := lv

    btnPaste := myGui.Add( "Button", "Default", Lang( "GUI_FULL_PASTE_FILE" ) )
    btnPaste.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistory() )
    myGui.btnPaste := btnPaste

    btnPasteText := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_PASTE_TEXT" ) )
    btnPasteText.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistoryText() )
    myGui.btnPasteText := btnPasteText

    btnClose := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_CLOSE" ) )
    btnClose.OnEvent( "Click", ( * ) => myGui.Destroy() )
    myGui.btnClose := btnClose

    chkSelectAll := myGui.Add( "CheckBox", "x10 y+20", Lang( "GUI_FULL_SELECT_ALL" ) )
    chkSelectAll.OnEvent( "Click", OnSelectAllClicked )
    myGui.chkSelectAll := chkSelectAll

    btnDelete := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_DELETE_SELECTED" ) )
    btnDelete.OnEvent( "Click", OnDeleteSelected )
    myGui.btnDeleteSelected := btnDelete

    btnLoadMore := myGui.Add( "Button", "x+10 yp", Lang( "GUI_FULL_LOAD_MORE", , "Load More" ) )
    btnLoadMore.OnEvent( "Click", OnLoadMoreClicked )
    myGui.btnLoadMore := btnLoadMore

    AppState.FullHistoryGui := myGui
    RefreshFullHistoryList()
    myGui.Show()
}

OnLoadMoreClicked( btn, info ) {
    AppState.MAX_FULL_HISTORY_DISPLAY += 50
    RefreshFullHistoryList()
}

RefreshFullHistoryList() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    lv.Delete()
    if ( lv.GetCount( "Col" ) < 2 )
        lv.InsertCol( 1, , "Integer" )
    lv.ModifyCol( 1, 50 )

    filter := Trim( myGui.SearchBox.Text )
    maxDisplay := AppState.MAX_FULL_HISTORY_DISPLAY

    matching := []
    for i, item in AppState.History {
        display := StrReplace( SubStr( item[ "text" ], 1, 100 ), "`n", " " )
        if StrLen( item[ "text" ] ) > 100
            display .= "..."

        if filter != "" && !InStr( display, filter ) && !InStr( item[ "text" ], filter )
            continue

        matching.Push( { index: i, display: display } )
    }

    totalMatching := matching.Length
    loop Min( maxDisplay, totalMatching ) {
        entry := matching[ A_Index ]
        lv.Add(, entry.index, entry.display )
    }

    if totalMatching > maxDisplay {
        lv.Add(, "...", "... (" . ( totalMatching - maxDisplay ) . " more items)" )
    }

    lv.ModifyCol( 2, "AutoHdr" )
    myGui.chkSelectAll.Value := 0
}

ResizeFullHistoryGui( guiObj, minmax, width, height ) {
    lv := guiObj.ListView
    lv.Move( 10, 40, width - 20, height - 130 )

    btnPaste := guiObj.btnPaste
    btnPasteText := guiObj.btnPasteText
    btnClose := guiObj.btnClose
    btnPaste.GetPos(, , &w1 )
    btnPasteText.GetPos(, , &w2 )
    btnClose.GetPos(, , &w3 )
    spacing := 10
    totalBtnWidth := w1 + w2 + w3 + spacing * 2
    startX := width - totalBtnWidth - 10
    btnPaste.Move( startX, height - 90 )
    btnPasteText.Move( startX + w1 + spacing, height - 90 )
    btnClose.Move( startX + w1 + spacing + w2 + spacing, height - 90 )

    chkSelectAll := guiObj.chkSelectAll
    btnDelete := guiObj.btnDeleteSelected
    btnLoadMore := guiObj.btnLoadMore
    chkSelectAll.GetPos(, , &w4 )
    btnDelete.GetPos(, , &w5 )
    btnLoadMore.GetPos(, , &w6 )

    totalWidth2 := w4 + w5 + w6 + spacing * 2
    startX2 := width - totalWidth2 - 10
    chkSelectAll.Move( startX2, height - 50 )
    btnDelete.Move( startX2 + w4 + spacing, height - 50 )
    btnLoadMore.Move( startX2 + w4 + spacing + w5 + spacing, height - 50 )
}
