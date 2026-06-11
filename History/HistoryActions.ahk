#Requires AutoHotkey v2.0

PasteAsFile( history_item ) {
    global LastManualClipboard, PasteMode, TargetWindow

    local text_content := history_item[ "text" ]

    if ( PasteMode = 2 && IsMultiFilePathText( text_content ) ) {
        local raw_paths := StrSplit( text_content, "`n", "`r" )
        local valid_paths := []
        for path in raw_paths {
            path := Trim( path )
            local attrs := FileExist( path )
            if ( path != "" && attrs != "" && !InStr( attrs, "D" ) ) {
                valid_paths.Push( path )
            }
        }
        if ( valid_paths.Length > 0 ) {
            local combined_text := ReadMultipleFilesAsText( valid_paths )
            local backup_clip := A_Clipboard
            A_Clipboard := combined_text
            Send( "^v" )
            Sleep( 50 )
            A_Clipboard := backup_clip
            ToolTip( "Pasted " valid_paths.Length " history files as text" )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
    }

    if ( IsImagePathsText( text_content ) ) {
        local original_clipboard := A_Clipboard
        A_Clipboard := text_content
        local temp_pdf_path := ProcessImagePathsToPDF()
        A_Clipboard := original_clipboard
        if ( temp_pdf_path = "" ) {
            ToolTip( "Failed to create PDF from image paths." )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
        PasteFile( temp_pdf_path, "pdf" )
        return
    }

    if ( IsFilePath( text_content ) && FileExist( text_content ) ) {
        local file_path := text_content
        local file_type := GetFileType( file_path )
        if ( file_type = "pdf" ) {
            DllCall( "OpenClipboard", "Ptr", A_ScriptHwnd ) && DllCall( "EmptyClipboard" )
            DllCall( "CloseClipboard" )
            SetClipboardFile( file_path )
        } else {
            local source_info := "Copied from: " history_item[ "source" ] " (at " history_item[ "time" ] ")"
            local full_content := "; " source_info "`n`n" FileRead( file_path, "UTF-8" )
            local temp_file := A_Temp "\ClipTemp_" A_TickCount ".txt"
            FileAppend( full_content, temp_file, "UTF-8" )
            SetClipboardFile( temp_file )
        }
    } else {
        local source_info := "Copied from: " history_item[ "source" ] " (at " history_item[ "time" ] ")"
        DllCall( "OpenClipboard", "Ptr", A_ScriptHwnd ) && DllCall( "EmptyClipboard" )
        DllCall( "CloseClipboard" )
        local full_content := "; " source_info "`n`n" text_content
        local temp_file := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend( full_content, temp_file, "UTF-8" )
        SetClipboardFile( temp_file )
    }

    if ( TargetWindow && WinExist( "ahk_id " TargetWindow ) ) {
        WinActivate( "ahk_id " TargetWindow )
    } else {
        if !WinExist( "A" ) {
            ToolTip( "No target window to paste into." )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
        WinActivate( "A" )
    }

    Sleep( 100 )
    Send( "^v" )

    if ( IsSet( temp_file ) && InStr( temp_file, A_Temp "\ClipTemp_" ) ) {
        ScheduleFileDeletion( temp_file )
    }
    if ( IsSet( file_path ) && IsSet( file_type ) && file_type = "pdf" ) {
        ScheduleFileDeletion( file_path )
    }

    SetTimer( () => ( LastManualClipboard != "" ) ? ( A_Clipboard := LastManualClipboard ) : "", -10000 )
}

DeleteHistoryItem( * ) {
    global ClipboardHistory, SelectedIndex

    if ( SelectedIndex <= ClipboardHistory.Length ) {
        ClipboardHistory.RemoveAt( SelectedIndex )
        SaveHistory()
        ToolTip( "Deleted" )
        SetTimer( () => ToolTip(), -1000 )
    }
}

_PasteAsMultipleFiles( textArray ) {
    global TargetWindow

    tempFiles := []
    for item in textArray {
        if ( Type( item ) = "Map" ) {
            textToWrite := item.Has( "text" ) ? item[ "text" ] : ""
            sourceInfo := "Copied from: " ( item.Has( "source" ) ? item[ "source" ] : "Unknown Source" )
            . " (at " ( item.Has( "time" ) ? item[ "time" ] : FormatTime(, "yyyy-MM-dd HH:mm:ss" ) ) . ")"
        } else {
            textToWrite := item
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        }
        fullContent := "; " sourceInfo "`n`n" textToWrite
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"
        FileAppend( fullContent, tempFile, "UTF-8" )
        tempFiles.Push( tempFile )
    }

    SetClipboardFiles( tempFiles )

    if ( TargetWindow && WinExist( "ahk_id " TargetWindow ) ) {
        WinActivate( "ahk_id " TargetWindow )
    } else {
        if !WinExist( "A" ) {
            ToolTip( "No target window to paste into." )
            SetTimer( () => ToolTip(), -1500 )
            return
        }
        WinActivate( "A" )
    }

    Sleep( 100 )
    Send( "^v" )
    for f in tempFiles {
        ScheduleFileDeletion( f )
    }
}

_PasteSingleFile( textContent, activate := true ) {
    global TargetWindow, ClipboardHistory

    if ( Type( textContent ) = "Map" ) {
        textToPaste := textContent.Has( "text" ) ? textContent[ "text" ] : ""
        sourceInfo := "Copied from: " ( textContent.Has( "source" ) ? textContent[ "source" ] : "Unknown Source" )
        . " (at " ( textContent.Has( "time" ) ? textContent[ "time" ] : FormatTime(, "yyyy-MM-dd HH:mm:ss" ) ) . ")"
    } else {
        textToPaste := textContent
        sourceInfo := ""
        for item in ClipboardHistory {
            if ( item[ "text" ] = textContent ) {
                sourceInfo := "Copied from: " item[ "source" ] " (at " item[ "time" ] ")"
                break
            }
        }
        if ( sourceInfo = "" ) {
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        }
    }

    if ( IsImagePathsText( textToPaste ) ) {
        originalClipboard := A_Clipboard
        A_Clipboard := textToPaste
        tempPDFPath := ProcessImagePathsToPDF()
        A_Clipboard := originalClipboard
        if ( tempPDFPath = "" ) {
            ToolTip( "Failed to create PDF from image paths in Full History." )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
        PasteFile( tempPDFPath, "pdf" )
        return
    }

    fullContent := "; " sourceInfo "`n`n" textToPaste
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    SetClipboardFile( tempFile )

    if ( activate ) {
        if !WinExist( "ahk_id " TargetWindow ) {
            ToolTip( "Target window not found, paste cancelled." )
            SetTimer( () => ToolTip(), -1500 )
            return
        }
        state := WinGetMinMax( "ahk_id " TargetWindow )
        if ( state = -1 ) {
            WinRestore( "ahk_id " TargetWindow )
        }
        WinActivate( "ahk_id " TargetWindow )
        if !WinWaitActive( "ahk_id " TargetWindow, , 1 ) {
            ToolTip( "Cannot activate target window, please try manually." )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
    }

    ToolTip( "Pasting: " SubStr( textToPaste, 1, 40 ) "..." )
    Send( "^v" )
    Sleep( 50 )
    ScheduleFileDeletion( tempFile )
    SetTimer( () => ToolTip(), -10000 )
}
