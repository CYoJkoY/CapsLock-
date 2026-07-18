#Requires AutoHotkey v2.0

PasteAsPlainText( content, tooltipMsg := "" ) {
    backup := A_Clipboard
    A_Clipboard := content
    ActivateAndPaste()
    Sleep( 50 )
    A_Clipboard := backup
    if ( tooltipMsg != "" )
        ShowToolTip( tooltipMsg, 2000 )
}

PasteImagesAsPdf( imagePathText ) {
    original := A_Clipboard
    A_Clipboard := imagePathText
    pdfPath := ProcessImagePathsToPDF()
    A_Clipboard := original
    if ( pdfPath == "" ) {
        ShowToolTip( Lang( "MSG_IMAGE_PDF_FAIL" ), 2000 )
        return
    }
    PasteFile( pdfPath, "pdf" )
}

PasteSingleFile( historyItem, activate := true ) {
    textToPaste := historyItem[ "text" ]
    if FileHelper.ShouldIgnore( textToPaste ) {
        ShowToolTip( Lang( "MSG_FILE_IGNORED" ), 1500 )
        return
    }

    if PathDetector.IsImagePathsText( textToPaste ) {
        PasteImagesAsPdf( textToPaste )
        return
    }

    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullContent := "; " sourceInfo "`n`n" textToPaste
    PasteTempText( fullContent, Lang( "MSG_PASTE_FILE_TYPE", , "text" ) )
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

PastePlainTextWithSource( historyItem ) {
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullContent := "; " sourceInfo "`n`n" historyItem[ "text" ]
    PasteTempText( fullContent )
}

HandleSingleFileText( historyItem ) {
    target := historyItem[ "text" ]
    if FileHelper.ShouldIgnore( target ) {
        ShowToolTip( Lang( "MSG_FILE_IGNORED" ), 1500 )
        return
    }
    content := FileHelper.ReadFileContentSafe( target )
    if ( content == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" content
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILE_TYPE", , "text" ) )
}

HandleMultipleFilesText( historyItem ) {
    target := historyItem[ "text" ]
    files := PathDetector.GetValidPathsFromText( target, "file" )
    if files.Length == 0
        return

    validFiles := []
    for f in files {
        if !FileHelper.ShouldIgnore( f )
            validFiles.Push( f )
    }

    if validFiles.Length == 0 {
        ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 1500 )
        return
    }

    merged := FileHelper.ReadMultipleFilesAsText( validFiles )
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }

    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILES", , validFiles.Length ) )
}

HandleMultipleFoldersText( historyItem ) {
    target := historyItem[ "text" ]
    folders := PathDetector.GetValidPathsFromText( target, "folder" )
    if folders.Length == 0
        return
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
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FOLDER_EMPTY_OR_IGNORED" ), 1500 )
        return
    }
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FOLDERS", , validFolders.Length ) )
}

HandleMixedPathsText( historyItem ) {
    target := historyItem[ "text" ]
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
    if allFiles.Length == 0
        return
    merged := FileHelper.ReadMultipleFilesAsText( allFiles )
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_MIXED", , validFiles.Length, validFolders.Length ) )
}

HandlePlainText( historyItem ) {
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" historyItem[ "text" ]
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILE_TYPE", , "text" ) )
}

PasteAsFile( historyItem ) {
    target := historyItem[ "text" ]

    if PathDetector.IsImagePathsText( target ) {
        PasteImagesAsPdf( target )
        return
    }

    if ( AppState.PasteMode == 2 ) {

        if PathDetector.IsFilePath( target ) && FileExist( target ) {
            HandleSingleFileText( historyItem )
            return
        }

        if PathDetector.IsMultiFilePathText( target ) {
            HandleMultipleFilesText( historyItem )
            return
        }

        if PathDetector.IsMultiFolderPathText( target ) {
            HandleMultipleFoldersText( historyItem )
            return
        }

        if PathDetector.IsMixedPathsText( target ) {
            HandleMixedPathsText( historyItem )
            return
        }

        HandlePlainText( historyItem )
        return
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
        validFiles := []
        for f in files {
            if !FileHelper.ShouldIgnore( f )
                validFiles.Push( f )
        }

        if validFiles.Length == 0 {
            ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 1500 )
            return
        }

        merged := FileHelper.ReadMultipleFilesAsText( validFiles )
        if merged != "" {
            sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
            full := "; " sourceInfo "`n`n" merged
            PasteTempText( full, Lang( "MSG_PASTE_FILES", , validFiles.Length ) )
        } else {
            ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        }
        return

    }

    if PathDetector.IsMultiFolderPathText( target ) {
        folders := PathDetector.GetValidPathsFromText( target, "folder" )
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
            PasteTempText( full, Lang( "MSG_FOLDER_MERGED" ) )
        } else {
            ShowToolTip( Lang( "MSG_FOLDER_EMPTY_OR_IGNORED" ), 1500 )
        }

        return
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

        if allFiles.Length == 0
            return

        merged := FileHelper.ReadMultipleFilesAsText( allFiles )
        if merged != "" {
            sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
            full := "; " sourceInfo "`n`n" merged
            PasteTempText( full, Lang( "MSG_PASTE_MIXED", , validFiles.Length, validFolders.Length ) )
        } else {
            ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        }

        return
    }

    PastePlainTextWithSource( historyItem )
}
