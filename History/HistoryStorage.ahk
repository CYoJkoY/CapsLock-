#Requires AutoHotkey v2.0

class HistoryManager {
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
        arrayLen := history.ReadInt()
        if arrayLen == "" || arrayLen < 0 {
            history.Close()
            return
        }
        list := []
        loop arrayLen {
            strLenBytes := history.ReadInt()
            if strLenBytes == "" || strLenBytes <= 0
                break
            buf := Buffer( strLenBytes )
            if history.RawRead( buf, strLenBytes ) != strLenBytes
                break
            CryptBuffer( buf )
            try {
                line := StrGet( buf, "UTF-8" )
                pos1 := InStr( line, " | " )
                if pos1 > 0 {
                    timeStr := SubStr( line, 1, pos1 - 1 )
                    rest := SubStr( line, pos1 + 3 )
                    pos2 := InStr( rest, " | " )
                    if pos2 > 0 {
                        sourceStr := SubStr( rest, 1, pos2 - 1 )
                        textStr := SubStr( rest, pos2 + 3 )
                    } else {
                        sourceStr := "Unknown Source"
                        textStr := rest
                    }
                } else {
                    timeStr := ""
                    sourceStr := "Unknown Source"
                    textStr := line
                }
                item := Map( "time", timeStr, "source", sourceStr, "text", textStr )
                list.Push( item )
            } catch {
                try {
                    text := StrGet( buf, "UTF-8" )
                    list.Push( Map( "time", "", "source", "Legacy Entry", "text", text ) )
                } catch
                    break
            }
        }
        history.Close()
        while list.Length > AppState.MaxHistory
            list.Pop()
        AppState.History := list
    }

    static Save() {
        history := FileOpen( AppState.HistoryFile, "w" )
        if !IsObject( history )
            return
        history.WriteInt( AppState.History.Length )
        for item in AppState.History {
            line := item[ "time" ] " | " item[ "source" ] " | " item[ "text" ]
            buf := Buffer( StrPut( line, "UTF-8" ) - 1 )
            StrPut( line, buf, "UTF-8" )
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
        this.Save()
    }

    static Delete( index ) {
        if index <= AppState.History.Length {
            AppState.History.RemoveAt( index )
            this.Save()
        }
    }

    static Get( index ) {
        if index <= AppState.History.Length
            return AppState.History[ index ]
        return ""
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
