#Requires AutoHotkey v2.0

PasteWithCurrentMode() {
    global AppState, PathDetector
    target := GetTargetText()
    if target == "" {
        ShowToolTip( Lang( "MSG_CLIPBOARD_EMPTY" ), 2000 )
        return
    }
    if AppState.PasteMode == 2 && TryPasteFolderOrFileAsText( target )
        return
    if PathDetector.IsImagePathsText( target ) {
        PasteImagesAsPdf( target )
        return
    }

    item := Map( "text", target, "source", "Direct Paste", "time", FormatTime(, "yyyy-MM-dd HH:mm:ss" ) )
    PastePlainTextWithSource( item )
}

GetTargetText() {
    global AppState
    current := A_Clipboard
    target := ( AppState.LastManualClipboard != "" ) ? AppState.LastManualClipboard : current
    if current != "" && !InStr( current, A_Temp "\ClipTemp_" )
        AppState.LastManualClipboard := current
    return target
}
