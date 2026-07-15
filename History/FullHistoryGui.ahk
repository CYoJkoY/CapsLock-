#Requires AutoHotkey v2.0

ShowFullHistoryGui( ItemName?, ItemPos?, MyMenu? ) {
    AppState.TargetWindow := WinExist( "A" )
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

    myGui := Gui( "+Resize +AlwaysOnTop", "Clipboard History (Full)" )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myGui.OnEvent( "Close", ( * ) => ( myGui.Destroy(), AppState.FullHistoryGui := "" ) )
    myGui.OnEvent( "Escape", ( * ) => ( myGui.Destroy(), AppState.FullHistoryGui := "" ) )
    myGui.OnEvent( "Size", ResizeFullHistoryGui )

    searchBox := myGui.Add( "Edit", "w600", "" )
    searchBox.OnEvent( "Change", ( * ) => RefreshFullHistoryList() )
    myGui.SearchBox := searchBox

    lv := myGui.Add( "ListView", "r20 w600 Checked Multi Grid", [ "#", "Content (first 100 chars)" ] )
    lv.OnEvent( "DoubleClick", OnFullHistoryDoubleClick )
    lv.OnEvent( "ContextMenu", OnFullHistoryContextMenu )
    lv.OnEvent( "ItemCheck", OnItemCheck )
    myGui.ListView := lv

    btnPaste := myGui.Add( "Button", "Default", "Paste as File" )
    btnPaste.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistory() )
    myGui.btnPaste := btnPaste

    btnPasteText := myGui.Add( "Button", "x+10 yp", "Paste as Text" )
    btnPasteText.OnEvent( "Click", ( * ) => PasteSelectedFromFullHistoryText() )
    myGui.btnPasteText := btnPasteText

    btnClose := myGui.Add( "Button", "x+10 yp", "Close" )
    btnClose.OnEvent( "Click", ( * ) => myGui.Destroy() )
    myGui.btnClose := btnClose

    chkSelectAll := myGui.Add( "CheckBox", "x10 y+20", "Select All" )
    chkSelectAll.OnEvent( "Click", OnSelectAllClicked )
    myGui.chkSelectAll := chkSelectAll

    btnDelete := myGui.Add( "Button", "x+10 yp", "Delete Selected" )
    btnDelete.OnEvent( "Click", OnDeleteSelected )
    myGui.btnDeleteSelected := btnDelete

    AppState.FullHistoryGui := myGui
    RefreshFullHistoryList()
    myGui.Show()
}

RefreshFullHistoryList() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    lv.Delete()
    filter := myGui.SearchBox.Text
    filter := Trim( filter )
    idx := 0
    for i, item in AppState.History {
        content := item[ "text" ]
        display := StrReplace( SubStr( content, 1, 100 ), "`n", " " )
        if StrLen( content ) > 100
            display .= "..."
        if filter != "" && !InStr( display, filter ) && !InStr( content, filter )
            continue
        idx++
        lv.Add(, idx, display )
    }
    lv.ModifyCol( 1, "AutoHdr" )
    lv.ModifyCol( 2, "AutoHdr" )
    myGui.chkSelectAll.Value := 0
}

ResizeFullHistoryGui( guiObj, minmax, width, height ) {
    lv := guiObj.ListView
    lv.Move( 10, 40, width - 20, height - 140 )

    guiObj.btnPaste.Move( 10, height - 80 )
    guiObj.btnPasteText.Move( 120, height - 80 )
    guiObj.btnClose.Move( 230, height - 80 )

    guiObj.chkSelectAll.Move( 10, height - 40 )
    guiObj.btnDeleteSelected.Move( 120, height - 40 )
}
