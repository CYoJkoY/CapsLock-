#Requires AutoHotkey v2.0

ProcessImagePathsToPDF() {
    exe := AppState.ImageMagickExe
    if exe == "" || !FileExist(exe) {
        MsgBox(Lang("MSG_IMAGEMAGICK_ERROR"), Lang("MSG_ERROR"), "Iconx")
        return ""
    }

    paths := []
    lines := StrSplit(A_Clipboard, "`n", "`r")
    for line in lines {
        line := Trim(line)
        if line != "" && FileExist(line) && !InStr(FileExist(line), "D") {
            if FileHelper.ShouldIgnore(line)
                continue
            paths.Push(line)
        }
    }

    if paths.Length == 0 {
        ShowToolTip(Lang("MSG_NO_IMAGE_FILES"), 2000)
        return ""
    }

    outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"

    static MAX_RESIZE   := "1600x>"
    static DENSITY      := 150
    static COMPRESS     := "Zip"
    static BATCH_SIZE   := 25
    static JPEG_QUALITY := 92
    static MAX_MERGE_BATCH := 15

    _QuotedJoin(arr) {
        s := ""
        for p in arr
            s .= '"' p '" '
        return Trim(s)
    }

    _RunAndCheck(cmd, &exitCode) {
        try {
            logFile := A_Temp "\ClipTemp_log_" A_TickCount ".txt"
            fullCmd := Format('{} >"{}" 2>&1', cmd, logFile)
            exitCode := RunWait(fullCmd, , "Hide")
            return exitCode == 0
        } catch as err {
            exitCode := -1
            return false
        }
    }

    _GetFileSize(path) {
        try {
            return FileGetSize(path)
        } catch {
            return -1
        }
    }

    _RunBatch(imgPaths, outPath, useJpeg := false) {
        compress := useJpeg ? "JPEG" : COMPRESS
        quality  := useJpeg ? " -quality " JPEG_QUALITY : ""
        cmd := Format('"{}" {} -resize "{}" -density {} -compress {}{} "{}"',
            exe, _QuotedJoin(imgPaths), MAX_RESIZE, DENSITY, compress, quality, outPath)
        exitCode := -1
        success := _RunAndCheck(cmd, &exitCode)
        return success && FileExist(outPath) && _GetFileSize(outPath) > 0
    }

    _CascadeMerge(pdfList, outputPath) {
        if pdfList.Length == 0
            return false
        if pdfList.Length == 1 {
            try {
                FileCopy(pdfList[1], outputPath, 1)
                return FileExist(outputPath) && _GetFileSize(outputPath) > 0
            } catch {
                return false
            }
        }

        validPdfs := []
        for p in pdfList {
            if FileExist(p) && _GetFileSize(p) > 0
                validPdfs.Push(p)
            else
                return false
        }

        level := 1
        current := validPdfs.Clone()
        tempFiles := []

        while current.Length > 1 {
            nextLevel := []
            batchCount := Ceil(current.Length / MAX_MERGE_BATCH)

            Loop batchCount {
                start := (A_Index - 1) * MAX_MERGE_BATCH + 1
                end := Min(A_Index * MAX_MERGE_BATCH, current.Length)

                batch := []
                Loop end - start + 1
                    batch.Push(current[start + A_Index - 1])

                if batch.Length == 1 {
                    nextLevel.Push(batch[1])
                    continue
                }

                tempMerge := A_Temp "\ClipTemp_merge_lvl" level "_" A_Index "_" A_TickCount ".pdf"
                mergeCmd := Format('"{}" {} "{}"', exe, _QuotedJoin(batch), tempMerge)

                exitCode := -1
                if !_RunAndCheck(mergeCmd, &exitCode) || !FileExist(tempMerge) || _GetFileSize(tempMerge) <= 0 {
                    for tf in tempFiles
                        try FileDelete(tf)
                    return false
                }

                nextLevel.Push(tempMerge)
                tempFiles.Push(tempMerge)
            }

            current := nextLevel
            level++
        }

        try {
            if FileExist(outputPath)
                FileDelete(outputPath)
            FileMove(current[1], outputPath, 1)
            for tf in tempFiles {
                if tf != outputPath
                    try FileDelete(tf)
            }
            return FileExist(outputPath) && _GetFileSize(outputPath) > 0
        } catch {
            for tf in tempFiles
                try FileDelete(tf)
            return false
        }
    }

    if paths.Length <= BATCH_SIZE {
        if _RunBatch(paths, outputPdf, false) {
            ShowToolTip(Lang("MSG_IMAGE_PDF_SUCCESS"), 2000)
            return outputPdf
        }

        ShowToolTip(Lang("MSC_PNG2PDF_FAILED"), 1500)
        if _RunBatch(paths, outputPdf, true) {
            ShowToolTip(Lang("MSG_IMAGE_PDF_SUCCESS"), 2000)
            return outputPdf
        }

        ShowToolTip(Lang("MSG_PDF_IM_ERROR"), 2000)
        return ""
    }

    tempPdfs := []
    batchCount := Ceil(paths.Length / BATCH_SIZE)
    failedBatches := 0

    Loop batchCount {
        batchNum := A_Index
        start := (batchNum - 1) * BATCH_SIZE + 1
        end := Min(batchNum * BATCH_SIZE, paths.Length)

        batchPaths := []
        Loop end - start + 1
            batchPaths.Push(paths[start + A_Index - 1])

        tempPdf := A_Temp "\ClipTemp_batch_" A_TickCount "_" batchNum ".pdf"

        success := _RunBatch(batchPaths, tempPdf, false)
        if !success
            success := _RunBatch(batchPaths, tempPdf, true)

        if success {
            if FileExist(tempPdf) && _GetFileSize(tempPdf) > 0 {
                tempPdfs.Push(tempPdf)
            } else {
                failedBatches++
                try FileDelete(tempPdf)
            }
        } else {
            failedBatches++
            try FileDelete(tempPdf)
        }

        ShowToolTip(
            Lang("MSG_PDF_PROGRESS", , batchNum, batchCount, tempPdfs.Length, failedBatches),
            800
        )
    }

    if tempPdfs.Length == 0 {
        ShowToolTip(Lang("MSG_PDF_IM_ERROR"), 2000)
        return ""
    }

    ShowToolTip(Lang("MSG_MERGEING_PDF_BATCHES", , tempPdfs.Length), 1500)

    mergeSuccess := _CascadeMerge(tempPdfs, outputPdf)

    for tp in tempPdfs {
        if tp != outputPdf
            try FileDelete(tp)
    }

    if mergeSuccess && FileExist(outputPdf) && _GetFileSize(outputPdf) > 0 {
        ShowToolTip(Lang("MSG_IMAGE_PDF_SUCCESS"), 2000)
        return outputPdf
    }

    ShowToolTip(Lang("MSG_PDF_IM_ERROR"), 2000)
    try FileDelete(outputPdf)
    return ""
}
