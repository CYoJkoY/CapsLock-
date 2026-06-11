#Requires AutoHotkey v2.0

LoadHistory() {
    global clipboardHistory, maxHistory, historyFile

    if ( maxHistory = 0 ) {
        clipboardHistory := []
        return
    }
    if !FileExist( historyFile ) {
        return
    }
    history := FileOpen( historyFile, "r" )
    if !IsObject( history ) {
        return
    }
    arrayLen := history.ReadInt()
    if ( arrayLen = "" || arrayLen < 0 ) {
        history.Close()
        return
    }
    historylist := []
    loop arrayLen {
        strLenBytes := history.ReadInt()
        if ( strLenBytes = "" || strLenBytes <= 0 ) {
            break
        }
        buf := Buffer( strLenBytes )
        if ( history.RawRead( buf, strLenBytes ) != strLenBytes ) {
            break
        }
        CryptBuffer( buf )
        try {
            line := StrGet( buf, "UTF-8" )
            pos1 := InStr( line, " | " )
            if ( pos1 > 0 ) {
                timeStr := SubStr( line, 1, pos1 - 1 )
                rest := SubStr( line, pos1 + 3 )
                pos2 := InStr( rest, " | " )
                if ( pos2 > 0 ) {
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
            item := Map()
            item[ "time" ] := timeStr
            item[ "source" ] := sourceStr
            item[ "text" ] := textStr
            historylist.Push( item )
        } catch {
            try {
                text := StrGet( buf, "UTF-8" )
                item := Map()
                item[ "time" ] := ""
                item[ "source" ] := "Legacy Entry"
                item[ "text" ] := text
                historylist.Push( item )
            } catch {
                break
            }
        }
    }
    history.Close()

    while ( historylist.Length > maxHistory ) {
        historylist.Pop()
    }
    clipboardHistory := historylist
}

SaveHistory() {
    global clipboardHistory, historyFile

    history := FileOpen( historyFile, "w" )
    if !IsObject( history ) {
        return
    }
    history.WriteInt( clipboardHistory.Length )
    for item in clipboardHistory {
        line := item[ "time" ] " | " item[ "source" ] " | " item[ "text" ]
        buf := Buffer( StrPut( line, "UTF-8" ) - 1 )
        StrPut( line, buf, "UTF-8" )
        CryptBuffer( buf )
        history.WriteInt( buf.Size )
        history.RawWrite( buf, buf.Size )
    }
    history.Close()
}

AddToHistory( text, source := "Manual Copy" ) {
    global clipboardHistory, maxHistory, ignoreNextClipChange

    if ( ignoreNextClipChange ) {
        ignoreNextClipChange := false
        return
    }
    if ( text == "" ) {
        return
    }
    if ( clipboardHistory.Length > 0 && clipboardHistory[ 1 ][ "text" ] == text ) {
        return
    }
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss" )
    historyItem := Map()
    historyItem[ "text" ] := text
    historyItem[ "source" ] := source
    historyItem[ "process" ] := ""
    historyItem[ "time" ] := timestamp

    clipboardHistory.InsertAt( 1, historyItem )
    while ( clipboardHistory.Length > maxHistory ) {
        clipboardHistory.Pop()
    }
    SaveHistory()
}

HandleHistoryUpdate( DataType ) {
    global clipboardHistory, maxHistory, lastManualClipboard, ignoreNextClipChange

    if ( ignoreNextClipChange ) {
        ignoreNextClipChange := false
        return
    }
    if ( DataType != 1 ) {
        return
    }
    text := A_Clipboard
    if InStr( text, A_Temp "\ClipTemp_" ) {
        return
    }
    lastManualClipboard := text
    if ( maxHistory = 0 ) {
        return
    }
    try {
        sourceTitle := WinGetTitle( "A" )
    } catch {
        sourceTitle := "Unknown Window"
    }
    try {
        sourceProcess := WinGetProcessName( "A" )
    } catch {
        sourceProcess := "Unknown Process"
    }
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss" )
    historyItem := Map()
    historyItem[ "text" ] := text
    historyItem[ "source" ] := sourceTitle
    historyItem[ "process" ] := sourceProcess
    historyItem[ "time" ] := timestamp

    ; 移除重复项（保留最新）
    for index, item in clipboardHistory {
        if ( item[ "text" ] == text ) {
            clipboardHistory.RemoveAt( index )
            break
        }
    }
    clipboardHistory.InsertAt( 1, historyItem )
    while ( clipboardHistory.Length > maxHistory ) {
        clipboardHistory.Pop()
    }
    SaveHistory()
}
