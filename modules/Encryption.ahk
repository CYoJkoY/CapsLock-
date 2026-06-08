#Requires AutoHotkey v2.0

CryptBuffer(buf) {
    local key := ENCRYPT_KEY
    local len := buf.Size

    loop len {
        local offset := A_Index - 1
        NumPut("UChar", NumGet(buf, offset, "UChar") ^ key, buf, offset)
    }

    return buf
}
