#Requires AutoHotkey v2.0

ProcessImagePathsToPDF() {
    global ImageMagickExe

    if ( !ValidateImageMagickPath( ImageMagickExe ) ) {
        return ""
    }

    validPaths := ExtractValidImagePaths( A_Clipboard )
    if ( validPaths.Length = 0 ) {
        ShowTemporaryToolTip( "No valid image files found in clipboard.", 2000 )
        return ""
    }

    return ExecuteImageMagickMerge( ImageMagickExe, validPaths )
}

ValidateImageMagickPath( exePath ) {
    if ( exePath = "" ) {
        MsgBox( "Please set ImageMagick path first via tray icon menu.", "Error", "Iconx 4096" )
        return false
    }
    if ( !FileExist( exePath ) ) {
        MsgBox( "ImageMagick executable not found at: `n" exePath, "Error", "Iconx 4096" )
        return false
    }
    return true
}

ExtractValidImagePaths( clipboardText ) {
    local imgPaths := StrSplit( clipboardText, "`n", "`r" )
    local validPaths := []
    for idx, line in imgPaths {
        line := Trim( line )
        if ( line = "" ) {
            continue
        }
        if ( FileExist( line ) ) {
            validPaths.Push( '"' line '"' )
        }
    }
    return validPaths
}

ExecuteImageMagickMerge( exePath, validPaths ) {
    local outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"
    local command := BuildMagickCommand( exePath, validPaths, outputPdf )

    ShowTemporaryToolTip( "Merging " validPaths.Length " images to PDF...", 0 )
    try {
        RunWait( command, , "Hide" )
        if ( FileExist( outputPdf ) ) {
            ShowTemporaryToolTip( "PDF created successfully!", 2000 )
            return outputPdf
        } else {
            ShowTemporaryToolTip( "Failed to create PDF", 2000 )
            return ""
        }
    } catch as err {
        ShowTemporaryToolTip( "Failed to create PDF: " err.Message, 3000 )
        return ""
    }
}

BuildMagickCommand( exePath, validPaths, outputPdf ) {
    local command := '"' exePath '" '
    for path in validPaths {
        command .= path " "
    }
    command .= '-density 150 -quality 100 "' outputPdf '"'
    return command
}

ShowTemporaryToolTip( message, duration ) {
    ToolTip( message )
    if ( duration > 0 ) {
        SetTimer( () => ToolTip(), -duration )
    }
}
