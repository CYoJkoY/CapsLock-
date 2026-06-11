#Requires AutoHotkey v2.0

CopyAsPlainTextAndAddToHistory() {
    global IgnoreNextClipChange

    IgnoreNextClipChange := true
    text := CopyAsPlainText()
    IgnoreNextClipChange := false
    if ( text != "" ) {
        AddToHistory( text, "Plain Text Copy" )
    }
}

PasteWithCurrentMode() {
    global LastManualClipboard, ClipboardHistory, IgnoreNextClipChange, PasteMode

    local current_clip := A_Clipboard
    local target_text := ( LastManualClipboard != "" ) ? LastManualClipboard : current_clip

    if ( target_text = "" ) {
        ToolTip( "Clipboard is empty, please copy content first" )
        SetTimer( () => ToolTip(), -2000 )
        return
    }

    if ( PasteMode = 2 && IsMultiFilePathText( target_text ) ) {
        local raw_paths := StrSplit( target_text, "`n", "`r" )
        local valid_paths := []
        for path in raw_paths {
            path := Trim( path )
            local attrs := FileExist( path )
            if ( path != "" && attrs != "" && !InStr( attrs, "D" ) ) {
                valid_paths.Push( path )
            }
        }
        if ( valid_paths.Length > 0 ) {
            local combined_text := ReadMultipleFilesAsText( valid_paths )
            local backup_clip := A_Clipboard
            A_Clipboard := combined_text
            Send( "^v" )
            Sleep( 50 )
            A_Clipboard := backup_clip
            ToolTip( "Pasted " valid_paths.Length " files as text" )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
    }

    if ( IsImagePathsText( target_text ) ) {
        local temp_pdf_path := ProcessImagePathsToPDF()
        if ( temp_pdf_path = "" ) {
            ToolTip( "Failed to create PDF" )
            SetTimer( () => ToolTip(), -2000 )
            return
        }
        PasteFile( temp_pdf_path, "pdf" )
        return
    }

    if ( current_clip != "" && !InStr( current_clip, A_Temp "\ClipTemp_" ) ) {
        LastManualClipboard := current_clip
    }

    local source_info := ""
    for item in ClipboardHistory {
        if ( item[ "text" ] = target_text ) {
            source_info := "Copied from: " item[ "source" ] " (at " item[ "time" ] ")"
            break
        }
    }
    if ( source_info = "" ) {
        source_info := "Source: (Direct Paste via Hotkey) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss" )
    }

    if ( PasteMode = 1 ) {
        local full_content := "; " source_info "`n`n" target_text
        local temp_file := A_Temp "\ClipTemp_" A_TickCount ".txt"
        FileAppend( full_content, temp_file, "UTF-8" )
        SetClipboardFile( temp_file )
        Send( "^v" )
        ScheduleFileDeletion( temp_file )
        SetTimer( () => ( LastManualClipboard != "" ) ? ( A_Clipboard := LastManualClipboard ) : "", -10000 )
    } else {
        local full_content := "; " source_info "`n`n" target_text
        local backup_clip := A_Clipboard
        A_Clipboard := full_content
        Send( "^v" )
        Sleep( 50 )
        A_Clipboard := backup_clip
    }
    SetTimer( () => ToolTip(), -2000 )
}

ChangeCaseOfLastCopy() {
    global LastManualClipboard, IgnoreNextClipChange

    sourceText := ( LastManualClipboard != "" ) ? LastManualClipboard : A_Clipboard
    if ( sourceText = "" ) {
        ToolTip( "No text to paste. Please copy something first." )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    if !RegExMatch( sourceText, "[a-zA-Z]", &match ) {
        ToolTip( "No English letters found" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    firstChar := match[ 0 ]
    newText := ( firstChar ~= "[A-Z]" ) ? StrLower( sourceText ) : StrUpper( sourceText )

    prevCapsState := GetKeyState( "CapsLock", "T" )
    if prevCapsState {
        SetCapsLockState( "AlwaysOff" )
    }

    IgnoreNextClipChange := true
    A_Clipboard := newText
    Send( "^v" )
    Sleep( 200 )

    IgnoreNextClipChange := true
    A_Clipboard := sourceText

    if prevCapsState {
        SetCapsLockState( "AlwaysOn" )
    }
}

ToggleAlwaysOnTopWithOSD() {
    hwnd := WinExist( "A" )
    WinSetAlwaysOnTop( -1, hwnd )
    isOnTop := WinGetExStyle( hwnd ) & 0x8
    if isOnTop {
        PlayResourceSound( "SND_ON" )
    } else {
        PlayResourceSound( "SND_OFF" )
    }
    ShowTopMostOSD( hwnd, isOnTop )
}
