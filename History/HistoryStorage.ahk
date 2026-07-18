#Requires AutoHotkey v2.0

class HistoryManager {
    static savePending := false
    static saveTimer := ""

    static Load() {
        if AppState.MaxHistory == 0 {
            AppState.History := []
            return
        }

        if !FileExist( AppState.HistoryFile )
            return

        history := FileOpen( AppState.HistoryFile, "r" )
        if !IsObject( history )
            return

        try {
            count := history.ReadInt()
            if count <= 0 {
                history.Close()
                return
            }

            list := []
            loop count {
                size := history.ReadInt()
                if size <= 0
                    break

                buf := Buffer( size )
                if history.RawRead( buf, size ) != size
                    break

                CryptBuffer( buf )
                p := 0
                timeLen := NumGet( buf, p, "Int" ), p += 4
                timeStr := StrGet( buf.Ptr + p, timeLen, "UTF-8" ), p += timeLen
                srcLen := NumGet( buf, p, "Int" ), p += 4
                srcStr := StrGet( buf.Ptr + p, srcLen, "UTF-8" ), p += srcLen
                txtLen := NumGet( buf, p, "Int" ), p += 4
                txtStr := StrGet( buf.Ptr + p, txtLen, "UTF-8" )
                list.Push( Map( "time", timeStr, "source", srcStr, "text", txtStr ) )
            }
        } catch {
            list := []
        }
        history.Close()
        while list.Length > AppState.MaxHistory
            list.Pop()
        AppState.History := list
    }

    static ScheduleSave() {
        if this.saveTimer
            SetTimer( this.saveTimer, 0 )
        this.savePending := true
        this.saveTimer := ObjBindMethod( this, "DoSave" )
        SetTimer( this.saveTimer, -2000 )
    }

    static DoSave() {
        if !this.savePending
            return

        this.savePending := false
        history := FileOpen( AppState.HistoryFile, "w" )
        if !IsObject( history )
            return

        history.WriteInt( AppState.History.Length )
        for item in AppState.History {
            timeBuf := Buffer( StrPut( item[ "time" ], "UTF-8" ) )
            StrPut( item[ "time" ], timeBuf, "UTF-8" )
            srcBuf := Buffer( StrPut( item[ "source" ], "UTF-8" ) )
            StrPut( item[ "source" ], srcBuf, "UTF-8" )
            txtBuf := Buffer( StrPut( item[ "text" ], "UTF-8" ) )
            StrPut( item[ "text" ], txtBuf, "UTF-8" )

            total := 4 + timeBuf.Size + 4 + srcBuf.Size + 4 + txtBuf.Size
            buf := Buffer( total )
            p := 0
            NumPut( "Int", timeBuf.Size, buf, p ), p += 4
            DllCall( "RtlMoveMemory", "Ptr", buf.Ptr + p, "Ptr", timeBuf.Ptr, "Ptr", timeBuf.Size ), p += timeBuf.Size
            NumPut( "Int", srcBuf.Size, buf, p ), p += 4
            DllCall( "RtlMoveMemory", "Ptr", buf.Ptr + p, "Ptr", srcBuf.Ptr, "Ptr", srcBuf.Size ), p += srcBuf.Size
            NumPut( "Int", txtBuf.Size, buf, p ), p += 4
            DllCall( "RtlMoveMemory", "Ptr", buf.Ptr + p, "Ptr", txtBuf.Ptr, "Ptr", txtBuf.Size )

            CryptBuffer( buf )
            history.WriteInt( buf.Size )
            history.RawWrite( buf, buf.Size )
        }

        history.Close()
    }

    static Add( text, source := "Manual Copy" ) {
        if AppState.IgnoreNextClipChange {
            AppState.IgnoreNextClipChange := false
            return
        }

        if text == ""
            return

        if AppState.History.Length > 0 && AppState.History[ 1 ][ "text" ] == text
            return

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss" )
        item := Map( "text", text, "source", source, "time", timestamp, "process", "" )

        for index, existing in AppState.History {
            if existing[ "text" ] == text {
                AppState.History.RemoveAt( index )
                break
            }
        }

        AppState.History.InsertAt( 1, item )
        while AppState.History.Length > AppState.MaxHistory
            AppState.History.Pop()

        this.ScheduleSave()
    }

    static Delete( index ) {
        if index <= AppState.History.Length {
            AppState.History.RemoveAt( index )
            this.ScheduleSave()
        }
    }

    static Get( index ) {
        if index <= AppState.History.Length
            return AppState.History[ index ]
        return ""
    }

    static ForceSave() {
        if this.saveTimer
            SetTimer( this.saveTimer, 0 )
        if this.savePending
            this.DoSave()
    }
}

ClipboardChanged( DataType ) {
    global AppState, HistoryManager
    if AppState.IgnoreNextClipChange {
        AppState.IgnoreNextClipChange := false
        return
    }

    if DataType != 1
        return

    text := A_Clipboard
    if InStr( text, A_Temp "\ClipTemp_" )
        return

    AppState.LastManualClipboard := text
    if AppState.MaxHistory == 0
        return

    try sourceTitle := WinGetTitle( "A" )
    catch
        sourceTitle := "Unknown Window"

    HistoryManager.Add( text, sourceTitle )
}
