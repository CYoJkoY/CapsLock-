#Requires AutoHotkey v2.0

class FileHelper {
    static ReadMultipleFilesAsText( filePaths ) {
        result := ""
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        for idx, filePath in filePaths {
            filePath := Trim( filePath )
            if filePath == ""
                continue
            result .= this.BuildFileHeader( filePath, timestamp )
            result .= this.ReadFileContentSafe( filePath )
        }
        return RTrim( result, "`n" )
    }

    static BuildFileHeader( filePath, timestamp ) {
        SplitPath( filePath, &fileName )
        fileSize := FileGetSize( filePath )
        sizeStr := this.FormatBytes( fileSize )
        header := "; =========================================================================`n"
        header .= "; FILE: " filePath "`n"
        header .= "; NAME: " fileName " | SIZE: " sizeStr " | TIME: " timestamp "`n"
        header .= "; =========================================================================`n"
        return header
    }

    static ReadFileContentSafe( filePath ) {
        try {
            content := FileRead( filePath, "UTF-8" )
            return content "`n`n"
        } catch as err {
            return "[ERROR: Failed to read file - " err.Message "]`n`n"
        }
    }

    static CollectFilesFromFolder( folderPath, recursive := true, fileList := unset ) {
        if !IsSet( fileList )
            fileList := []
        try {
            loop files, folderPath "\*", "F"
                fileList.Push( A_LoopFileFullPath )
            if recursive {
                loop files, folderPath "\*", "D"
                    this.CollectFilesFromFolder( A_LoopFileFullPath, true, fileList )
            }
        }
        return fileList
    }

    static ReadMultipleFoldersAsText( folderPaths ) {
        allFiles := []
        for folder in folderPaths {
            folder := Trim( folder )
            if PathDetector.IsFolderPath( folder ) {
                files := this.CollectFilesFromFolder( folder, true )
                for f in files
                    allFiles.Push( f )
            }
        }
        if allFiles.Length == 0
            return ""
        return this.ReadMultipleFilesAsText( allFiles )
    }

    static FormatBytes( bytes ) {
        if bytes < 1024
            return bytes " B"
        else if bytes < 1048576
            return Round( bytes / 1024, 1 ) " KB"
        else if bytes < 1073741824
            return Round( bytes / 1048576, 1 ) " MB"
        else if bytes < 1099511627776
            return Round( bytes / 1073741824, 1 ) " GB"
        else
            return Round( bytes / 1099511627776, 1 ) " TB"
    }
}
