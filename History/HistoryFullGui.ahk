#Requires AutoHotkey v2.0

ShowFullHistoryGui( ItemName?, ItemPos?, MyMenu? ) {
    global ClipboardHistory, FullHistoryGui, TargetWindow

    TargetWindow := WinExist( "A" )

    if ( FullHistoryGui ) {
        try {
            if WinExist( "ahk_id " FullHistoryGui.Hwnd ) {
                WinActivate( "ahk_id " FullHistoryGui.Hwnd )
                _RefreshFullHistoryList()
                return
            }
        } catch {
            FullHistoryGui := ""
        }
    }

    FullHistoryGui := Gui( "+Resize +AlwaysOnTop", "Clipboard History (Full)" )
    FullHistoryGui.SetFont( "s10", "Microsoft YaHei" )
    FullHistoryGui.OnEvent( "Close", ( * ) => ( FullHistoryGui.Destroy(), FullHistoryGui := "" ) )
    FullHistoryGui.OnEvent( "Escape", ( * ) => ( FullHistoryGui.Destroy(), FullHistoryGui := "" ) )
    FullHistoryGui.OnEvent( "Size", _ResizeFullHistoryGui )

    lv := FullHistoryGui.Add( "ListView", "r20 w600 Checked Multi Grid", [
        "#",
        "Content (first 100 chars)"
    ] )
    lv.OnEvent( "DoubleClick", _OnFullHistoryDoubleClick )
    lv.OnEvent( "ContextMenu", _OnFullHistoryContextMenu )
    lv.OnEvent( "ItemCheck", _OnItemCheck )
    FullHistoryGui.ListView := lv

    btnPaste := FullHistoryGui.Add( "Button", "Default", "Paste as File" )
    btnPaste.OnEvent( "Click", ( * ) => _PasteSelectedFromFullHistory() )
    FullHistoryGui.btnPaste := btnPaste

    btnClose := FullHistoryGui.Add( "Button", "x+10 yp", "Close" )
    btnClose.OnEvent( "Click", ( * ) => FullHistoryGui.Destroy() )
    FullHistoryGui.btnClose := btnClose

    chkSelectAll := FullHistoryGui.Add( "CheckBox", "x10 y+20", "Select All" )
    chkSelectAll.OnEvent( "Click", _OnSelectAllClicked )
    FullHistoryGui.chkSelectAll := chkSelectAll

    btnDeleteSelected := FullHistoryGui.Add( "Button", "x+10 yp", "Delete Selected" )
    btnDeleteSelected.OnEvent( "Click", _OnDeleteSelected )
    FullHistoryGui.btnDeleteSelected := btnDeleteSelected

    _RefreshFullHistoryList()
    FullHistoryGui.Show()
}

_RefreshFullHistoryList() {
    global ClipboardHistory, FullHistoryGui

    lv := FullHistoryGui.ListView
    lv.Delete()

    for idx, item in ClipboardHistory {
        try {
            if ( Type( item ) = "Map" && item.Has( "text" ) ) {
                content := item[ "text" ]
            } else {
                content := String( item ?? "" )
            }
        } catch {
            content := "[Invalid History Entry]"
        }
        display := StrReplace( SubStr( content, 1, 100 ), "`n", " " )
        if ( StrLen( content ) > 100 ) {
            display .= "..."
        }
        lv.Add(, idx, display )
    }

    lv.ModifyCol( 1, "AutoHdr" )
    lv.ModifyCol( 2, "AutoHdr" )
    FullHistoryGui.chkSelectAll.Value := 0
}

_ResizeFullHistoryGui( guiObj, windowMinMax, width, height ) {
    lv := guiObj.ListView
    lv.Move( 10, 10, width - 20, height - 100 )

    guiObj.btnPaste.Move( 10, height - 80 )
    guiObj.btnClose.Move( 120, height - 80 )
    guiObj.chkSelectAll.Move( 10, height - 40 )
    guiObj.btnDeleteSelected.Move( 120, height - 40 )
}

_OnFullHistoryDoubleClick( lv, row ) {
    if ( row = 0 ) {
        return
    }
    selectedHistory := ClipboardHistory[ row ]
    _PasteAsMultipleFiles( [
        selectedHistory
    ] )
}

_OnFullHistoryContextMenu( lv, row, isRightClick, x, y ) {
    if ( row = 0 ) {
        return
    }
    selectedHistory := ClipboardHistory[ row ]
    ContextMenu := Menu()
    ContextMenu.Add( "📄 Paste as File", ( * ) => _PasteAsMultipleFiles( [
        selectedHistory
    ] ) )
    ContextMenu.Add( "🔍 Preview", ( * ) => ShowPreviewGui( selectedHistory[ "text" ] ) )
    ContextMenu.Add( "❌ Delete", ( * ) => _DeleteFromFullHistory( row ) )
    ContextMenu.Show( x, y )
}

_PasteSelectedFromFullHistory() {
    global FullHistoryGui, ClipboardHistory, TargetWindow

    lv := FullHistoryGui.ListView
    fileList := []
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        fileList.Push( ClipboardHistory[ row ] )
    }

    if ( fileList.Length = 0 ) {
        ToolTip( "Please select at least one item" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }

    if !WinExist( "ahk_id " TargetWindow ) {
        currentWin := WinExist( "A" )
        if ( currentWin && currentWin != FullHistoryGui.Hwnd ) {
            TargetWindow := currentWin
        } else {
            ToolTip( "Target window closed.`nSwitch to desired window within 2 seconds..." )
            SetTimer( () => ToolTip(), -2500 )
            loop 20 {
                Sleep( 100 )
                currentWin := WinExist( "A" )
                if ( currentWin && currentWin != FullHistoryGui.Hwnd ) {
                    TargetWindow := currentWin
                    break
                }
            }
            if !TargetWindow {
                ToolTip( "No new window detected, operation cancelled" )
                SetTimer( () => ToolTip(), -2000 )
                return
            }
        }
    }

    state := WinGetMinMax( "ahk_id " TargetWindow )
    if ( state = -1 ) {
        WinRestore( "ahk_id " TargetWindow )
    }
    WinActivate( "ahk_id " TargetWindow )
    if !WinWaitActive( "ahk_id " TargetWindow, , 1 ) {
        ToolTip( "Cannot activate target window, please click it manually" )
        SetTimer( () => ToolTip(), -2000 )
        return
    }
    Sleep( 100 )

    for item in fileList {
        _PasteSingleFile( item[ "text" ], false )
        Sleep( 200 )
    }
    ToolTip( "Paste completed" )
    SetTimer( () => ToolTip(), -1500 )
}

_OnSelectAllClicked( chk, info ) {
    lv := chk.Gui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        checked++
    }
    if ( checked = total ) {
        loop total {
            lv.Modify( A_Index, "-Check" )
        }
        chk.Value := 0
    } else {
        loop total {
            lv.Modify( A_Index, "Check" )
        }
        chk.Value := 1
    }
}

_OnDeleteSelected( * ) {
    global ClipboardHistory, FullHistoryGui

    lv := FullHistoryGui.ListView
    rowsToDelete := []
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        rowsToDelete.Push( row )
    }
    if ( rowsToDelete.Length = 0 ) {
        ToolTip( "No checked items" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    loop rowsToDelete.Length {
        idx := rowsToDelete[ rowsToDelete.Length - A_Index + 1 ]
        ClipboardHistory.RemoveAt( idx )
    }
    SaveHistory()
    _RefreshFullHistoryList()
}

_DeleteFromFullHistory( index ) {
    global ClipboardHistory, FullHistoryGui

    if ( index <= ClipboardHistory.Length ) {
        ClipboardHistory.RemoveAt( index )
        SaveHistory()
        _RefreshFullHistoryList()
    }
}

_UpdateSelectAllCheckbox() {
    global FullHistoryGui

    lv := FullHistoryGui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        checked++
    }
    FullHistoryGui.chkSelectAll.Value := ( checked = total ) ? 1 : 0
}

_OnItemCheck( lv, row, checked ) {
    _UpdateSelectAllCheckbox()
}
