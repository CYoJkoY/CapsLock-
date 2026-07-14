#Requires AutoHotkey v2.0

PasteFile( filePath, fileType := "auto" ) {
    if fileType == "auto"
        fileType := GetFileType( filePath )
    if fileType == "pdf" || fileType == "image" {
        ClipboardHelper.ClearClipboard()
        ClipboardHelper.SetClipboardFile( filePath )
    } else {
        sourceInfo := "Copied from: File | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        content := ""
        try content := FileRead( filePath, "UTF-8" )
        catch
            content := "[File content could not be read]"
        full := "; " sourceInfo "`n`n" content
        tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend( full, tempFile, "UTF-8" )
        ClipboardHelper.ClearClipboard()
        ClipboardHelper.SetClipboardFile( tempFile )
        CleanupManager.ScheduleDeletion( tempFile )
        filePath := tempFile
    }
    ActivateAndPaste()
    if fileType == "pdf" && InStr( filePath, A_Temp "\ClipTemp_" )
        CleanupManager.ScheduleDeletion( filePath )
    ShowToolTip( "已粘贴 " fileType " 文件", 1500 )
}

ActivateAndPaste() {
    if AppState.TargetWindow && WinExist( "ahk_id " AppState.TargetWindow ) {
        WinActivate( "ahk_id " AppState.TargetWindow )
    } else {
        WinActivate( "A" )
    }
    Sleep( 100 )
    Send( "^v" )
}

GetFileType( filePath ) {
    ext := StrLower( SubStr( filePath, InStr( filePath, ".", , -1 ) + 1 ) )
    if ext == "pdf"
        return "pdf"
    for fmt in AppState.TextFormats
        if ext == fmt
            return "text"
    for fmt in AppState.ImageFormats
        if ext == fmt
            return "image"
    return "unknown"
}
