#Requires AutoHotkey v2.0

PasteAsFile( historyItem ) {
    target := historyItem[ "text" ]

    if !PathDetector.IsFilePath( target ) && !PathDetector.IsMultiFilePathText( target )
    && !PathDetector.IsMultiFolderPathText( target ) && !PathDetector.IsMixedPathsText( target ) {
        PastePlainTextWithSource( historyItem )
        return
    }

    if PathDetector.IsImagePathsText( target ) {
        PasteImagesAsPdf( target )
        return
    }

    if AppState.PasteMode == 1 && PathDetector.IsMultiFolderPathText( target ) {
        folders := PathDetector.GetValidPathsFromText( target, "folder" )
        if folders.Length > 0 {
            validFolders := []
            for fd in folders {
                if !FileHelper.ShouldIgnore( fd )
                    validFolders.Push( fd )
            }

            if validFolders.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_FOLDERS_IGNORED" ), 1500 )
                return
            }

            merged := FileHelper.ReadMultipleFoldersAsText( validFolders )
            if merged != "" {
                sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
                full := "; " sourceInfo "`n`n" merged
                tempFile := A_Temp "\ClipTemp_Combine_" A_TickCount ".txt"
                FileAppend( full, tempFile, "UTF-8" )
                ClipboardHelper.SetClipboardFile( tempFile )
                ActivateAndPaste()
                CleanupManager.ScheduleDeletion( tempFile )
                ShowToolTip( Lang( "MSG_FOLDER_MERGED" ), 2000 )
                return
            } else {
                ShowToolTip( Lang( "MSG_FOLDER_EMPTY_OR_IGNORED" ), 1500 )
                return
            }
        }
    }

    if PathDetector.IsFilePath( target ) && FileExist( target ) {
        if FileHelper.ShouldIgnore( target ) {
            ShowToolTip( Lang( "MSG_FILE_IGNORED" ), 1500 )
            return
        }

        PasteSingleFile( historyItem, true )
        return
    }

    if PathDetector.IsMultiFilePathText( target ) {
        files := PathDetector.GetValidPathsFromText( target, "file" )
        if files.Length > 0 {
            validFiles := []
            for f in files {
                if !FileHelper.ShouldIgnore( f )
                    validFiles.Push( f )
            }

            if validFiles.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 1500 )
                return
            }

            if AppState.PasteMode == 2 {
                merged := FileHelper.ReadMultipleFilesAsText( validFiles )
                if merged != "" {
                    PastePlainTextWithBackup( merged, Lang( "MSG_PASTE_FILES", , validFiles.Length ) )
                } else {
                    ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
                }
            } else {
                items := []
                for f in validFiles {
                    items.Push( Map( "text", f, "source", historyItem[ "source" ], "time", historyItem[ "time" ] ) )
                }
                PasteAsMultipleFiles( items )
            }
            return
        }
    }

    if PathDetector.IsMixedPathsText( target ) {
        files := PathDetector.GetValidPathsFromText( target, "file" )
        folders := PathDetector.GetValidPathsFromText( target, "folder" )
        validFiles := []
        for f in files {
            if !FileHelper.ShouldIgnore( f )
                validFiles.Push( f )
        }
        validFolders := []
        for fd in folders {
            if !FileHelper.ShouldIgnore( fd )
                validFolders.Push( fd )
        }
        if validFiles.Length == 0 && validFolders.Length == 0 {
            ShowToolTip( Lang( "MSG_ALL_PATHS_IGNORED" ), 1500 )
            return
        }

        allFiles := []
        for f in validFiles
            allFiles.Push( f )
        for fd in validFolders {
            collected := FileHelper.CollectFilesFromFolder( fd, true )
            for cf in collected {
                if !FileHelper.ShouldIgnore( cf )
                    allFiles.Push( cf )
            }
        }
        if allFiles.Length == 0 {
            ShowToolTip( Lang( "MSG_NO_VALID_FILES" ), 1500 )
            return
        }
        if AppState.PasteMode == 2 {
            merged := FileHelper.ReadMultipleFilesAsText( allFiles )
            if merged != "" {
                PastePlainTextWithBackup( merged, Lang( "MSG_PASTE_MIXED", , validFiles.Length, validFolders.Length ) )
            } else {
                ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
            }
        } else {
            items := []
            for f in allFiles {
                items.Push( Map( "text", f, "source", historyItem[ "source" ], "time", historyItem[ "time" ] ) )
            }
            PasteAsMultipleFiles( items )
        }
        return
    }

    PastePlainTextWithSource( historyItem )
}

PasteImagesAsPdf( imagePathText ) {
    original := A_Clipboard
    A_Clipboard := imagePathText
    pdfPath := ProcessImagePathsToPDF()
    A_Clipboard := original
    if pdfPath == "" {
        ShowToolTip( Lang( "MSG_IMAGE_PDF_FAIL" ), 2000 )
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

    if FileHelper.ShouldIgnore( textToPaste ) {
        ShowToolTip( Lang( "MSG_FILE_IGNORED" ), 1500 )
        return
    }

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
