#Requires AutoHotkey v2.0

class CleanupManager {
    static pending := Map()

    static ScheduleDeletion( filePath ) {
        if AppState.DeleteMode == 1 {
            if !IsObject( this.pending ) {
                this.pending := Map()
                SetTimer( this.ProcessDeletions.Bind( this ), 1000 )
            }
            this.pending[ filePath ] := A_TickCount + AppState.DeleteDelay * 1000
        } else if AppState.DeleteMode == 2 {
            AppState.PendingCleanup.Push( filePath )
            if AppState.CleanupTimer == "" {
                AppState.CleanupTimer := SetTimer( this.PerformBatchCleanup.Bind( this ), AppState.CleanupInterval * 1000 )
            }
        }
    }

    static ProcessDeletions() {
        if !IsObject( this.pending )
            return
        now := A_TickCount
        for path, timeout in this.pending.Clone() {
            if now >= timeout {
                try FileDelete( path )
                this.pending.Delete( path )
            }
        }
        if this.pending.Count == 0 {
            this.pending := ""
            SetTimer( this.ProcessDeletions, 0 )
        }
    }

    static PerformBatchCleanup() {
        newList := []
        for path in AppState.PendingCleanup {
            if FileExist( path ) {
                try FileDelete( path )
                if FileExist( path )
                    newList.Push( path )
            }
        }
        AppState.PendingCleanup := newList
        if AppState.PendingCleanup.Length == 0 && AppState.CleanupTimer != "" {
            SetTimer( AppState.CleanupTimer, 0 )
            AppState.CleanupTimer := ""
        }
    }

    static OnExit() {
        loop files, A_Temp "\ClipTemp_*", "F" {
            try FileDelete( A_LoopFileFullPath )
        }

        if IsObject( this.pending ) {
            for path in this.pending.Clone()
                try FileDelete( path )
            this.pending := ""
        }

        for path in AppState.PendingCleanup
            try FileDelete( path )
        AppState.PendingCleanup := []
    }
}
