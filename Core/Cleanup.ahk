#Requires AutoHotkey v2.0

class CleanupManager {
    static _delayed := unset
    static _delayedTimer := ""
    static _batch := []
    static _batchTimer := ""
    static _starting := false

    static ScheduleDeletion(filePath) {
        if AppState.DeleteMode == 1 {
            if !IsObject(this._delayed) {
                if this._starting
                    return

                this._starting := true
                this._delayed := Map()
                this._delayedTimer := ObjBindMethod(this, "ProcessDelayed")
                SetTimer(this._delayedTimer, 1000)
            }

            this._delayed[filePath] := A_TickCount + AppState.DeleteDelay * 1000
        } else if AppState.DeleteMode == 2 {
            this._batch.Push(filePath)

            if this._batchTimer == "" {
                this._batchTimer := ObjBindMethod(this, "ProcessBatch")
                SetTimer(this._batchTimer, AppState.CleanupInterval * 1000)
            }
        }

        this._starting := false
    }

    static ProcessDelayed() {
        if !IsObject(this._delayed)
            return

        now := A_TickCount

        for path, timeout in this._delayed.Clone() {
            if now >= timeout {
                try FileDelete(path)
                this._delayed.Delete(path)
            }
        }

        if this._delayed.Count == 0 {
            this._delayed := unset

            if this._delayedTimer != "" {
                SetTimer(this._delayedTimer, 0)
                this._delayedTimer := ""
            }
        }
    }

    static ProcessBatch() {
        newList := []

        for path in this._batch {
            if FileExist(path) {
                try FileDelete(path)

                if FileExist(path)
                    newList.Push(path)
            }
        }

        this._batch := newList

        if this._batch.Length == 0 && this._batchTimer != "" {
            SetTimer(this._batchTimer, 0)
            this._batchTimer := ""
        }
    }

    static OnExit() {
        if this._delayedTimer != ""
            SetTimer(this._delayedTimer, 0)

        if this._batchTimer != ""
            SetTimer(this._batchTimer, 0)

        Loop Files, A_Temp "\ClipTemp_*", "F"
            try FileDelete(A_LoopFileFullPath)

        if IsObject(this._delayed) {
            for path in this._delayed.Clone()
                try FileDelete(path)
        }

        for path in this._batch
            try FileDelete(path)
    }
}
