#Requires AutoHotkey v2.0

class HistoryPasteUtils {
    static GetPathType( text ) {
        if PathDetector.IsImagePathsText( text ) {
            return { type: "image" }
        }

        files := PathDetector.GetValidPathsFromText( text, "file" )
        folders := PathDetector.GetValidPathsFromText( text, "folder" )

        if files.Length && folders.Length {
            return { type: "mixed", files: files, folders: folders }
        } else if files.Length {
            return { type: "file", files: files }
        } else if folders.Length {
            return { type: "folder", folders: folders }
        } else {
            return { type: "plain" }
        }
    }
}

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

_PasteSingleFileAsText( filePath, sourceInfo ) {
    content := FileHelper.ReadFileContentSafe( filePath )
    if ( content == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }
    fullText := "; " sourceInfo "`n`n" content
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILE_TYPE", , "text" ) )
}

_PasteMultipleFilesAsText( filePaths, sourceInfo ) {
    merged := FileHelper.ReadMultipleFilesAsText( filePaths )
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILES", , filePaths.Length ) )
}

_PasteMultipleFoldersAsText( folderPaths, sourceInfo ) {
    merged := FileHelper.ReadMultipleFoldersAsText( folderPaths )
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FOLDER_EMPTY_OR_IGNORED" ), 1500 )
        return
    }
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FOLDERS", , folderPaths.Length ) )
}

_PasteMixedPathsAsText( filePaths, folderPaths, sourceInfo ) {
    allFiles := []
    for f in filePaths
        allFiles.Push( f )
    for fd in folderPaths {
        collected := FileHelper.CollectFilesFromFolder( fd, true )
        for cf in collected {
            if !FileHelper.ShouldIgnore( cf )
                allFiles.Push( cf )
        }
    }
    if allFiles.Length == 0 {
        ShowToolTip( Lang( "MSG_ALL_PATHS_IGNORED" ), 1500 )
        return
    }
    merged := FileHelper.ReadMultipleFilesAsText( allFiles )
    if ( merged == "" ) {
        ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
        return
    }
    fullText := "; " sourceInfo "`n`n" merged
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_MIXED", , filePaths.Length, folderPaths.Length ) )
}

HandlePlainText( historyItem ) {
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"
    fullText := "; " sourceInfo "`n`n" historyItem[ "text" ]
    PasteAsPlainText( fullText, Lang( "MSG_PASTE_FILE_TYPE", , "text" ) )
}

PasteAsFile( historyItem ) {
    target := historyItem[ "text" ]
    sourceInfo := "Copied from: " historyItem[ "source" ] " (at " historyItem[ "time" ] ")"

    if PathDetector.IsImagePathsText( target ) {
        PasteImagesAsPdf( target )
        return
    }

    pathInfo := HistoryPasteUtils.GetPathType( target )

    if pathInfo.type == "plain" {
        if AppState.PasteMode == 2 {
            HandlePlainText( historyItem )
        } else {
            PastePlainTextWithSource( historyItem )
        }
        return
    }

    if AppState.PasteMode == 2 {
        switch pathInfo.type {
        case "file":
            validFiles := []
            for f in pathInfo.files {
                if !FileHelper.ShouldIgnore( f )
                    validFiles.Push( f )
            }

            if validFiles.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 1500 )
                return
            }

            if validFiles.Length == 1 {
                _PasteSingleFileAsText( validFiles[ 1 ], sourceInfo )
            } else {
                _PasteMultipleFilesAsText( validFiles, sourceInfo )
            }

        case "folder":
            validFolders := []
            for fd in pathInfo.folders {
                if !FileHelper.ShouldIgnore( fd )
                    validFolders.Push( fd )
            }

            if validFolders.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_FOLDERS_IGNORED" ), 1500 )
                return
            }

            _PasteMultipleFoldersAsText( validFolders, sourceInfo )

        case "mixed":
            validFiles := [], validFolders := []
            for f in pathInfo.files {
                if !FileHelper.ShouldIgnore( f )
                    validFiles.Push( f )
            }

            for fd in pathInfo.folders {
                if !FileHelper.ShouldIgnore( fd )
                    validFolders.Push( fd )
            }

            if validFiles.Length == 0 && validFolders.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_PATHS_IGNORED" ), 1500 )
                return
            }

            _PasteMixedPathsAsText( validFiles, validFolders, sourceInfo )
        }

    } else {
        switch pathInfo.type {
        case "file":
            if pathInfo.files.Length == 1 && !FileHelper.ShouldIgnore( pathInfo.files[ 1 ] ) {
                PasteSingleFile( historyItem, true )
            } else {
                validFiles := []
                for f in pathInfo.files {
                    if !FileHelper.ShouldIgnore( f )
                        validFiles.Push( f )
                }

                if validFiles.Length == 0 {
                    ShowToolTip( Lang( "MSG_ALL_FILES_IGNORED" ), 1500 )
                    return
                }

                merged := FileHelper.ReadMultipleFilesAsText( validFiles )
                if merged != "" {
                    full := "; " sourceInfo "`n`n" merged
                    PasteTempText( full, Lang( "MSG_PASTE_FILES", , validFiles.Length ) )
                } else {
                    ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
                }
            }

        case "folder":
            validFolders := []
            for fd in pathInfo.folders {
                if !FileHelper.ShouldIgnore( fd )
                    validFolders.Push( fd )
            }

            if validFolders.Length == 0 {
                ShowToolTip( Lang( "MSG_ALL_FOLDERS_IGNORED" ), 1500 )
                return
            }

            merged := FileHelper.ReadMultipleFoldersAsText( validFolders )
            if merged != "" {
                full := "; " sourceInfo "`n`n" merged
                PasteTempText( full, Lang( "MSG_FOLDER_MERGED" ) )
            } else {
                ShowToolTip( Lang( "MSG_FOLDER_EMPTY_OR_IGNORED" ), 1500 )
            }

        case "mixed":
            validFiles := [], validFolders := []
            for f in pathInfo.files {
                if !FileHelper.ShouldIgnore( f )
                    validFiles.Push( f )
            }

            for fd in pathInfo.folders {
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

            merged := FileHelper.ReadMultipleFilesAsText( allFiles )
            if merged != "" {
                full := "; " sourceInfo "`n`n" merged
                PasteTempText( full, Lang( "MSG_PASTE_MIXED", , validFiles.Length, validFolders.Length ) )
            } else {
                ShowToolTip( Lang( "MSG_FILES_EMPTY" ), 1500 )
            }
        }
    }
}
