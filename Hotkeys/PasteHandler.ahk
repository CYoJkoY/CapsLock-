#Requires AutoHotkey v2.0

PasteWithCurrentMode() {
    local targetText := GetTargetText()
    if ( targetText = "" ) {
        ShowToolTip( "Clipboard is empty, please copy content first", 2000 )
        return
    }

    if ( pasteMode = 2 && TryPasteFolderOrFileAsText( targetText ) ) {
        return
    }

    if ( IsImagePathsText( targetText ) ) {
        PasteImagesAsPdf( targetText )
        return
    }

    PasteWithSourceInfo( targetText )
}

GetTargetText() {
    global lastManualClipboard
    local currentClip := A_Clipboard
    local target := ( lastManualClipboard != "" ) ? lastManualClipboard : currentClip

    if ( currentClip != "" && !InStr( currentClip, A_Temp "\ClipTemp_" ) ) {
        lastManualClipboard := currentClip
    }
    return target
}

TryPasteFolderOrFileAsText( targetText ) {
    if ( IsMultiFolderPathText( targetText ) ) {
        PasteFoldersAsText( targetText )
        return true
    }
    if ( IsMultiFilePathText( targetText ) ) {
        PasteFilesAsText( targetText )
        return true
    }
    return false
}

PasteFoldersAsText( folderText ) {
    local folders := GetValidPathsFromText( folderText, "IsFolderPath" )
    if ( folders.Length = 0 ) {
        return
    }
    local combined := ReadMultipleFoldersAsText( folders )
    PastePlainTextWithBackup( combined, folders.Length " folders as text" )
}

PasteFilesAsText( fileText ) {
    local files := GetValidPathsFromText( fileText, "IsFilePathExists" )
    if ( files.Length = 0 ) {
        return
    }
    local combined := ReadMultipleFilesAsText( files )
    PastePlainTextWithBackup( combined, files.Length " files as text" )
}

PastePlainTextWithBackup( text, tooltipMsg ) {
    local backup := A_Clipboard
    A_Clipboard := text
    Send( "^v" )
    Sleep( 50 )
    A_Clipboard := backup
    ShowToolTip( tooltipMsg, 2000 )
}

PasteImagesAsPdf( imagePathText ) {
    local originalClip := A_Clipboard
    A_Clipboard := imagePathText
    local pdfPath := ProcessImagePathsToPDF()
    A_Clipboard := originalClip
    if ( pdfPath = "" ) {
        ShowToolTip( "Failed to create PDF", 2000 )
        return
    }
    PasteFile( pdfPath, "pdf" )
}

GetValidPathsFromText( text, validateFuncName ) {
    local lines := StrSplit( text, "`n", "`r" )
    local valid := []
    for line in lines {
        line := Trim( line )
        if ( line = "" ) {
            continue
        }
        if ( validateFuncName = "IsFolderPath" && IsFolderPath( line ) ) {
            valid.Push( line )
        } else if ( validateFuncName = "IsFilePathExists" && FileExist( line ) && !InStr( FileExist( line ), "D" ) ) {
            valid.Push( line )
        }
    }
    return valid
}

PasteWithSourceInfo( targetText ) {
    local sourceInfo := GetSourceInfoForText( targetText )
    local fullContent := "; " sourceInfo "`n`n" targetText

    if ( pasteMode = 1 ) {
        local tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend( fullContent, tempFile, "UTF-8" )
        SetClipboardFile( tempFile )
        Send( "^v" )
        ScheduleFileDeletion( tempFile )
        SetTimer( () => ( lastManualClipboard != "" ) ? ( A_Clipboard := lastManualClipboard ) : "", -10000 )
    } else {
        local backup := A_Clipboard
        A_Clipboard := fullContent
        Send( "^v" )
        Sleep( 50 )
        A_Clipboard := backup
    }
    ShowToolTip( "", 0 )
    SetTimer( () => ToolTip(), -2000 )
}

GetSourceInfoForText( targetText ) {
    global clipboardHistory
    for item in clipboardHistory {
        if ( item[ "text" ] = targetText ) {
            return "Copied from: " item[ "source" ] " (at " item[ "time" ] ")"
        }
    }
    return "Source: (Direct Paste via Hotkey) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
}
