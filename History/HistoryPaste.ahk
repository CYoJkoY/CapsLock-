#Requires AutoHotkey v2.0

PasteAsFile( historyItem ) {
    global lastManualClipboard, pasteMode, targetWindow

    local textContent := historyItem[ "text" ]

    if ( pasteMode = 2 && TryHistoryPasteAsText( textContent ) ) {
        return
    }

    if ( pasteMode = 1 && TryHistoryPasteFoldersAsMergedFile( textContent, historyItem ) ) {
        return
    }

    if ( IsImagePathsText( textContent ) ) {
        PasteHistoryImagesAsPdf( textContent )
        return
    }

    if ( IsFilePath( textContent ) && FileExist( textContent ) ) {
        PasteHistorySingleFile( textContent, historyItem )
    } else {
        PasteHistoryPlainText( textContent, historyItem )
    }

    ActivateAndPaste( targetWindow )
}

TryHistoryPasteAsText( textContent ) {
    if ( IsMultiFolderPathText( textContent ) ) {
        local folders := GetValidPathsFromText( textContent, "IsFolderPath" )
        if ( folders.Length > 0 ) {
            local combined := ReadMultipleFoldersAsText( folders )
            PastePlainTextWithBackup( combined, folders.Length " folders as text" )
            return true
        }
    }
    if ( IsMultiFilePathText( textContent ) ) {
        local files := GetValidPathsFromText( textContent, "IsFilePathExists" )
        if ( files.Length > 0 ) {
            local combined := ReadMultipleFilesAsText( files )
            PastePlainTextWithBackup( combined, files.Length " files as text" )
            return true
        }
    }
    return false
}

TryHistoryPasteFoldersAsMergedFile( textContent, historyItem ) {
    if ( IsMultiFolderPathText( textContent ) ) {
        local folders := GetValidPathsFromText( textContent, "IsFolderPath" )
        if ( folders.Length > 0 ) {
            local sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
            local mergedText := ReadMultipleFoldersAsText( folders )
            local fullContent := "; " sourceInfo "`n`n" mergedText
            local tempFile := A_Temp "\ClipTemp_Combine_" A_TickCount ".txt"
            FileAppend( fullContent, tempFile, "UTF-8" )
            SetClipboardFile( tempFile )
            ActivateAndPaste( targetWindow )
            ScheduleFileDeletion( tempFile )
            SetTimer( () => ( lastManualClipboard != "" ) ? ( A_Clipboard := lastManualClipboard ) : "", -10000 )
            ShowToolTip( "Pasted combined folder content", 2000 )
            return true
        }
    }
    return false
}

PasteHistoryImagesAsPdf( textContent ) {
    local originalClip := A_Clipboard
    A_Clipboard := textContent
    local pdfPath := ProcessImagePathsToPDF()
    A_Clipboard := originalClip
    if ( pdfPath = "" ) {
        ShowToolTip( "Failed to create PDF from image paths.", 2000 )
        return
    }
    PasteFile( pdfPath, "pdf" )
}

PasteHistorySingleFile( filePath, historyItem ) {
    local fileType := GetFileType( filePath )
    if ( fileType = "pdf" ) {
        DllCall( "OpenClipboard", "Ptr", A_ScriptHwnd ) && DllCall( "EmptyClipboard" )
        DllCall( "CloseClipboard" )
        SetClipboardFile( filePath )
    } else {
        local sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
        local fullContent := "; " sourceInfo "`n`n" FileRead( filePath, "UTF-8" )
        local tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend( fullContent, tempFile, "UTF-8" )
        SetClipboardFile( tempFile )
    }
}

PasteHistoryPlainText( textContent, historyItem ) {
    local sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    DllCall( "OpenClipboard", "Ptr", A_ScriptHwnd ) && DllCall( "EmptyClipboard" )
    DllCall( "CloseClipboard" )
    local fullContent := "; " sourceInfo "`n`n" textContent
    local tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    SetClipboardFile( tempFile )
}

ActivateAndPaste( targetWin ) {
    if ( targetWin && WinExist( "ahk_id " targetWin ) ) {
        WinActivate( "ahk_id " targetWin )
    } else {
        if !WinExist( "A" ) {
            ShowToolTip( "No target window to paste into.", 2000 )
            return
        }
        WinActivate( "A" )
    }
    Sleep( 100 )
    Send( "^v" )
}

PasteAsMultipleFiles( textArray ) {
    global targetWindow

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
    ActivateAndPaste( targetWindow )
    for f in tempFiles {
        ScheduleFileDeletion( f )
    }
}

PasteSingleFile( textContent, activate := true ) {
    global clipboardHistory, targetWindow

    if ( Type( textContent ) = "Map" ) {
        textToPaste := textContent.Has( "text" ) ? textContent[ "text" ] : ""
        sourceInfo := "Copied from: " ( textContent.Has( "source" ) ? textContent[ "source" ] : "Unknown Source" )
        . " (at " ( textContent.Has( "time" ) ? textContent[ "time" ] : FormatTime(, "yyyy-MM-dd HH:mm:ss" ) ) . ")"
    } else {
        textToPaste := textContent
        sourceInfo := ""
        for item in clipboardHistory {
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
        originalClip := A_Clipboard
        A_Clipboard := textToPaste
        pdfPath := ProcessImagePathsToPDF()
        A_Clipboard := originalClip
        if ( pdfPath = "" ) {
            ShowToolTip( "Failed to create PDF from image paths.", 2000 )
            return
        }
        PasteFile( pdfPath, "pdf" )
        return
    }

    fullContent := "; " sourceInfo "`n`n" textToPaste
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    SetClipboardFile( tempFile )

    if ( activate ) {
        if !WinExist( "ahk_id " targetWindow ) {
            ShowToolTip( "Target window not found, paste cancelled.", 1500 )
            return
        }
        state := WinGetMinMax( "ahk_id " targetWindow )
        if ( state = -1 ) {
            WinRestore( "ahk_id " targetWindow )
        }
        WinActivate( "ahk_id " targetWindow )
        if !WinWaitActive( "ahk_id " targetWindow, , 1 ) {
            ShowToolTip( "Cannot activate target window, please try manually.", 2000 )
            return
        }
    }

    ShowToolTip( "Pasting: " SubStr( textToPaste, 1, 40 ) "...", 10000 )
    Send( "^v" )
    Sleep( 50 )
    ScheduleFileDeletion( tempFile )
    SetTimer( () => ToolTip(), -10000 )
}
