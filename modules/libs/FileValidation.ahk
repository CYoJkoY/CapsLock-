#Requires AutoHotkey v2.0

IsFilePath( text ) {
    if ( InStr( text, ":\" ) || InStr( text, "\\" ) ) {
        ext := SubStr( text, InStr( text, ".", , -1 ) + 1 )
        if ( ext != "" && StrLen( ext ) < 12 ) {
            return true
        }
    }
    return false
}

IsMultiFilePathText( text ) {
    if ( !( text is String ) || ( text = "" ) ) {
        return false
    }

    local lines := StrSplit( text, "`n", "`r" )
    if ( lines.Length < 1 ) {
        return false
    }

    local validFileCount := 0
    for line in lines {
        line := Trim( line )
        if ( line = "" ) {
            continue
        }

        local attrs := FileExist( line )
        if ( attrs != "" && !InStr( attrs, "D" ) ) {
            validFileCount++
        } else {
            return false
        }
    }
    return ( validFileCount >= 1 )
}

GetFileType( filePath ) {
    global ImageFormats
    ext := StrLower( SubStr( filePath, InStr( filePath, ".", , -1 ) + 1 ) )

    if ( ext = "pdf" ) {
        return "pdf"
    }
    if ( ext = "txt" || ext = "ini" || ext = "ahk" || ext = "js" || ext = "py" || ext = "cpp" || ext = "h" ) {
        return "text"
    }
    for imgformat in ImageFormats {
        if ( ext = imgformat ) {
            return "image"
        }
    }
    return "unknown"
}

IsImagePathsText( text ) {
    global ImageFormats
    if ( !( text is String ) || text = "" || InStr( text, A_Temp "\ClipTemp_" ) ) {
        return false
    }

    lines := StrSplit( text, "`n", "`r" )
    if ( lines.Length < 2 ) {
        return false
    }

    for idx, line in lines {
        line := Trim( line )
        if ( line = "" ) {
            continue
        }
        if ( !FileExist( line ) || !IsImageExtension( line, ImageFormats ) ) {
            return false
        }
    }
    return true
}

IsImageExtension( filePath, imageFormats ) {
    ext := StrLower( SubStr( filePath, InStr( filePath, ".", , -1 ) + 1 ) )
    for imgformat in imageFormats {
        if ( ext = imgformat ) {
            return true
        }
    }
    return false
}
