#Requires AutoHotkey v2.0

IsFolderPath( path ) {
    attrs := FileExist( path )
    return ( attrs != "" && InStr( attrs, "D" ) )
}

IsMultiFolderPathText( text ) {
    if !( text is String ) || ( text = "" ) {
        return false
    }
    lines := StrSplit( text, "`n", "`r" )
    if ( lines.Length < 1 ) {
        return false
    }
    local validFolderCount := 0
    for line in lines {
        line := Trim( line )
        if ( line = "" ) {
            continue
        }
        if ( IsFolderPath( line ) ) {
            validFolderCount++
        } else {
            return false
        }
    }
    return ( validFolderCount >= 1 )
}

CollectFilesFromFolder( folderPath, recursive := true, fileList := unset ) {
    if ( !IsSet( fileList ) ) {
        fileList := []
    }
    try {
        loop files, folderPath "\*", "F" {
            fileList.Push( A_LoopFileFullPath )
        }
        if ( recursive ) {
            loop files, folderPath "\*", "D" {
                CollectFilesFromFolder( A_LoopFileFullPath, true, fileList )
            }
        }
    }
    return fileList
}

CollectFilesFromFolders( folderPaths, recursive := true ) {
    allFiles := []
    for folder in folderPaths {
        folder := Trim( folder )
        if ( IsFolderPath( folder ) ) {
            files := CollectFilesFromFolder( folder, recursive )
            for f in files {
                allFiles.Push( f )
            }
        }
    }
    return allFiles
}

ReadMultipleFoldersAsText( folderPaths ) {
    allFiles := CollectFilesFromFolders( folderPaths, true )
    if ( allFiles.Length = 0 ) {
        return ""
    }
    return ReadMultipleFilesAsText( allFiles )
}
