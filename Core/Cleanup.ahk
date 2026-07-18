#Requires AutoHotkey v2.0

class CleanupManager {
    static pending := unset
    static pendingTimer := ""
    static scheduling := false

    static ScheduleDeletion( filePath ) {
        if AppState.DeleteMode == 1 {
            if !IsObject( this.pending ) {
                if this.scheduling
                    return

                scheduling := true
                this.pending := Map()
                this.pendingTimer := ObjBindMethod( this, "ProcessDeletions" )
                SetTimer( this.pendingTimer, 1000 )
            }

            this.pending[ filePath ] := A_TickCount + AppState.DeleteDelay * 1000

        } else if AppState.DeleteMode == 2 {
            AppState.PendingCleanup.Push( filePath )
            if AppState.CleanupTimer == "" {
                bound := ObjBindMethod( this, "PerformBatchCleanup" )
                AppState.CleanupTimer := bound
                SetTimer( bound, AppState.CleanupInterval * 1000 )
            }
        }

        scheduling := false
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
            this.pending := unset
            this.scheduling := false

            if this.pendingTimer != "" {
                SetTimer( this.pendingTimer, 0 )
                this.pendingTimer := ""
            }
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

        if this.pendingTimer != "" {
            SetTimer( this.pendingTimer, 0 )
            this.pendingTimer := ""
        }

        if AppState.CleanupTimer != "" {
            SetTimer( AppState.CleanupTimer, 0 )
            AppState.CleanupTimer := ""
        }

        loop files, A_Temp "\ClipTemp_*", "F"
            try FileDelete( A_LoopFileFullPath )

        if !IsObject( this.pending )
            for path in this.pending.Clone()
                try FileDelete( path )

        for path in AppState.PendingCleanup
            try FileDelete( path )
    }
}
