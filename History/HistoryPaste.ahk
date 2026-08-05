#Requires AutoHotkey v2.0

class HistoryPasteUtils {
    static GetPathType(text) {
        if PathDetector.IsImagePathsText(text)
            return { type: "image" }

        files := PathDetector.GetValidPathsFromText(text, "file")
        folders := PathDetector.GetValidPathsFromText(text, "folder")

        if files.Length && folders.Length
            return { type: "mixed", files: files, folders: folders }

        if files.Length
            return { type: "file", files: files }

        if folders.Length
            return { type: "folder", folders: folders }

        return { type: "plain" }
    }
}

PasteAsPlainText(content, tooltipMsg := "") {
    backup := A_Clipboard

    AppState.IgnoreNextClipChange := true
    A_Clipboard := content

    ActivateAndPaste()
    Sleep(50)

    AppState.IgnoreNextClipChange := true
    A_Clipboard := backup

    if tooltipMsg != ""
        ShowToolTip(tooltipMsg, 2000)
}

PasteImagesAsPdf(imagePathText) {
    original := A_Clipboard

    AppState.IgnoreNextClipChange := true
    A_Clipboard := imagePathText

    pdfPath := ProcessImagePathsToPDF()

    AppState.IgnoreNextClipChange := true
    A_Clipboard := original

    if pdfPath == "" {
        ShowToolTip(Lang("MSG_IMAGE_PDF_FAIL"), 2000)
        return
    }

    PasteFile(pdfPath, "pdf")
}

PasteSingleFile(historyItem, activate := true) {
    textToPaste := historyItem["text"]

    if FileHelper.ShouldIgnore(textToPaste) {
        ShowToolTip(Lang("MSG_FILE_IGNORED"), 1500)
        return
    }

    if PathDetector.IsImagePathsText(textToPaste) {
        PasteImagesAsPdf(textToPaste)
        return
    }

    _PasteTempWithSourceHeader(
        _GetHistorySourceInfo(historyItem),
        textToPaste,
        Lang("MSG_PASTE_FILE_TYPE", "", "text")
    )
}

PasteAsMultipleFiles(textArray) {
    tempFiles := []

    for item in textArray {
        if Type(item) == "Map" {
            textToWrite := item["text"]
            sourceInfo := _GetHistorySourceInfo(item)
        } else {
            textToWrite := item
            sourceInfo := _GetNowSourceInfo()
        }

        full := "; " sourceInfo "`n`n" textToWrite
        tempFile := A_Temp "\ClipTemp_" A_TickCount "_" A_Index ".txt"

        FileAppend(full, tempFile, "UTF-8")
        tempFiles.Push(tempFile)
    }

    if tempFiles.Length == 0
        return

    ClipboardHelper.SetClipboardFiles(tempFiles)
    ActivateAndPaste()

    for f in tempFiles
        CleanupManager.ScheduleDeletion(f)
}

PastePlainTextWithSource(historyItem) {
    _PasteTempWithSourceHeader(
        _GetHistorySourceInfo(historyItem),
        historyItem["text"]
    )
}

HandlePlainText(historyItem) {
    _PasteTextWithSourceHeader(
        _GetHistorySourceInfo(historyItem),
        historyItem["text"],
        Lang("MSG_PASTE_FILE_TYPE", "", "text")
    )
}

PasteAsFile(historyItem) {
    target := historyItem["text"]
    sourceInfo := _GetHistorySourceInfo(historyItem)

    if PathDetector.IsImagePathsText(target) {
        PasteImagesAsPdf(target)
        return
    }

    pathInfo := HistoryPasteUtils.GetPathType(target)

    if pathInfo.type == "plain" {
        if AppState.PasteMode == 2
            HandlePlainText(historyItem)
        else
            PastePlainTextWithSource(historyItem)
        return
    }

    if AppState.PasteMode == 2 {
        switch pathInfo.type {
            case "file":
                validFiles := _FilterIgnored(pathInfo.files)

                if validFiles.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_FILES_IGNORED"), 1500)
                    return
                }

                if validFiles.Length == 1
                    _PasteSingleFileAsText(validFiles[1], sourceInfo)
                else
                    _PasteMultipleFilesAsText(validFiles, sourceInfo)

            case "folder":
                validFolders := _FilterIgnored(pathInfo.folders)

                if validFolders.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_FOLDERS_IGNORED"), 1500)
                    return
                }

                _PasteMultipleFoldersAsText(validFolders, sourceInfo)

            case "mixed":
                validFiles := _FilterIgnored(pathInfo.files)
                validFolders := _FilterIgnored(pathInfo.folders)

                if validFiles.Length == 0 && validFolders.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_PATHS_IGNORED"), 1500)
                    return
                }

                _PasteMixedPathsAsText(validFiles, validFolders, sourceInfo)
        }
    } else {
        switch pathInfo.type {
            case "file":
                if pathInfo.files.Length == 1 && !FileHelper.ShouldIgnore(pathInfo.files[1]) {
                    PasteSingleFile(historyItem, true)
                    return
                }

                validFiles := _FilterIgnored(pathInfo.files)

                if validFiles.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_FILES_IGNORED"), 1500)
                    return
                }

                merged := FileHelper.ReadMultipleFilesAsText(validFiles)

                if merged != ""
                    _PasteTempWithSourceHeader(sourceInfo, merged, Lang("MSG_PASTE_FILES", "", validFiles.Length))
                else
                    ShowToolTip(Lang("MSG_FILES_EMPTY"), 1500)

            case "folder":
                validFolders := _FilterIgnored(pathInfo.folders)

                if validFolders.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_FOLDERS_IGNORED"), 1500)
                    return
                }

                merged := FileHelper.ReadMultipleFoldersAsText(validFolders)

                if merged != ""
                    _PasteTempWithSourceHeader(sourceInfo, merged, Lang("MSG_FOLDER_MERGED"))
                else
                    ShowToolTip(Lang("MSG_FOLDER_EMPTY_OR_IGNORED"), 1500)

            case "mixed":
                validFiles := _FilterIgnored(pathInfo.files)
                validFolders := _FilterIgnored(pathInfo.folders)

                if validFiles.Length == 0 && validFolders.Length == 0 {
                    ShowToolTip(Lang("MSG_ALL_PATHS_IGNORED"), 1500)
                    return
                }

                allFiles := _CollectAllFiles(validFiles, validFolders)
                merged := FileHelper.ReadMultipleFilesAsText(allFiles)

                if merged != ""
                    _PasteTempWithSourceHeader(sourceInfo, merged, Lang("MSG_PASTE_MIXED", "", validFiles.Length, validFolders.Length))
                else
                    ShowToolTip(Lang("MSG_FILES_EMPTY"), 1500)
        }
    }
}

_PasteSingleFileAsText(filePath, sourceInfo) {
    content := FileHelper.ReadFileContentSafe(filePath)

    if content == "" {
        ShowToolTip(Lang("MSG_FILES_EMPTY"), 1500)
        return
    }

    _PasteTextWithSourceHeader(sourceInfo, content, Lang("MSG_PASTE_FILE_TYPE", "", "text"))
}

_PasteMultipleFilesAsText(filePaths, sourceInfo) {
    merged := FileHelper.ReadMultipleFilesAsText(filePaths)

    if merged == "" {
        ShowToolTip(Lang("MSG_FILES_EMPTY"), 1500)
        return
    }

    _PasteTextWithSourceHeader(sourceInfo, merged, Lang("MSG_PASTE_FILES", "", filePaths.Length))
}

_PasteMultipleFoldersAsText(folderPaths, sourceInfo) {
    merged := FileHelper.ReadMultipleFoldersAsText(folderPaths)

    if merged == "" {
        ShowToolTip(Lang("MSG_FOLDER_EMPTY_OR_IGNORED"), 1500)
        return
    }

    _PasteTextWithSourceHeader(sourceInfo, merged, Lang("MSG_PASTE_FOLDERS", "", folderPaths.Length))
}

_PasteMixedPathsAsText(filePaths, folderPaths, sourceInfo) {
    allFiles := _CollectAllFiles(filePaths, folderPaths)

    if allFiles.Length == 0 {
        ShowToolTip(Lang("MSG_ALL_PATHS_IGNORED"), 1500)
        return
    }

    merged := FileHelper.ReadMultipleFilesAsText(allFiles)

    if merged == "" {
        ShowToolTip(Lang("MSG_FILES_EMPTY"), 1500)
        return
    }

    _PasteTextWithSourceHeader(sourceInfo, merged, Lang("MSG_PASTE_MIXED", "", filePaths.Length, folderPaths.Length))
}

_GetHistorySourceInfo(historyItem) {
    return "Copied from: " historyItem["source"] " (at " historyItem["time"] ")"
}

_GetNowSourceInfo() {
    return "Source: (Pasted from History) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
}

_PasteTextWithSourceHeader(sourceInfo, content, tooltipMsg := "") {
    PasteAsPlainText("; " sourceInfo "`n`n" content, tooltipMsg)
}

_PasteTempWithSourceHeader(sourceInfo, content, tooltipMsg := "") {
    PasteTempText("; " sourceInfo "`n`n" content, tooltipMsg)
}

_FilterIgnored(paths) {
    valid := []

    for path in paths {
        if !FileHelper.ShouldIgnore(path)
            valid.Push(path)
    }

    return valid
}

; Collect all files from a mix of individual files and folders.
; FileHelper.CollectFilesFromFolder() already applies ShouldIgnore internally,
; so we skip redundant ShouldIgnore checks on collected files.
_CollectAllFiles(files, folders) {
    allFiles := []

    for f in files
        allFiles.Push(f)

    for fd in folders {
        collected := FileHelper.CollectFilesFromFolder(fd, true)
        ; No redundant ShouldIgnore here - CollectFilesFromFolder already filters
        for cf in collected
            allFiles.Push(cf)
    }

    return allFiles
}
