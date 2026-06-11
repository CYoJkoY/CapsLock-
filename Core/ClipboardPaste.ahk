#Requires AutoHotkey v2.0

PasteFile( filePath, fileType := "auto" ) {
    global LastManualClipboard, TargetWindow

    if ( fileType = "auto" ) {
        fileType := GetFileType( filePath )
    }

    PrepareClipboardForPaste( filePath, fileType )
    ExecutePasteAction( TargetWindow )
    ScheduleClipboardRestore( filePath, fileType )

    ToolTip( "Pasted " fileType " file" )
    SetTimer( () => ToolTip(), -1500 )
}

PrepareClipboardForPaste( filePath, fileType ) {
    if ( fileType = "pdf" || fileType = "image" ) {
        ClearClipboard()
        SetClipboardFile( filePath )
    } else {
        PrepareTextFileForPaste( filePath, fileType )
    }
}

PrepareTextFileForPaste( filePath, fileType ) {
    local sourceInfo := "Copied from: File | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
    local content := ""
    try {
        content := FileRead( filePath, "UTF-8" )
    } catch {
        content := "[File content could not be read]"
    }
    local fullContent := "; " sourceInfo "`n`n" content
    local tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )

    ClearClipboard()
    SetClipboardFile( tempFile )
    ScheduleFileDeletion( tempFile )
}

ExecutePasteAction( targetWindow ) {
    if ( targetWindow && WinExist( "ahk_id " targetWindow ) ) {
        WinActivate( "ahk_id " targetWindow )
    } else {
        WinActivate( "A" )
    }
    Sleep( 100 )
    Send( "^v" )
}

ScheduleClipboardRestore( filePath, fileType ) {
    global LastManualClipboard
    if ( fileType = "pdf" && InStr( filePath, A_Temp "\ClipTemp_" ) ) {
        ScheduleFileDeletion( filePath )
    }
    if ( LastManualClipboard != "" ) {
        SetTimer( () => ( A_Clipboard := LastManualClipboard ), -10000 )
    }
}
