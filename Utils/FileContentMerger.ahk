#Requires AutoHotkey v2.0

CombineFilePathsToTempFile( filePathListText, sourceInfo ) {
    local rawPaths := StrSplit( Trim( filePathListText ), "`n", "`r" )
    local validPaths := []
    for path in rawPaths {
        path := Trim( path )
        local attrs := FileExist( path )
        if ( path != "" && attrs != "" && !InStr( attrs, "D" ) ) {
            validPaths.Push( path )
        }
    }
    if ( validPaths.Length = 0 ) {
        return ""
    }

    local mergedText := ReadMultipleFilesAsText( validPaths )
    local fullContent := "; " sourceInfo "`n`n" mergedText
    local tempFile := A_Temp "\ClipTemp_Combine_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    return tempFile
}

ShowToolTip( msg, durationMs ) {
    ToolTip( msg )
    if ( durationMs > 0 ) {
        SetTimer( () => ToolTip(), -durationMs )
    }
}
