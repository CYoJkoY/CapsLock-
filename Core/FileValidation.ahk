#Requires AutoHotkey v2.0

class PathDetector {
    static IsFilePath( text ) {
        if ( InStr( text, ":\" ) || InStr( text, "\\" ) ) {
            ext := SubStr( text, InStr( text, ".", , -1 ) + 1 )
            if ( ext != "" && StrLen( ext ) < 12 )
                return true
        }
        return false
    }

    static IsImagePathsText( text ) {
        if !( text is String ) || text == "" || InStr( text, A_Temp "\ClipTemp_" )
            return false
        lines := StrSplit( text, "`n", "`r" )
        if lines.Length == 0
            return false
        for line in lines {
            line := Trim( line )
            if line == ""
                continue
            if !FileExist( line ) || !this.IsImageExtension( line )
                return false
        }
        return true
    }

    static IsImageExtension( filePath ) {
        ext := StrLower( SubStr( filePath, InStr( filePath, ".", , -1 ) + 1 ) )
        for fmt in AppState.ImageFormats
            if ext == fmt
                return true
        return false
    }

    static IsMultiFilePathText( text ) {
        if !( text is String ) || text == ""
            return false
        lines := StrSplit( text, "`n", "`r" )
        if lines.Length < 1
            return false
        for line in lines {
            line := Trim( line )
            if line == ""
                continue
            attrs := FileExist( line )
            if !attrs || InStr( attrs, "D" )
                return false
        }
        return true
    }

    static IsFolderPath( path ) {
        attrs := FileExist( path )
        return attrs != "" && InStr( attrs, "D" )
    }

    static IsMultiFolderPathText( text ) {
        if !( text is String ) || text == ""
            return false
        lines := StrSplit( text, "`n", "`r" )
        if lines.Length < 1
            return false
        for line in lines {
            line := Trim( line )
            if line == ""
                continue
            if !this.IsFolderPath( line )
                return false
        }
        return true
    }

    static IsMixedPathsText( text ) {
        if !( text is String ) || text == ""
            return false
        lines := StrSplit( text, "`n", "`r" )
        hasFile := false, hasFolder := false
        for line in lines {
            line := Trim( line )
            if line == ""
                continue
            attrs := FileExist( line )
            if attrs == ""
                return false
            if InStr( attrs, "D" )
                hasFolder := true
            else
                hasFile := true
            if hasFile && hasFolder
                return true
        }
        return false
    }

    static GetValidPathsFromText( text, validateFunc ) {
        lines := StrSplit( text, "`n", "`r" )
        valid := []
        for line in lines {
            line := Trim( line )
            if line == ""
                continue
            if ( %validateFunc%( line ) )
                valid.Push( line )
        }
        return valid
    }
}
