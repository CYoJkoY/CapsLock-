#Requires AutoHotkey v2.0

PasteWithCurrentMode() {
    target := A_Clipboard
    if target == "" {
        ShowToolTip( Lang( "MSG_CLIPBOARD_EMPTY" ), 2000 )
        return
    }

    lines := StrSplit( target, "`n", "`r" )
    validLines := []
    newTarget := ""
    allImages := true
    for line in lines {
        line := Trim( line )
        if line == ""
            continue

        if FileExist( line ) && FileHelper.ShouldIgnore( line )
            continue

        validLines.Push( line )

        if allImages && ( !FileExist( line ) || !PathDetector.IsImageExtension( line ) )
            allImages := false
    }

    newTarget := ""
    for line in validLines
        newTarget .= line "`n"
    newTarget := RTrim( newTarget, "`n" )

    if allImages && AppState.ImageMagickExe && FileExist( AppState.ImageMagickExe ) {
        original := A_Clipboard
        A_Clipboard := newTarget
        pdfPath := ProcessImagePathsToPDF()
        A_Clipboard := original
        if pdfPath != ""
            PasteFile( pdfPath, "pdf" )
        else
            ShowToolTip( Lang( "MSG_IMAGE_PDF_FAIL" ), 2000 )
        return
    }

    item := Map( "text", newTarget, "source", "Direct Paste", "time", FormatTime(, "yyyy-MM-dd HH:mm:ss" ) )
    PasteAsFile( item )
}
