#Requires AutoHotkey v2.0

PasteWithCurrentMode() {
    target := A_Clipboard
    if target == "" {
        ShowToolTip( Lang( "MSG_CLIPBOARD_EMPTY" ), 2000 )
        return
    }

    validLines := []
    ignoredCount := 0
    lines := StrSplit( target, "`n", "`r" )
    for line in lines {
        line := Trim( line )
        if line == ""
            continue

        if FileExist( line ) && FileHelper.ShouldIgnore( line ) {
            ignoredCount++
            continue
        }
        validLines.Push( line )
    }

    if validLines.Length == 0 {
        ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 2000 )
        return
    }

    newTarget := ""
    for line in validLines
        newTarget .= line . "`n"
    newTarget := RTrim( newTarget, "`n" )

    item := Map( "text", newTarget, "source", "Direct Paste", "time", FormatTime(, "yyyy-MM-dd HH:mm:ss" ) )
    PasteAsFile( item )

}
