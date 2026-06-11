#Requires AutoHotkey v2.0

SetPasteMode1( * ) {
    global pasteMode
    pasteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Paste Mode: File" )
    SetTimer( () => ToolTip(), -2000 )
}

SetPasteMode2( * ) {
    global pasteMode
    pasteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Paste Mode: Text" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode1( * ) {
    global deleteMode
    deleteMode := 1
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Delete after delay (" deleteDelay "s)" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode2( * ) {
    global deleteMode
    deleteMode := 2
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Batch cleanup every " cleanupInterval "s" )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode3( * ) {
    global deleteMode
    deleteMode := 3
    SaveConfig()
    TrayMenuRefresh()
    ToolTip( "Mode: Never delete" )
    SetTimer( () => ToolTip(), -2000 )
}

SetMaxHistory( * ) {
    global maxHistory, clipboardHistory

    input := InputBox( "Enter max history limit (0 to disable, e.g., 500, 1000):", "Max History Limit", "w300 h120",
        maxHistory )
    if ( input.Result = "OK" && IsNumber( input.Value ) ) {
        newMax := Integer( input.Value )
        if ( newMax < 0 ) {
            newMax := 0
        }
        if ( newMax = 0 ) {
            if ( clipboardHistory.Length > 0 ) {
                confirm := MsgBox( "Setting limit to 0 will DISABLE history and remove all " clipboardHistory.Length " entries.`n`nContinue?",
                    "Disable History", "YesNo Icon?" )
                if ( confirm != "Yes" ) {
                    return
                }
            }
            maxHistory := 0
            SaveConfig()
            clipboardHistory := []
            SaveHistory()
            ToolTip( "Clipboard history disabled, all entries removed" )
            SetTimer( () => ToolTip(), -3000 )
        } else {
            pendingRemoval := clipboardHistory.Length - newMax
            if ( pendingRemoval > 0 ) {
                confirm := MsgBox( "Current history has " clipboardHistory.Length " entries.`n"
                    "Setting limit to " newMax " will remove " pendingRemoval " oldest entries.`n`nContinue?",
                    "Confirm Max History Change", "YesNo Icon?" )
                if ( confirm != "Yes" ) {
                    return
                }
            }
            maxHistory := newMax
            SaveConfig()
            if ( pendingRemoval > 0 ) {
                removedCount := clipboardHistory.Length - maxHistory
                while ( clipboardHistory.Length > maxHistory ) {
                    clipboardHistory.Pop()
                }
                SaveHistory()
                ToolTip( "Max history set to " maxHistory " — removed " removedCount " old entries" )
            } else {
                ToolTip( "Max history limit set to " maxHistory )
            }
            SetTimer( () => ToolTip(), -3000 )
        }
    }
}

SetDeleteDelay( * ) {
    global deleteDelay

    input := InputBox( "Enter delete delay in seconds:", "Delete Delay", "w300 h120", deleteDelay )
    if ( input.Result = "OK" && IsNumber( input.Value ) && input.Value > 0 ) {
        deleteDelay := Integer( input.Value )
        SaveConfig()
        ToolTip( "Delete delay set to " deleteDelay "s" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetCleanupInterval( * ) {
    global cleanupInterval, batchCleanupTimer

    input := InputBox( "Enter cleanup interval in seconds:", "Cleanup Interval", "w300 h120", cleanupInterval )
    if ( input.Result = "OK" && IsNumber( input.Value ) && input.Value > 0 ) {
        cleanupInterval := Integer( input.Value )
        SaveConfig()
        if ( batchCleanupTimer != "" ) {
            SetTimer( batchCleanupTimer, cleanupInterval * 1000 )
        }
        ToolTip( "Cleanup interval set to " cleanupInterval "s" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetImPath( * ) {
    global imageMagickExe, configFile

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
        IniWrite( SelectedFile, configFile, "ImageMagick", "Path" )
    } catch as err {
        MsgBox( "Failed to save path: " err.Message, "Error", "Iconx" )
        return
    }
    imageMagickExe := SelectedFile
    RefreshImStatus()
    MsgBox( "ImageMagick path set successfully!`n" SelectedFile, "Success", "Iconi T2" )
}
