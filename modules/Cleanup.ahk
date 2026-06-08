#Requires AutoHotkey v2.0

ScheduleFileDeletion(filePath) {
    global DeleteMode, DeleteDelay, PendingCleanupFiles, BatchCleanupTimer

    if (DeleteMode = 1) {
        SetTimer(() => (FileExist(filePath) ? FileDelete(filePath) : ""), -DeleteDelay * 1000)
    }
    else if (DeleteMode = 2) {
        PendingCleanupFiles.Push(filePath)

        if (BatchCleanupTimer = "") {
            BatchCleanupTimer := SetTimer(PerformBatchCleanup, CleanupInterval * 1000)
        }
    }
    ; Mode 3: Do nothing, never delete
}

PerformBatchCleanup() {
    global PendingCleanupFiles, BatchCleanupTimer

    newList := []

    for path in PendingCleanupFiles {
        if FileExist(path) {
            try FileDelete(path)

            if FileExist(path)
                newList.Push(path)
        }
    }

    PendingCleanupFiles := newList

    if (PendingCleanupFiles.Length = 0 && BatchCleanupTimer != "") {
        SetTimer(BatchCleanupTimer, 0)
        BatchCleanupTimer := ""
    }
}
