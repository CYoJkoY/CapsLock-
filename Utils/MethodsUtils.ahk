#Requires AutoHotkey v2.0

Clamp( val, min, max ) => val < min ? min : ( val > max ? max : val )

ShowToolTip( msg, durationMs := 1500 ) {
    ToolTip( msg )
    if durationMs > 0
        SetTimer( () => ToolTip(), -durationMs )
}

Join( arr, sep := " " ) {
    s := ""
    for v in arr
        s .= v . sep
    return SubStr( s, 1, -StrLen( sep ) )
}

PasteTempText( content, tooltipMsg := "" ) {
    tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_MSec ".txt"
    FileAppend( content, tempFile, "UTF-8" )
    ClipboardHelper.SetClipboardFile( tempFile )
    ActivateAndPaste()
    CleanupManager.ScheduleDeletion( tempFile )
    if tooltipMsg
        ShowToolTip( tooltipMsg, 2000 )
}
