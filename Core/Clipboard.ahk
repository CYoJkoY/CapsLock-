#Requires AutoHotkey v2.0

class ClipboardHelper {
    static SetClipboardFile( filePath ) {
        static DROPFILES_SIZE := 20
        pathLen := StrLen( filePath )
        buf := Buffer( DROPFILES_SIZE + ( pathLen + 2 ) * 2, 0 )
        NumPut( "UInt", DROPFILES_SIZE, buf, 0 )
        NumPut( "UInt", 1, buf, 16 )
        StrPut( filePath, buf.Ptr + DROPFILES_SIZE, "UTF-16" )
        if !this.OpenClipboard()
            return

        DllCall( "EmptyClipboard" )
        hMem := DllCall( "GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr" )
        if !hMem {
            this.CloseClipboard()
            return
        }

        pMem := DllCall( "GlobalLock", "Ptr", hMem, "Ptr" )
        DllCall( "RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size )
        DllCall( "GlobalUnlock", "Ptr", hMem )

        if !DllCall( "SetClipboardData", "UInt", 0xF, "Ptr", hMem ) {
            DllCall( "GlobalFree", "Ptr", hMem )
        }

        this.CloseClipboard()
    }

    static SetClipboardFiles( fileArray ) {
        static DROPFILES_SIZE := 20
        totalBytes := DROPFILES_SIZE + 2
        for path in fileArray
            totalBytes += ( StrLen( path ) + 1 ) * 2

        buf := Buffer( totalBytes, 0 )
        NumPut( "UInt", DROPFILES_SIZE, buf, 0 )
        NumPut( "UInt", 1, buf, 16 )
        offset := DROPFILES_SIZE
        for path in fileArray {
            StrPut( path, buf.Ptr + offset, StrLen( path ) + 1, "UTF-16" )
            offset += ( StrLen( path ) + 1 ) * 2
        }

        if !this.OpenClipboard()
            return

        DllCall( "EmptyClipboard" )
        hMem := DllCall( "GlobalAlloc", "UInt", 0x42, "Ptr", buf.Size, "Ptr" )
        if !hMem {
            this.CloseClipboard()
            return
        }

        pMem := DllCall( "GlobalLock", "Ptr", hMem, "Ptr" )
        DllCall( "RtlMoveMemory", "Ptr", pMem, "Ptr", buf.Ptr, "Ptr", buf.Size )
        DllCall( "GlobalUnlock", "Ptr", hMem )

        if !DllCall( "SetClipboardData", "UInt", 0xF, "Ptr", hMem ) {
            DllCall( "GlobalFree", "Ptr", hMem )
        }

        this.CloseClipboard()
    }

    static ClearClipboard() {
        if this.OpenClipboard() {
            DllCall( "EmptyClipboard" )
            this.CloseClipboard()
        }
    }

    static CopyAsPlainText() {
        bak := ClipboardAll()
        A_Clipboard := ""
        Send( "^c" )
        if !ClipWait( 1 ) {
            A_Clipboard := bak
            return ""
        }
        text := A_Clipboard
        if text == "" {
            A_Clipboard := bak
            return ""
        }

        if InStr( text, "`n" ) && FileExist( StrSplit( text, "`n", "`r" )[ 1 ] ) {
            A_Clipboard := bak
            return ""
        }
        A_Clipboard := text
        return text
    }

    static OpenClipboard() {
        loop 3 {
            if DllCall( "OpenClipboard", "Ptr", A_ScriptHwnd )
                return true
            Sleep( 50 )
        }
        return false
    }

    static CloseClipboard() {
        DllCall( "CloseClipboard" )
    }
}
