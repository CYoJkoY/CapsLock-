#Requires AutoHotkey v2.0

Base64EncodeBuffer(buffer, size := "", urlSafe := false) {
    if size == ""
        size := buffer.Size
    if size <= 0
        return ""

    alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    result := ""
    i := 0

    while i < size {
        b1 := NumGet(buffer, i, "UChar")
        i++

        b2 := i < size ? NumGet(buffer, i, "UChar") : 0
        hasB2 := i < size
        if hasB2
            i++

        b3 := i < size ? NumGet(buffer, i, "UChar") : 0
        hasB3 := i < size
        if hasB3
            i++

        result .= SubStr(alphabet, (b1 >> 2) + 1, 1)
        result .= SubStr(alphabet, (((b1 & 0x03) << 4) | (b2 >> 4)) + 1, 1)
        result .= hasB2
            ? SubStr(alphabet, (((b2 & 0x0F) << 2) | (b3 >> 6)) + 1, 1)
            : "="
        result .= hasB3
            ? SubStr(alphabet, (b3 & 0x3F) + 1, 1)
            : "="
    }

    if urlSafe {
        result := StrReplace(result, "+", "-")
        result := StrReplace(result, "/", "_")
        result := RTrim(result, "=")
    }

    return result
}

Base64EncodeText(text, urlSafe := false) {
    size := StrPut(String(text), "UTF-8") - 1
    buffer := Buffer(Max(size, 1), 0)
    if size > 0
        StrPut(String(text), buffer, "UTF-8")
    return Base64EncodeBuffer(buffer, size, urlSafe)
}

Base64DecodeToBuffer(text, urlSafe := false) {
    text := String(text)
    if urlSafe {
        text := StrReplace(text, "-", "+")
        text := StrReplace(text, "_", "/")
        switch Mod(StrLen(text), 4) {
            case 2: text .= "=="
            case 3: text .= "="
        }
    }

    clean := RegExReplace(text, "\s+", "")
    if clean == "" || clean ~= "[^A-Za-z0-9+/=]"
        throw Error("Invalid Base64 text.")

    padding := 0
    if SubStr(clean, -1) == "="
        padding++
    if SubStr(clean, -2) == "="
        padding++

    dataLength := Floor(StrLen(clean) / 4) * 3 - padding
    buffer := Buffer(Max(dataLength, 1), 0)

    alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    outIndex := 0

    Loop StrLen(clean) // 4 {
        offset := (A_Index - 1) * 4
        c1 := InStr(alphabet, SubStr(clean, offset + 1, 1)) - 1
        c2 := InStr(alphabet, SubStr(clean, offset + 2, 1)) - 1
        c3Char := SubStr(clean, offset + 3, 1)
        c4Char := SubStr(clean, offset + 4, 1)

        c3 := c3Char == "=" ? 0 : InStr(alphabet, c3Char) - 1
        c4 := c4Char == "=" ? 0 : InStr(alphabet, c4Char) - 1

        if c1 < 0 || c2 < 0 || c3 < 0 || c4 < 0
            throw Error("Invalid Base64 character.")

        if outIndex < dataLength
            NumPut("UChar", (c1 << 2) | (c2 >> 4), buffer, outIndex++)
        if outIndex < dataLength
            NumPut("UChar", ((c2 & 0x0F) << 4) | (c3 >> 2), buffer, outIndex++)
        if outIndex < dataLength
            NumPut("UChar", ((c3 & 0x03) << 6) | c4, buffer, outIndex++)
    }

    return buffer
}

Base64DecodeText(text, urlSafe := false) {
    buffer := Base64DecodeToBuffer(text, urlSafe)
    if buffer.Size == 0
        return ""
    return StrGet(buffer, buffer.Size, "UTF-8")
}
