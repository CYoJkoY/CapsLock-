#Requires AutoHotkey v2.0

PasteAsFile( historyItem ) {
    if AppState.PasteMode == 2 && TryPasteFolderOrFileAsText( historyItem[ "text" ] )
        return
    if AppState.PasteMode == 1 {
        if PathDetector.IsMultiFolderPathText( historyItem[ "text" ] ) {
            folders := PathDetector.GetValidPathsFromText( historyItem[ "text" ], "folder" )
            if folders.Length > 0 {
                merged := FileHelper.ReadMultipleFoldersAsText( folders )
                sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
                full := "; " sourceInfo "`n`n" merged
                tempFile := A_Temp "\ClipTemp_Combine_" A_TickCount ".txt"
                FileAppend( full, tempFile, "UTF-8" )
                ClipboardHelper.SetClipboardFile( tempFile )
                ActivateAndPaste()
                CleanupManager.ScheduleDeletion( tempFile )
                ShowToolTip( "已粘贴合并的文件夹内容", 2000 )
                return
            }
        }
    }

    if PathDetector.IsImagePathsText( historyItem[ "text" ] ) {
        PasteImagesAsPdf( historyItem[ "text" ] )
        return
    }

    if PathDetector.IsFilePath( historyItem[ "text" ] ) && FileExist( historyItem[ "text" ] ) {
        PasteSingleFile( historyItem, true )
    } else {
        PastePlainTextWithSource( historyItem )
    }
}

TryPasteFolderOrFileAsText( targetText ) {
    global PathDetector, FileHelper
    if PathDetector.IsImagePathsText( targetText ) {
        lines := StrSplit( targetText, "`n", "`r" )
        pathList := []
        for line in lines {
            line := Trim( line )
            if line != "" && FileExist( line ) && !InStr( FileExist( line ), "D" )
                pathList.Push( line )
        }
        if pathList.Length > 0 {
            combined := ""
            for p in pathList
                combined .= p "`n"
            combined := Trim( combined, "`n" )
            PastePlainTextWithBackup( combined, "粘贴图片路径 (" pathList.Length " 个文件)" )
            return true
        }
    }

    if PathDetector.IsMixedPathsText( targetText ) {
        files := PathDetector.GetValidPathsFromText( targetText, "file" )
        folders := PathDetector.GetValidPathsFromText( targetText, "folder" )
        combined := ""
        if files.Length > 0
            combined .= FileHelper.ReadMultipleFilesAsText( files )
        if folders.Length > 0
            combined .= FileHelper.ReadMultipleFoldersAsText( folders )
        if combined != "" {
            PastePlainTextWithBackup( combined, "粘贴混合路径内容 (" files.Length " 文件, " folders.Length " 文件夹)" )
            return true
        }
    }

    if PathDetector.IsMultiFolderPathText( targetText ) {
        folders := PathDetector.GetValidPathsFromText( targetText, "folder" )
        if folders.Length > 0 {
            merged := FileHelper.ReadMultipleFoldersAsText( folders )
            PastePlainTextWithBackup( merged, "粘贴 " folders.Length " 个文件夹内容" )
            return true
        }
    }

    if PathDetector.IsMultiFilePathText( targetText ) {
        files := PathDetector.GetValidPathsFromText( targetText, "file" )
        if files.Length > 0 {
            merged := FileHelper.ReadMultipleFilesAsText( files )
            PastePlainTextWithBackup( merged, "粘贴 " files.Length " 个文件内容" )
            return true
        }
    }
    return false
}

PasteImagesAsPdf( imagePathText ) {
    original := A_Clipboard
    A_Clipboard := imagePathText
    pdfPath := ProcessImagePathsToPDF()
    A_Clipboard := original
    if pdfPath == "" {
        ShowToolTip( "创建PDF失败", 2000 )
        return
    }
    PasteFile( pdfPath, "pdf" )
}

PastePlainTextWithBackup( text, tooltipMsg ) {
    backup := A_Clipboard
    A_Clipboard := text
    Send( "^v" )
    Sleep( 50 )
    A_Clipboard := backup
    ShowToolTip( tooltipMsg, 2000 )
}

PastePlainTextWithSource( historyItem ) {
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullContent := "; " sourceInfo "`n`n" historyItem[ "text" ]
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    ClipboardHelper.SetClipboardFile( tempFile )
    ActivateAndPaste()
    CleanupManager.ScheduleDeletion( tempFile )
}

PasteSingleFile( historyItem, activate := true ) {
    if Type( historyItem ) == "Map"
        textToPaste := historyItem[ "text" ]
    else
        textToPaste := historyItem
    if PathDetector.IsImagePathsText( textToPaste ) {
        PasteImagesAsPdf( textToPaste )
        return
    }
    sourceInfo := ""
    if Type( historyItem ) == "Map" {
        sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    } else {
        for item in AppState.History {
            if item[ "text" ] == textToPaste {
                sourceInfo := "Copied from: " item[ "source" ] " (at " item[ "time" ] ")"
                break
            }
        }
        if sourceInfo == ""
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
    }
    fullContent := "; " sourceInfo "`n`n" textToPaste
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend( fullContent, tempFile, "UTF-8" )
    ClipboardHelper.SetClipboardFile( tempFile )
    if activate {
        ActivateAndPaste()
    } else {
        Send( "^v" )
    }
    CleanupManager.ScheduleDeletion( tempFile )
}

PasteAsMultipleFiles( textArray ) {
    tempFiles := []
    for item in textArray {
        if Type( item ) == "Map" {
            textToWrite := item[ "text" ]
            sourceInfo := "Copied from: " item[ "source" ] " (at " item[ "time" ] ")"
        } else {
            textToWrite := item
            sourceInfo := "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        }
        full := "; " sourceInfo "`n`n" textToWrite
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"
        FileAppend( full, tempFile, "UTF-8" )
        tempFiles.Push( tempFile )
    }
    ClipboardHelper.SetClipboardFiles( tempFiles )
    ActivateAndPaste()
    for f in tempFiles
        CleanupManager.ScheduleDeletion( f )
}
