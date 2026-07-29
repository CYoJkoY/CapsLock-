#Requires AutoHotkey v2.0

_SafeReadString(buf, &p, declaredLen, bufSize) {
    if (declaredLen <= 0 || declaredLen > 10485760) {
        return ""
    }

    currentOffset := p

    if (currentOffset + declaredLen > bufSize) {
        return ""
    }

    firstByte := NumGet(buf.Ptr + currentOffset, "UChar")
    if (firstByte == 0 || firstByte > 240) {
        return ""
    }

    str := StrGet(buf.Ptr + currentOffset, declaredLen, "UTF-8")
    p := currentOffset + declaredLen

    return str
}

_SafeReadInt(buf, &p, bufSize, minVal := -2147483648, maxVal := 2147483647) {
    if (p + 4 > bufSize) {
        return -1
    }

    val := NumGet(buf, p, "Int")
    p += 4

    if (val < minVal || val > maxVal) {
        return -1
    }

    return val
}

class HistoryManager {
    static savePending := false
    static saveTimer := ""

    static Load() {
        if AppState.MaxHistory == 0 {
            AppState.History := []
            return
        }

        if !FileExist(AppState.HistoryFile)
            return

        history := FileOpen(AppState.HistoryFile, "r")
        if !IsObject(history) {
            try FileMove(AppState.HistoryFile, AppState.HistoryFile ".corrupt", true)
            catch
            return
        }

        try {
            count := history.ReadInt()
            if (count <= 0 || count > 100000) {
                history.Close()
                return
            }

            list := []
            Loop count {
                size := history.ReadInt()
                if (size <= 0 || size > 10485760) {
                    list := []
                    break
                }

                buf := Buffer(size)
                if history.RawRead(buf, size) != size {
                    list := []
                    break
                }

                CryptBuffer(buf)

                bufSize := buf.Size
                p := 0

                timeLen := _SafeReadInt(buf, &p, bufSize, 0, 100)
                if (timeLen < 0) {
                    list := []
                    break
                }
                timeStr := _SafeReadString(buf, &p, timeLen, bufSize)
                if (timeStr == "") {
                    list := []
                    break
                }

                srcLen := _SafeReadInt(buf, &p, bufSize, 0, 1000)
                if (srcLen < 0) {
                    list := []
                    break
                }
                srcStr := _SafeReadString(buf, &p, srcLen, bufSize)
                if (srcStr == "") {
                    list := []
                    break
                }

                txtLen := _SafeReadInt(buf, &p, bufSize, 0, 10485760)
                if (txtLen < 0) {
                    list := []
                    break
                }
                txtStr := _SafeReadString(buf, &p, txtLen, bufSize)
                if (txtStr == "") {
                    list := []
                    break
                }

                if (!RegExMatch(timeStr, "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")) {
                    list := []
                    break
                }

                list.Push(Map("time", timeStr, "source", srcStr, "text", txtStr))
            }
        } catch {
            list := []
        }

        history.Close()

        if (list.Length == 0 && count > 0) {
            try {
                FileMove(AppState.HistoryFile, AppState.HistoryFile ".corrupt", true)
            } catch {
            }
        }

        while list.Length > AppState.MaxHistory
            list.Pop()
        AppState.History := list
    }

    static ScheduleSave() {
        if this.saveTimer
            SetTimer(this.saveTimer, 0)

        this.savePending := true
        this.saveTimer := ObjBindMethod(this, "DoSave")

        SetTimer(this.saveTimer, -2000)
    }

    static DoSave() {
        if !this.savePending
            return
        this.savePending := false

        tempBuf := Buffer(0)
        totalWritten := 0

        estimatedSize := 4
        for item in AppState.History {
            estimatedSize += 4 + StrPut(item["time"], "UTF-8")
            estimatedSize += 4 + StrPut(item["source"], "UTF-8")
            estimatedSize += 4 + StrPut(item["text"], "UTF-8")
        }

        outBuf := Buffer(estimatedSize)
        p := 0
        NumPut("Int", AppState.History.Length, outBuf, p)
        p += 4

        validItems := 0
        for item in AppState.History {
            singleSize := 0
            timeBuf := Buffer(StrPut(item["time"], "UTF-8"))
            StrPut(item["time"], timeBuf, "UTF-8")
            srcBuf := Buffer(StrPut(item["source"], "UTF-8"))
            StrPut(item["source"], srcBuf, "UTF-8")
            txtBuf := Buffer(StrPut(item["text"], "UTF-8"))
            StrPut(item["text"], txtBuf, "UTF-8")

            singleSize := 4 + timeBuf.Size + 4 + srcBuf.Size + 4 + txtBuf.Size

            NumPut("Int", singleSize, outBuf, p)
            p += 4
            NumPut("Int", timeBuf.Size, outBuf, p)
            p += 4
            DllCall("RtlMoveMemory", "Ptr", outBuf.Ptr + p, "Ptr", timeBuf.Ptr, "Ptr", timeBuf.Size)
            p += timeBuf.Size
            NumPut("Int", srcBuf.Size, outBuf, p)
            p += 4
            DllCall("RtlMoveMemory", "Ptr", outBuf.Ptr + p, "Ptr", srcBuf.Ptr, "Ptr", srcBuf.Size)
            p += srcBuf.Size
            NumPut("Int", txtBuf.Size, outBuf, p)
            p += 4
            DllCall("RtlMoveMemory", "Ptr", outBuf.Ptr + p, "Ptr", txtBuf.Ptr, "Ptr", txtBuf.Size)
            p += txtBuf.Size

            validItems++
        }

        NumPut("Int", validItems, outBuf, 0)

        CryptBuffer(outBuf)

        history := FileOpen(AppState.HistoryFile ".tmp", "w")
        if !IsObject(history)
            return
        history.RawWrite(outBuf, p)
        history.Close()

        try {
            FileDelete(AppState.HistoryFile)
            FileMove(AppState.HistoryFile ".tmp", AppState.HistoryFile)
        } catch {
        }
    }

    static Add(text, source := "Manual Copy") {
        if AppState.IgnoreNextClipChange {
            AppState.IgnoreNextClipChange := false
            return
        }

        if text == ""
            return

        if AppState.History.Length > 0 && AppState.History[1]["text"] == text
            return

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        item := Map("time", timestamp, "source", source, "text", text)

        for index, existing in AppState.History {
            if existing["text"] == text {
                AppState.History.RemoveAt(index)
                break
            }
        }

        AppState.History.InsertAt(1, item)

        while AppState.History.Length > AppState.MaxHistory
            AppState.History.Pop()

        this.ScheduleSave()
    }

    static Delete(index) {
        if index <= AppState.History.Length {
            AppState.History.RemoveAt(index)
            this.ScheduleSave()
        }
    }

    static Get(index) {
        if index <= AppState.History.Length
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
