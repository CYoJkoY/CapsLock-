#Requires AutoHotkey v2.0

Sha256(text) {
    text := String(text)
    dataSize := StrPut(text, "UTF-8") - 1
    data := Buffer(Max(dataSize, 1), 0)

    if dataSize > 0
        StrPut(text, data, "UTF-8")

    hAlg := 0
    hHash := 0
    objLength := 0
    cbResult := 0

    try {
        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptOpenAlgorithmProvider failed: 0x" Format("{:08X}", status))

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", hAlg,
            "WStr", "ObjectLength",
            "UInt*", &objLength,
            "UInt", 4,
            "UInt*", &cbResult,
            "UInt"
        )
        if status != 0
            throw Error("BCryptGetProperty failed: 0x" Format("{:08X}", status))

        hashObject := Buffer(objLength, 0)

        status := DllCall(
            "bcrypt\BCryptCreateHash",
            "Ptr", hAlg,
            "Ptr*", &hHash,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptCreateHash failed: 0x" Format("{:08X}", status))

        if dataSize > 0 {
            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", dataSize,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                throw Error("BCryptHashData failed: 0x" Format("{:08X}", status))
        }

        digest := Buffer(32, 0)
        status := DllCall(
            "bcrypt\BCryptFinishHash",
            "Ptr", hHash,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptFinishHash failed: 0x" Format("{:08X}", status))

        result := ""
        Loop digest.Size
            result .= Format("{:02x}", NumGet(digest, A_Index - 1, "UChar"))

        return result
    } finally {
        if hHash
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
        if hAlg
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}


Sha256Bytes(text) {
    text := String(text)
    dataSize := StrPut(text, "UTF-8") - 1
    data := Buffer(Max(dataSize, 1), 0)

    if dataSize > 0
        StrPut(text, data, "UTF-8")

    hAlg := 0
    hHash := 0
    objLength := 0
    cbResult := 0

    try {
        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptOpenAlgorithmProvider failed.")

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", hAlg,
            "WStr", "ObjectLength",
            "UInt*", &objLength,
            "UInt", 4,
            "UInt*", &cbResult,
            "UInt"
        )
        if status != 0
            throw Error("BCryptGetProperty failed.")

        hashObject := Buffer(objLength, 0)

        status := DllCall(
            "bcrypt\BCryptCreateHash",
            "Ptr", hAlg,
            "Ptr*", &hHash,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptCreateHash failed.")

        if dataSize > 0 {
            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", dataSize,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                throw Error("BCryptHashData failed.")
        }

        digest := Buffer(32, 0)
        status := DllCall(
            "bcrypt\BCryptFinishHash",
            "Ptr", hHash,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptFinishHash failed.")

        return digest
    } finally {
        if hHash
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
        if hAlg
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}


; SHA-256 of an in-memory Buffer, returned as lowercase hexadecimal text, or
; "" when hashing fails. Callers compare it against a hex digest from another
; source, so the letter case is part of the contract.
Sha256BufferHex(data, size := -1) {
    if !(data is Buffer)
        return ""

    if size < 0 || size > data.Size
        size := data.Size

    hAlg := 0
    hHash := 0
    objLength := 0
    cbResult := 0

    try {
        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptOpenAlgorithmProvider failed.")

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", hAlg,
            "WStr", "ObjectLength",
            "UInt*", &objLength,
            "UInt", 4,
            "UInt*", &cbResult,
            "UInt", 0
        )
        if status != 0
            throw Error("BCryptGetProperty failed.")

        hashObject := Buffer(objLength, 0)

        status := DllCall(
            "bcrypt\BCryptCreateHash",
            "Ptr", hAlg,
            "Ptr*", &hHash,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0
        )
        if status != 0
            throw Error("BCryptCreateHash failed.")

        if size > 0 {
            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", size,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                throw Error("BCryptHashData failed.")
        }

        digest := Buffer(32, 0)
        status := DllCall(
            "bcrypt\BCryptFinishHash",
            "Ptr", hHash,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            throw Error("BCryptFinishHash failed.")

        result := ""
        Loop digest.Size
            result .= Format("{:02x}", NumGet(digest, A_Index - 1, "UChar"))

        return result
    } catch {
        ; A hashing failure is never fatal for the caller: an empty digest
        ; simply does not match anything it is compared against.
        return ""
    } finally {
        if hHash
            DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
        if hAlg
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}


; SHA-256 of a file's raw bytes, lowercase hexadecimal text, or "" when the
; file cannot be read. Used to verify the AHK# bridge DLL against the digest
; pinned in the bridge's own source before the CLR is asked to load it.
;
; AutoHotkey v2 has no "RAW" file encoding: FileOpen accepts "UTF-8",
; "UTF-8-RAW", "UTF-16", "UTF-16-RAW", "CP0" and "CPnnn", and *throws*
; "Parameter #3 invalid" for anything else - a bare "RAW" included. Opening
; with CP0 is safe for RawRead because it performs no encoding or EOL
; translation; the Seek(0) matters because FileOpen skips a leading UTF BOM
; before the first read, and the digest must cover every byte of the file.
Sha256File(path) {
    try {
        if !FileExist(path)
            return ""

        file := FileOpen(path, "r", "CP0")
        try {
            size := file.Length
            if size <= 0 {
                return ""
            }

            file.Seek(0)
            data := Buffer(size, 0)
            read := file.RawRead(data, size)
        } finally {
            file.Close()
        }

        if read != size
            return ""

        return Sha256BufferHex(data, size)
    } catch {
        return ""
    }
}
