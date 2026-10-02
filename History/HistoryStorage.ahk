#Requires AutoHotkey v2.0

class HistoryManager {
    static savePending := false
    static saveTimer := ""
    static revision := 0

    ; Snapshot replacement is lazy: even Load() at startup never starts .NET.
    static Replaced() {
        this.revision++
        Services.InvalidateHistory(true)
    }

    static Load() {
        if AppState.MaxHistory == 0 {
            AppState.History := []
            this.Replaced()
            return
        }

        if !FileExist(AppState.HistoryFile)
            return

        history := FileOpen(AppState.HistoryFile, "r")
        if !IsObject(history)
            return

        try {
            count := history.ReadInt()

            if count <= 0 {
                history.Close()
                if count == 0 {
                    AppState.History := []
                    this.Replaced()
                }
                return
            }

            list := []

            Loop count {
                size := history.ReadInt()

                if size <= 0
                    break

                buf := Buffer(size)

                if history.RawRead(buf, size) != size
                    break

                CryptBuffer(buf)

                p := 0

                timeLen := NumGet(buf, p, "Int"), p += 4
                timeStr := StrGet(buf.Ptr + p, timeLen, "UTF-8"), p += timeLen

                srcLen := NumGet(buf, p, "Int"), p += 4
                srcStr := StrGet(buf.Ptr + p, srcLen, "UTF-8"), p += srcLen

                txtLen := NumGet(buf, p, "Int"), p += 4
                txtStr := StrGet(buf.Ptr + p, txtLen, "UTF-8")

                list.Push(Map("time", timeStr, "source", srcStr, "text", txtStr))
            }
        } catch {
            list := []
        }

        history.Close()

        while list.Length > AppState.MaxHistory
            list.Pop()

        AppState.History := list
        this.Replaced()
    }

    static ScheduleSave() {
        if this.saveTimer
            SetTimer(this.saveTimer, 0)

        this.savePending := true
        this.saveTimer := ObjBindMethod(this, "DoSave")

        ; Extended debounce from 2000ms to 3000ms to reduce disk I/O
        ; during rapid clipboard operations. ForceSave() is called on exit
        ; so no data is lost.
        SetTimer(this.saveTimer, -3000)
    }

    static DoSave() {
        if !this.savePending
            return

        this.savePending := false

        history := FileOpen(AppState.HistoryFile, "w")
        if !IsObject(history)
            return

        history.WriteInt(AppState.History.Length)

        for item in AppState.History {
            timeStr := item["time"]
            srcStr := item["source"]
            txtStr := item["text"]

            ; Measure string sizes with StrPut
            timeSize := StrPut(timeStr, "UTF-8")
            srcSize := StrPut(srcStr, "UTF-8")
            txtSize := StrPut(txtStr, "UTF-8")

            ; Build buffer directly with StrPut (no intermediate buffers or RtlMoveMemory)
            total := 4 + timeSize + 4 + srcSize + 4 + txtSize
            buf := Buffer(total, 0)

            p := 0
            NumPut("Int", timeSize, buf, p), p += 4
            StrPut(timeStr, buf.Ptr + p, timeSize, "UTF-8"), p += timeSize
            NumPut("Int", srcSize, buf, p), p += 4
            StrPut(srcStr, buf.Ptr + p, srcSize, "UTF-8"), p += srcSize
            NumPut("Int", txtSize, buf, p), p += 4
            StrPut(txtStr, buf.Ptr + p, txtSize, "UTF-8")

            CryptBuffer(buf)

            history.WriteInt(buf.Size)
            history.RawWrite(buf, buf.Size)
        }

        history.Close()
    }

    static Add(text, source := "Manual Copy") {
        if AppState.IgnoreNextClipChange {
            AppState.IgnoreNextClipChange := false
            return
        }

        if text == ""
            return

        ; Fast check: most common duplicate case is the most recent entry
        if AppState.History.Length > 0 && AppState.History[1]["text"] == text
            return

        ; C# keeps a resident hash/ring index; only the candidate crosses on
        ; warm calls. The AHK fallback retains the original reverse scan.
        previousRevision := this.revision
        idx := Services.HistoryFindDuplicate(text)
        ; A timer/clipboard event may have edited history during a cold boot.
        if previousRevision != this.revision
            idx := ServicesHistoryFindDuplicateResidentAhk(text)
        previousRevision := this.revision
        if idx > 0
            AppState.History.RemoveAt(idx)

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        item := Map("time", timestamp, "source", source, "text", text)

        AppState.History.InsertAt(1, item)

        while AppState.History.Length > AppState.MaxHistory
            AppState.History.Pop()

        this.revision++
        Services.HistoryAdded(text, idx, AppState.MaxHistory, previousRevision)
        this.ScheduleSave()
    }

    static Delete(index) {
        if index >= 1 && index <= AppState.History.Length {
            previousRevision := this.revision
            AppState.History.RemoveAt(index)
            this.revision++
            Services.HistoryDeleted(index, previousRevision)
            this.ScheduleSave()
        }
    }

    ; All limit changes and auto-cleaning go through this path so the resident
    ; index and the GUI's incremental-search cache cannot become stale.
    static Trim(limit) {
        limit := Max(0, Integer(limit))
        if AppState.History.Length <= limit
            return
        previousRevision := this.revision
        while AppState.History.Length > limit
            AppState.History.Pop()
        this.revision++
        Services.HistoryTrimmed(limit, previousRevision)
        this.ScheduleSave()
    }

    static Get(index) {
        if index >= 1 && index <= AppState.History.Length
            return AppState.History[index]

        return ""
    }

    static ForceSave() {
        if this.saveTimer
            SetTimer(this.saveTimer, 0)

        if this.savePending
            this.DoSave()
    }
}

ClipboardChanged(DataType) {
    if AppState.IgnoreNextClipChange {
        AppState.IgnoreNextClipChange := false
        return
    }

    if DataType != 1
        return

    text := A_Clipboard

    if InStr(text, A_Temp "\ClipTemp_")
        return

    AppState.LastManualClipboard := text

    if AppState.MaxHistory == 0
        return

    try sourceTitle := WinGetTitle("A")
    catch
        sourceTitle := "Unknown Window"

    HistoryManager.Add(text, sourceTitle)
}
