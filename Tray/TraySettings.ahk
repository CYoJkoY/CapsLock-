#Requires AutoHotkey v2.0

SetPasteMode1( * ) {
    global PasteMode
    PasteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Paste Mode: File" )
    SetTimer( () => ToolTip(), -2000 )
}

SetPasteMode2( * ) {
    global PasteMode
    PasteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Paste Mode: Text" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode1( * ) {
    global DeleteMode
    DeleteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Delete after delay (" DeleteDelay "s)" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode2( * ) {
    global DeleteMode
    DeleteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Batch cleanup every " CleanupInterval "s" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode3( * ) {
    global DeleteMode
    DeleteMode := 3
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Never delete" )
    SetTimer( () => ToolTip(), -2000 )
}

SetMaxHistory( * ) {
    global MaxHistory, ClipboardHistory

    input := InputBox( "Enter max history limit (0 to disable, e.g., 500, 1000):", "Max History Limit", "w300 h120",
        MaxHistory )
    if ( input.Result = "OK" && IsNumber( input.Value ) ) {
        newMax := Integer( input.Value )
        if ( newMax < 0 ) {
            newMax := 0
        }
        if ( newMax = 0 ) {
            if ( ClipboardHistory.Length > 0 ) {
                confirm := MsgBox( "Setting limit to 0 will DISABLE history and remove all " ClipboardHistory.Length " entries.`n`nContinue?",
                    "Disable History", "YesNo Icon?" )
                if ( confirm != "Yes" ) {
                    return
                }
            }
            MaxHistory := 0
            SaveConfig()
            ClipboardHistory := []
            SaveHistory()
            ToolTip( "Clipboard history disabled, all entries removed" )
            SetTimer( () => ToolTip(), -3000 )
        } else {
            pendingRemoval := ClipboardHistory.Length - newMax
            if ( pendingRemoval > 0 ) {
                confirm := MsgBox( "Current history has " ClipboardHistory.Length " entries.`n"
                    "Setting limit to " newMax " will remove " pendingRemoval " oldest entries.`n`nContinue?",
                    "Confirm Max History Change", "YesNo Icon?" )
                if ( confirm != "Yes" ) {
                    return
                }
            }
            MaxHistory := newMax
            SaveConfig()
            if ( pendingRemoval > 0 ) {
                removedCount := ClipboardHistory.Length - MaxHistory
                while ( ClipboardHistory.Length > MaxHistory ) {
                    ClipboardHistory.Pop()
                }
                SaveHistory()
                ToolTip( "Max history set to " MaxHistory " — removed " removedCount " old entries" )
            } else {
                ToolTip( "Max history limit set to " MaxHistory )
            }
            SetTimer( () => ToolTip(), -3000 )
        }
    }
}

SetDeleteDelay( * ) {
    global DeleteDelay

    input := InputBox( "Enter delete delay in seconds:", "Delete Delay", "w300 h120", DeleteDelay )
    if ( input.Result = "OK" && IsNumber( input.Value ) && input.Value > 0 ) {
        DeleteDelay := Integer( input.Value )
        SaveConfig()
        ToolTip( "Delete delay set to " DeleteDelay "s" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetCleanupInterval( * ) {
    global CleanupInterval, BatchCleanupTimer

    input := InputBox( "Enter cleanup interval in seconds:", "Cleanup Interval", "w300 h120", CleanupInterval )
    if ( input.Result = "OK" && IsNumber( input.Value ) && input.Value > 0 ) {
        CleanupInterval := Integer( input.Value )
        SaveConfig()
        if ( BatchCleanupTimer != "" ) {
            SetTimer( BatchCleanupTimer, CleanupInterval * 1000 )
        }
        ToolTip( "Cleanup interval set to " CleanupInterval "s" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetImPath( * ) {
    global ImageMagickExe, ConfigFile

    SelectedFile := Trim( FileSelect( 1, A_ProgramFiles, "Select ImageMagick's magick.exe", "Executable (*.exe)" ) )
    if ( SelectedFile = "" ) {
        return
    }
    if !InStr( StrLower( SelectedFile ), "magick.exe" ) {
        MsgBox( "Please select the correct file: magick.exe", "Error", "Iconx" )
        return
    }
    if !FileExist( SelectedFile ) {
        MsgBox( "Selected file does not exist!`nPath: " SelectedFile, "Error", "Iconx" )
        return
    }
    try {
        IniWrite( SelectedFile, ConfigFile, "ImageMagick", "Path" )
    } catch as err {
        MsgBox( "Failed to save path: " err.Message, "Error", "Iconx" )
        return
    }
    ImageMagickExe := SelectedFile
    RefreshImStatus()
    MsgBox( "ImageMagick path set successfully!`n" SelectedFile, "Success", "Iconi T2" )
}
