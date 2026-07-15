#Requires AutoHotkey v2.0

ProcessImagePathsToPDF() {
    exe := AppState.ImageMagickExe
    if exe == "" || !FileExist( exe ) {
        MsgBox( Lang( "MSG_IMAGEMAGICK_ERROR" ), Lang( "MSG_ERROR" ), "Iconx" )
        return ""
    }
    paths := []
    lines := StrSplit( A_Clipboard, "`n", "`r" )
    for line in lines {
        line := Trim( line )
        if line != "" && FileExist( line ) && !InStr( FileExist( line ), "D" ) {
            if FileHelper.ShouldIgnore( line )
                continue

            paths.Push( '"' line '"' )
        }
    }

    if paths.Length == 0 {
        ShowToolTip( Lang( "MSG_NO_IMAGE_FILES" ), 2000 )
        return ""
    }

    outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"
    cmd := '"' exe '" ' . Join( paths, " " ) . ' -density 150 -quality 100 "' outputPdf '"'
    try {
        RunWait( cmd, , "Hide" )

        if FileExist( outputPdf ) {
            ShowToolTip( Lang( "MSG_IMAGE_PDF_SUCCESS" ), 2000 )
            return outputPdf
        } else {
            ShowToolTip( Lang( "MSG_PDF_IM_ERROR" ), 2000 )
            return ""
        }

    } catch as err {
        ShowToolTip( Lang( "MSG_PDF_IM_EXCEPTION", , err.Message ), 3000 )
        return ""
    }
}

Join( arr, sep := " " ) {
    s := ""
    for v in arr
        s .= v . sep
    return SubStr( s, 1, -StrLen( sep ) )
}
