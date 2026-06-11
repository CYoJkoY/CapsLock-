#Requires AutoHotkey v2.0

ScheduleFileDeletion( filePath ) {
    global deleteMode, deleteDelay, pendingCleanupFiles, batchCleanupTimer

    if ( deleteMode = 1 ) {
        SetTimer( () => ( FileExist( filePath ) ? FileDelete( filePath ) : "" ), -deleteDelay * 1000 )
    } else if ( deleteMode = 2 ) {
        pendingCleanupFiles.Push( filePath )
        if ( batchCleanupTimer = "" ) {
            batchCleanupTimer := SetTimer( PerformBatchCleanup, cleanupInterval * 1000 )
        }
    }
}

PerformBatchCleanup() {
    global pendingCleanupFiles, batchCleanupTimer

    newList := []
    for path in pendingCleanupFiles {
        if FileExist( path ) {
            try FileDelete( path )
            if FileExist( path ) {
                newList.Push( path )
            }
        }
    }
    pendingCleanupFiles := newList

    if ( pendingCleanupFiles.Length = 0 && batchCleanupTimer != "" ) {
        SetTimer( batchCleanupTimer, 0 )
        batchCleanupTimer := ""
    }
}
