#Requires AutoHotkey v2.0

CryptBuffer( buf ) {
    key := AppState.ENCRYPT_KEY
    ptr := buf.Ptr
    loop buf.Size {
        offset := A_Index - 1
        NumPut( "UChar", NumGet( ptr + offset, "UChar" ) ^ key, ptr + offset )
    }

    return buf
}
