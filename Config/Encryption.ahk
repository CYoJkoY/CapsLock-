#Requires AutoHotkey v2.0

CryptBuffer( buf ) {
    key := AppState.ENCRYPT_KEY
    loop buf.Size {
        offset := A_Index - 1
        NumPut( "UChar", NumGet( buf, offset, "UChar" ) ^ key, buf, offset )
    }
    return buf
}
